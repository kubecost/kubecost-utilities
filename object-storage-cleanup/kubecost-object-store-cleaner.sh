#!/usr/bin/env bash

set -euo pipefail

#==============================================================================
# Configuration Variables (can be overridden via environment variables)
#==============================================================================
BUCKET="${BUCKET:-bucket1}"
PREFIX="${PREFIX:-federated/}"
DAYS_OLD="${DAYS_OLD:-7}"
OUTPUT_FILE="${OUTPUT_FILE:-old_files.csv}"
SEARCH_PATTERNS="${SEARCH_PATTERNS:-1h,10m}"

#==============================================================================
# Script Variables
#==============================================================================
DELETE_MODE=false
CSV_FILE=""

#==============================================================================
# Functions
#==============================================================================

parse_arguments() {
  for arg in "$@"; do
    case "$arg" in
      --delete)
        DELETE_MODE=true
        ;;
      --csv=*)
        CSV_FILE="${arg#*=}"
        ;;
      *)
        echo "Unknown argument: $arg"
        echo "Usage: $0 [--delete] [--csv=file.csv]"
        exit 1
        ;;
    esac
  done
}

calculate_cutoff_date() {
  if date --version &>/dev/null 2>&1; then
    date -d "${DAYS_OLD} days ago" -u +"%Y-%m-%dT%H:%M:%S"
  else
    date -u -v-${DAYS_OLD}d +"%Y-%m-%dT%H:%M:%S"
  fi
}

build_grep_pattern() {
  local patterns="$1"
  IFS=', ' read -ra PATTERNS <<< "$patterns"

  local grep_pattern=""
  for pattern in "${PATTERNS[@]}"; do
    if [[ -z "$grep_pattern" ]]; then
      grep_pattern="/${pattern}/"
    else
      grep_pattern="${grep_pattern}\|/${pattern}/"
    fi
  done

  echo "$grep_pattern"
}

# List S3 objects matching path patterns (e.g. /1h/, /10m/)
# Uses --no-paginate to retrieve all objects, not just the first 1000
# List S3 objects matching path patterns (e.g. /1h/, /10m/)
list_objects_with_patterns() {
  local bucket="$1"
  local cutoff="$2"
  local grep_pattern="$3"
  local output_file="$4"

  echo "Finding files in s3://${bucket} matching patterns: ${SEARCH_PATTERNS} older than ${DAYS_OLD} days (before ${cutoff})..."

  aws s3api list-objects-v2 \
    --bucket "$bucket" \
    --output text \
    --query "Contents[].[Key,LastModified,Size]" \
  | awk -v cutoff="$cutoff" '$2 < cutoff' \
  | grep "$grep_pattern" \
  | awk '{print $1","$2","$3}' \
  >> "$output_file"
}

# List S3 objects under a specific prefix
list_objects_with_prefix() {
  local bucket="$1"
  local prefix="$2"
  local cutoff="$3"
  local output_file="$4"

  echo "Finding files in s3://${bucket} matching [${prefix}] older than ${DAYS_OLD} days (before ${cutoff})..."

  aws s3api list-objects-v2 \
    --bucket "$bucket" \
    --prefix "$prefix" \
    --output text \
    --query "Contents[].[Key,LastModified,Size]" \
  | awk -v cutoff="$cutoff" '$2 < cutoff' \
  | awk '{print $1","$2","$3}' \
  >> "$output_file"
}

show_preview() {
  local csv_file="$1"
  local file_count="$2"

  echo "Found ${file_count} file(s). List saved to: ${csv_file}"
  echo ""
  echo "Preview (first 20):"
  head -21 "$csv_file" | column -t -s','
}

