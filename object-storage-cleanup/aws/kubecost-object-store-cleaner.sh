#!/usr/bin/env bash

set -euo pipefail

#==============================================================================
# Configuration (override via environment variables)
#==============================================================================
BUCKET="${BUCKET:-}"
PREFIX="${PREFIX:-}"
DAYS_OLD="${DAYS_OLD:-7}"

#==============================================================================
# Script state
#==============================================================================
DELETE_MODE=false
CSV_FILE=""
SKIP_CONFIRM=false
OUTPUT_CSV=""  # set by --output-csv[=filename]; empty means stdout

#==============================================================================
# Functions
#==============================================================================

parse_arguments() {
  for arg in "$@"; do
    case "$arg" in
      --delete)       DELETE_MODE=true ;;
      --csv=*)        CSV_FILE="${arg#*=}" ;;
      --confirm)      SKIP_CONFIRM=true ;;
      --output-csv)   OUTPUT_CSV="old_files.csv" ;;
      --output-csv=*) OUTPUT_CSV="${arg#*=}" ;;
      *)
        echo "Unknown argument: $arg"
        echo "Usage: $0 [--delete] [--csv=file.csv] [--confirm] [--output-csv[=file.csv]]"
        exit 1
        ;;
    esac
  done
}

calculate_cutoff_date() {
  if date --version &>/dev/null 2>&1; then
    # GNU date (Linux)
    date -d "${DAYS_OLD} days ago" -u +"%Y-%m-%dT%H:%M:%S"
  else
    # BSD date (macOS)
    date -u -v-"${DAYS_OLD}"d +"%Y-%m-%dT%H:%M:%S"
  fi
}

# List S3 objects with /1h/ or /10m/ in their key path, older than cutoff.
# Applies PREFIX to scope the listing when set.
# Auto-pagination is on by default in AWS CLI v2, so all objects are returned.
list_objects() {
  local bucket="$1"
  local prefix="$2"
  local cutoff="$3"
  local output_file="$4"

  local location="s3://${bucket}"
  [[ -n "$prefix" ]] && location="s3://${bucket}/${prefix}"

  echo "Finding /1h/ and /10m/ files in ${location} older than ${DAYS_OLD} days (before ${cutoff})..."
  echo "This can take hours if there are many files."

  local aws_args=(
    --bucket "$bucket"
    --output text
    --query "Contents[?LastModified < '${cutoff}' && (contains(Key, '/1h/') || contains(Key, '/10m/'))].[Key,LastModified,Size]"
  )
  [[ -n "$prefix" ]] && aws_args+=(--prefix "$prefix")

  aws s3api list-objects-v2 "${aws_args[@]}" \
    | awk '{print $1","$2","$3}' \
    >> "$output_file"
}

show_preview() {
  local csv_file="$1"
  local file_count="$2"

  echo "Found ${file_count} file(s)."
  echo ""
  echo "Preview (first 5):"
  head -6 "$csv_file"
}

