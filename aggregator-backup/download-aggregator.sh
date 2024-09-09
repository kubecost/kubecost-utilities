#!/usr/bin/env bash
#
# This script finds the latest aggregator read file and downloads it directly without using tar

set -euo pipefail

# Accept Optional Namespace -- default to kubecost
namespace="${1:-kubecost}"

# Accept Optional duckdb Storage Directory -- default to /var/configs/waterfowl/duckdb
aggDir="${2:-/var/configs/waterfowl/duckdb}"

# Grab the Current Context for Prompt
currentContext="$(kubectl config current-context)"

echo "This script will download the Aggregator Read DB using the following:"
echo "  Kubectl Context: $currentContext"
echo "  Namespace: $namespace"
echo "  Kubecost Aggregator Directory: $aggDir"
echo -n "Would you like to continue [y/N]? "
read -r r

if [ "$r" == "${r#[y]}" ]; then
  echo "Exiting..."
  exit 0
fi

# Find the aggregator pod
podName=$(kubectl get pod -n "$namespace" -l app=aggregator -o jsonpath='{.items[0].metadata.name}')

if [ -z "$podName" ]; then
    echo "No aggregator pod found in namespace $namespace"
    exit 1
fi

echo "Found aggregator pod: $podName"

# Find the latest .read file and download it
echo "Finding latest .read file and downloading..."
kubectl exec -it $podName -n $namespace -c aggregator -- /bin/sh <<EOF
set -e
latest_read_file=\$(ls -t $aggDir/v*/*.read | head -n 1)
echo "Latest .read file: \$latest_read_file"
if [ -f "\$latest_read_file" ]; then
    base64 "\$latest_read_file"
else
    echo "File not found: \$latest_read_file" >&2
    exit 1
fi
EOF
) | base64 -d > "kubecost-latest.duckdb.read"

if [ $? -eq 0 ]; then
    echo "File kubecost-latest.duckdb.read downloaded successfully."
else
    echo "Error occurred while downloading the file."
    exit 1
fi

echo "Done"