# Delete files listed in a CSV using AWS batch deletion (max 1000 objects per API call)
# Uses jq to safely build the JSON payload, avoiding issues with special characters in keys
delete_files_from_csv() {
  local csv_file="$1"
  local file_count="$2"

  echo ""
  echo "WARNING: CSV Delete mode enabled. Deleting ${file_count} file(s)..."

  local deleted_log="${csv_file%.csv}_deleted.csv"
  echo "Key,LastModified,Size,DeletedAt" > "$deleted_log"
  local deletion_timestamp
  deletion_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local batch_keys=()
  local total_deleted=0
  local batch_num=0

  flush_batch() {
    if [[ ${#batch_keys[@]} -eq 0 ]]; then
      return
    fi

    batch_num=$((batch_num + 1))
    local batch_size=${#batch_keys[@]}
    echo "Deleting batch ${batch_num} (${batch_size} objects)..."

    # Build the delete payload safely with jq
    local payload
    payload=$(printf '%s\n' "${batch_keys[@]}" | jq -Rn '
      {"Objects": [inputs | {"Key": .}], "Quiet": true}
    ')

    aws s3api delete-objects \
      --bucket "$BUCKET" \
      --delete "$payload"

    total_deleted=$((total_deleted + batch_size))
    echo "  Progress: ${total_deleted} / ${file_count} deleted"

    batch_keys=()
  }

  while IFS=',' read -r key last_modified size; do
    # Skip header row
    [[ "$key" == "Key" ]] && continue
    # Skip blank lines
    [[ -z "$key" ]] && continue

    batch_keys+=("$key")

    # Flush when batch reaches AWS limit of 1000
    if [[ ${#batch_keys[@]} -eq 1000 ]]; then
      flush_batch
    fi

    echo "${key},${last_modified},${size},${deletion_timestamp}" >> "$deleted_log"
  done < "$csv_file"

  # Flush any remaining objects
  flush_batch

  echo ""
  echo "Deletion complete. Deleted ${total_deleted} objects in ${batch_num} batch(es)."
  echo "Deletion log saved to: ${deleted_log}"
}

process_csv_file() {
  local csv_file="$1"

  if [[ ! -f "$csv_file" ]]; then
    echo "Error: CSV file '${csv_file}' not found"
    exit 1
  fi

  # Subtract 1 to exclude the header row
  local file_count=$(( $(wc -l < "$csv_file" | tr -d ' ') - 1 ))

  if [[ "$file_count" -eq 0 ]]; then
    echo "No files found in CSV."
    exit 0
  fi

  show_preview "$csv_file" "$file_count"

  if [[ "$DELETE_MODE" == true ]]; then
    delete_files_from_csv "$csv_file" "$file_count"
  else
    echo ""
    echo "To delete these files, run with --delete --csv=${csv_file}"
  fi
}

query_s3_and_create_csv() {
  local cutoff
  cutoff=$(calculate_cutoff_date)
  rm -f "$OUTPUT_FILE"
  echo "Key,LastModified,Size" > "$OUTPUT_FILE"

  if [[ -n "$SEARCH_PATTERNS" ]]; then
    local grep_pattern
    grep_pattern=$(build_grep_pattern "$SEARCH_PATTERNS")
    list_objects_with_patterns "$BUCKET" "$cutoff" "$grep_pattern" "$OUTPUT_FILE"
  else
    list_objects_with_prefix "$BUCKET" "$PREFIX" "$cutoff" "$OUTPUT_FILE"
  fi

  local file_count=$(( $(wc -l < "$OUTPUT_FILE" | tr -d ' ') - 1 ))

  if [[ "$file_count" -eq 0 ]]; then
    echo "No files found older than ${DAYS_OLD} days."
    rm -f "$OUTPUT_FILE"
    exit 0
  fi

  show_preview "$OUTPUT_FILE" "$file_count"

  if [[ "$DELETE_MODE" == true ]]; then
    echo ""
    # Accept both "yes" and "y" for confirmation
    read -p "Proceed with deletion of ${file_count} files? (yes/y to confirm): " confirm
    if [[ "$confirm" == "yes" || "$confirm" == "y" ]]; then
      delete_files_from_csv "$OUTPUT_FILE" "$file_count"
    else
      echo "Deletion cancelled. Files list saved to: ${OUTPUT_FILE}"
    fi
  else
    echo ""
    echo "To delete these files, run with --delete flag"
  fi
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
  parse_arguments "$@"

  if [[ -n "$CSV_FILE" ]]; then
    process_csv_file "$CSV_FILE"
    exit 0
  fi

  query_s3_and_create_csv
}

main "$@"