# Deletes files listed in a CSV using AWS batch deletion (max 1000 objects per API call).
# Uses jq to safely build the JSON payload, avoiding issues with special characters in keys.
# Deletion records go to a *_deleted.csv file if --output-csv was set, otherwise to stdout.
delete_files_from_csv() {
  local csv_file="$1"
  local file_count="$2"

  echo ""
  echo "WARNING: Deleting ${file_count} file(s) from s3://${BUCKET}..."

  local deleted_log=""
  if [[ -n "$OUTPUT_CSV" ]]; then
    deleted_log="${OUTPUT_CSV%.csv}_deleted.csv"
    echo "Key,LastModified,Size,DeletedAt" > "$deleted_log"
  fi

  local deletion_timestamp
  deletion_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local batch_keys=()
  local total_deleted=0
  local batch_num=0

  flush_batch() {
    [[ ${#batch_keys[@]} -eq 0 ]] && return

    batch_num=$((batch_num + 1))
    local batch_size=${#batch_keys[@]}

    local payload_file
    payload_file=$(mktemp /tmp/kubecost-delete-payload-XXXXXX.json)
    printf '%s\n' "${batch_keys[@]}" | jq -Rn '
      {"Objects": [inputs | {"Key": .}], "Quiet": true}
    ' > "$payload_file"

    aws s3api delete-objects --bucket "$BUCKET" --delete "file://${payload_file}"
    rm -f "$payload_file"

    total_deleted=$((total_deleted + batch_size))
    echo "  Progress: ${total_deleted} / ${file_count} deleted"
    batch_keys=()
  }

  while IFS=',' read -r key last_modified size; do
    [[ "$key" == "Key" || -z "$key" ]] && continue
    batch_keys+=("$key")
    [[ ${#batch_keys[@]} -eq 1000 ]] && flush_batch

    if [[ -n "$deleted_log" ]]; then
      echo "${key},${last_modified},${size},${deletion_timestamp}" >> "$deleted_log"
    else
      echo "DELETED ${key} ${last_modified} ${size} ${deletion_timestamp}"
    fi
  done < "$csv_file"

  flush_batch

  echo ""
  echo "Deletion complete. ${total_deleted} object(s) deleted in ${batch_num} batch(es)."
  if [[ -n "$deleted_log" ]]; then
    echo "Deletion log: ${deleted_log}"
  fi
}

process_csv_file() {
  local csv_file="$1"

  [[ ! -f "$csv_file" ]] && { echo "Error: CSV file '${csv_file}' not found"; exit 1; }

  local file_count=$(( $(wc -l < "$csv_file" | tr -d ' ') - 1 ))

  [[ "$file_count" -eq 0 ]] && { echo "No files found in CSV."; exit 0; }

  show_preview "$csv_file" "$file_count"

  if [[ "$DELETE_MODE" == true ]]; then
    delete_files_from_csv "$csv_file" "$file_count"
  else
    echo ""
    echo "To delete these files, run: $0 --delete --csv=${csv_file}"
  fi
}

query_and_process() {
  [[ -z "$BUCKET" ]] && { echo "Error: BUCKET environment variable is not set"; exit 1; }
  # Validate bucket name doesn't contain : or /
  if [[ "$BUCKET" =~ [:/] ]]; then
    echo "Error: BUCKET name cannot contain ':' or '/' characters"
    echo "Found: $BUCKET"
    exit 1
  fi
  local cutoff
  cutoff=$(calculate_cutoff_date)

  local tmp_file
  tmp_file=$(mktemp /tmp/kubecost-cleaner-XXXXXX.csv)
  echo "Key,LastModified,Size" > "$tmp_file"

  list_objects "$BUCKET" "$PREFIX" "$cutoff" "$tmp_file"

  local file_count=$(( $(wc -l < "$tmp_file" | tr -d ' ') - 1 ))

  if [[ "$file_count" -eq 0 ]]; then
    echo "No files found older than ${DAYS_OLD} days."
    rm -f "$tmp_file"
    exit 0
  fi

  show_preview "$tmp_file" "$file_count"

  if [[ -n "$OUTPUT_CSV" ]]; then
    cp "$tmp_file" "$OUTPUT_CSV"
    echo "File list saved to: ${OUTPUT_CSV}"
  fi

  if [[ "$DELETE_MODE" == true ]]; then
    echo ""
    if [[ "$SKIP_CONFIRM" == true ]]; then
      delete_files_from_csv "$tmp_file" "$file_count"
    else
      read -r -p "Proceed with deletion of ${file_count} files? (yes/y to confirm): " confirm
      if [[ "$confirm" == "yes" || "$confirm" == "y" ]]; then
        delete_files_from_csv "$tmp_file" "$file_count"
      else
        echo "Deletion cancelled."
      fi
    fi
  else
    echo ""
    echo "To delete these files, run: $0 --delete"
  fi

  rm -f "$tmp_file"
}

#==============================================================================
# Main
#==============================================================================

main() {
  parse_arguments "$@"

  if [[ -n "$CSV_FILE" ]]; then
    process_csv_file "$CSV_FILE"
    exit 0
  fi

  query_and_process
}

main "$@"

echo "Script completed."