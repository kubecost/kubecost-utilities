# Kubecost Object Store Cleaner

> **Note:** This script currently supports AWS S3 only. Support for additional cloud providers (GCP, Azure) will be added in future releases.

Kubecost stores files that represent a window of time. There are three different resolutions: 10m, 1h, 1d

Only the 1d resolution files are required during a rebuild of the Aggregator pod — which would be needed if the Primary is moved to a new cluster or the PV was lost.

The 10m and 1h files are not required for a rebuild, but they will be ingested up to the limit set in the helm values, which defaults to `retention1h: 49` (49 hours) and `retention10m: 36` (360 minutes).

**The above defaults may change in the future.**

This [script](aws/kubecost-object-store-cleaner.sh) targets `/1h/` and `/10m/` files and uses a conservative default of removing them after 7 days.

- **Two Operation Modes:**
  - The default mode is read-only: query S3 and generate a CSV of matching files older than 7 days
  - `--delete` will delete the files

## Prerequisites

- AWS CLI configured with appropriate credentials
- `jq` installed
- S3 bucket access permissions (read for query, delete for cleanup)

## Configuration

Set via environment variables:

```bash
BUCKET="your-bucket-name"   # S3 bucket name (required), no s3:// prefix
PREFIX=""                   # S3 key prefix to scope the search (e.g. "federated/")
DAYS_OLD="7"                # Delete files older than N days
OUTPUT_FILE="old_files.csv" # Output CSV filename
```

## Example Usage

Generate a CSV of /1h/ and /10m/ files older than 7 days:

```sh
export BUCKET=kubecost-federated-s3-bucket
./object-storage-cleanup/aws/kubecost-object-store-cleaner.sh
```

Delete using a previously generated CSV:

```sh
./object-storage-cleanup/aws/kubecost-object-store-cleaner.sh --delete --csv=old_files.csv
```

Query and delete in one step (with interactive confirmation):

```sh
./object-storage-cleanup/aws/kubecost-object-store-cleaner.sh --delete
```

Scope the search to a specific prefix and keep 30 days instead of 7:

```sh
BUCKET=my-kubecost-bucket PREFIX="federated/" DAYS_OLD=30 \
  ./object-storage-cleanup/aws/kubecost-object-store-cleaner.sh
```

## Safety Features

- **Read-only by default:** Generates a file list without deleting anything unless `--delete` is passed
- **Preview before deletion:** Always shows the first 20 matching files and total count
- **Confirmation prompt:** Requires `yes`/`y` confirmation when `--delete` is used interactively
- **`--confirm` flag:** Skips the prompt for automated/CronJob use only
- **CSV audit trail:** Generates `*_deleted.csv` with a record of every deleted object

## Output Format

### Query output (`old_files.csv`)
```csv
Key,LastModified,Size
federated/cluster1/1h/2026-03-01T00:00:00Z.json,2026-03-01T00:00:00,1024
federated/cluster1/10m/2026-03-01T00:00:00Z.json,2026-03-01T00:00:00,512
```

### Deletion log (`old_files_deleted.csv`)
```csv
Key,LastModified,Size,DeletedAt
federated/cluster1/1h/2026-03-01T00:00:00Z.json,2026-03-01T00:00:00,1024,2026-04-16T11:21:00Z
federated/cluster1/10m/2026-03-01T00:00:00Z.json,2026-03-01T00:00:00,512,2026-04-16T11:21:00Z
```

## Performance

- **Batch deletion:** Uses `aws s3api delete-objects` — up to 1000 objects per API call
- **Full pagination:** `--no-paginate` ensures all objects are returned, not just the first 1000
- **Example:** Deleting 10,000 files takes ~10–20 seconds instead of 30+ minutes

## Notes

- Dates are in UTC
- File size is in bytes
- `PREFIX` scopes the S3 listing; leave empty to search the entire bucket
