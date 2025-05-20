#!/bin/bash
set -euo pipefail

# Function to print usage
print_usage() {
    echo "Usage: $0 <namespace> <query> [--file <filename>]"
    echo "  <namespace>: The Kubernetes namespace"
    echo "  <query>: The SQL query (in quotes) or --file option"
    echo "  --file <filename>: Optional. Path to a file containing the SQL query"
}

# Check if at least two arguments are provided
if [[ $# -lt 2 ]]; then
    echo "Error: Namespace and query arguments are required."
    print_usage
    exit 1
fi

NAMESPACE=$1
shift

# Initialize query variable
QUERY=""

# Parse arguments
if [[ "$1" == "--file" ]]; then
    if [[ -z "$2" ]]; then
        echo "Error: File path is missing after --file option."
        print_usage
        exit 1
    fi
    if [[ ! -f "$2" ]]; then
        echo "Error: File '$2' not found."
        exit 1
    fi
    QUERY=$(cat "$2")
else
    QUERY="$1"
fi

if [[ -z "${NAMESPACE}" ]]; then
    echo "Namespace cannot be empty. Exiting."
    exit 1
fi

# Check if the provided namespace exists
if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    echo "Namespace '${NAMESPACE}' does not exist. Exiting."
    exit 1
fi

# Find the aggregator pod
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -o json | jq -r ".items[] | select(.spec.containers[].name == \"aggregator\") | .metadata.name")

if [[ -z "${POD_NAME}" ]]; then
    echo "No aggregator pod found in namespace ${NAMESPACE}"
    exit 1
fi

echo "Found aggregator pod: ${POD_NAME}"

# Find the latest versioned folder
LATEST_VERSION=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c aggregator -- \
    sh -c "ls -d /var/configs/waterfowl/duckdb/v* | sort -V | tail -n 1")

echo "Latest version folder: ${LATEST_VERSION}"

# Find the latest .read file
LATEST_READ_FILE=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c aggregator -- \
    sh -c "ls -t ${LATEST_VERSION}/kubecost-*.duckdb.read | head -n 1")

echo "Latest .read file: ${LATEST_READ_FILE}"

# Execute the query
#echo "Executing query: $QUERY"
RESULT=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c aggregator -- \
    duckdb --readonly "${LATEST_READ_FILE}" -csv -c "${QUERY}")

echo "Query result:"
echo "${RESULT}"

echo "Script execution complete"