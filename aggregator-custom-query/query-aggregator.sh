#!/bin/bash
set -euo pipefail

# Check if namespace and query arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Namespace and query arguments are required."
    echo "Usage: $0 <namespace> <query>"
    exit 1
fi

NAMESPACE=$1
QUERY=$2

if [ -z "$NAMESPACE" ]; then
    echo "Namespace cannot be empty. Exiting."
    exit 1
fi

# Check if the provided namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "Namespace '$NAMESPACE' does not exist. Exiting."
    exit 1
fi

# Find the aggregator pod
POD_NAME=$(kubectl get pod -n "$NAMESPACE" -l app=aggregator -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo "No aggregator pod found in namespace $NAMESPACE"
    exit 1
fi

echo "Found aggregator pod: $POD_NAME"

# Find the latest versioned folder
LATEST_VERSION=$(kubectl exec -n "$NAMESPACE" $POD_NAME -c aggregator -- \
    sh -c "ls -d /var/configs/waterfowl/duckdb/v* | sort -V | tail -n 1")

echo "Latest version folder: $LATEST_VERSION"

# Find the latest .read file
LATEST_READ_FILE=$(kubectl exec -n "$NAMESPACE" $POD_NAME -c aggregator -- \
    sh -c "ls -t $LATEST_VERSION/kubecost-*.duckdb.read | head -n 1")

echo "Latest .read file: $LATEST_READ_FILE"

# Execute the query
echo "Executing query: $QUERY"
RESULT=$(kubectl exec -n "$NAMESPACE" $POD_NAME -c aggregator -- \
    duckdb --readonly "$LATEST_READ_FILE" -csv -c "$QUERY")

echo "Query result:"
echo "$RESULT"

echo "Script execution complete"