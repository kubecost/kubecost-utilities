#!/bin/bash
set -euo pipefail

# Check if namespace argument is provided
if [ $# -eq 0 ]; then
    echo "Error: Namespace argument is required."
    echo "Usage: $0 <namespace>"
    exit 1
fi

NAMESPACE=$1

if [ -z "$NAMESPACE" ]; then
    echo "Namespace cannot be empty. Exiting."
    exit 1
fi

# Check if the provided namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "Namespace '$NAMESPACE' does not exist. Exiting."
    exit 1
fi

OLD_POD=''
NEW_POD=''
if [[ $(kubectl -n "$NAMESPACE" get sts -l app=aggregator 2>&1) == *"No resources found"* ]]; then
    echo "No aggregator StatefulSet found with label 'app=aggregator' in namespace $NAMESPACE"
    # check if its single cluster deployment
    if [ $(kubectl -n "$NAMESPACE" get service -l app=aggregator -o name | wc -l) -gt 0 ]; then
        echo "default single cluster deployment"
        OLD_POD=$(kubectl get pod -n "$NAMESPACE" -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')
        NEW_POD=$OLD_POD
    else
        echo "Unsupported alert transition"
        exit 1
    fi
else
    echo "Aggregator StatefulSet with label 'app=aggregator' found in namespace $NAMESPACE"
    OLD_POD=$(kubectl get pod -n "$NAMESPACE" -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')
    NEW_POD=$(kubectl get pod -n "$NAMESPACE" -l app=aggregator -o jsonpath='{.items[0].metadata.name}')
fi

# Check if OLD_POD and NEW_POD are not empty
if [ -z "$OLD_POD" ] || [ -z "$NEW_POD" ]; then
    echo "Error: OLD_POD or NEW_POD is empty. Exiting."
    exit 1
fi

SOURCE_DIR="/var/configs/alerts"
TARGET_DIR="/var/configs/alerts"

# In cost-model the alerts are stored as alerts.json and in aggregator alerts are stored as alerts-aggregator.json
OLDFILENAME="/alerts.json"
NEWFILENAME="/alerts-aggregator.json"
TEMP_FILE="/tmp/$NEWFILENAME"

# Copy the content of the old file to the temporary file
kubectl exec -n "$NAMESPACE" $OLD_POD -c cost-model -- cat "$SOURCE_DIR/$OLDFILENAME" > "$TEMP_FILE"

# Ensure the target directory exists in aggregator container
kubectl exec -i -n "$NAMESPACE" $NEW_POD -c aggregator -- sh -c "mkdir -p $TARGET_DIR"

# Copy the content from the temporary file to the new file in the aggregator
cat "$TEMP_FILE" | kubectl exec -i -n "$NAMESPACE" $NEW_POD -c aggregator -- sh -c "cat > $TARGET_DIR/$NEWFILENAME"

# Check the file is transitioned
output=$(kubectl exec -it -n "$NAMESPACE" $NEW_POD -c aggregator -- ls -lh "$TARGET_DIR/$NEWFILENAME")
line_count=$(echo "$output" | wc -l)

if [ "$line_count" -eq 1 ]; then
    echo "File successfully copied and verified"
else
    echo "Failed to copy, could not find the ${NEWFILENAME} in aggregator"
    exit 1
fi

rm -f "$TEMP_FILE"

# Empty the old alerts file in cost-model
# NOTE: Health alerts need to be enabled again on UI to get alerts from cost-model
kubectl exec -it -n "$NAMESPACE" $OLD_POD -c cost-model -- sh -c "echo '{}' > '$SOURCE_DIR/$OLDFILENAME'"

echo "Script run complete"

