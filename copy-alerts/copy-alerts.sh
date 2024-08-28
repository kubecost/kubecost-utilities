#!/bin/bash
set -euxo pipefail

# Prompt user for namespace and validate
read -p "Enter the namespace for your kubecost deployment: " NAMESPACE

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

SOURCE_DIR="/var/configs"
TARGET_DIR="/var/configs"

# IN cost-model the alerts are stored as alerts.json and in aggregator alerts are stored as alerts-aggregator.json
OLDFILENAME="alerts/alerts.json"
NEWFILENAME="alerts/alerts-aggregator.json"

kubectl cp $OLD_POD:"$SOURCE_DIR/$OLDFILENAME" /tmp/"$NEWFILENAME" -c cost-model

# Upload the file to the new reports location in Aggregator
kubectl cp /tmp/"$NEWFILENAME" $NEW_POD:"$TARGET_DIR/$NEWFILENAME" -c aggregator

# Check the file is transitioned
output=$(kubectl exec -it -n "$NAMESPACE" $NEW_POD -c aggregator -- ls -lh "$TARGET_DIR/$NEWFILENAME")
line_count=$(echo "$output" | wc -l)

if [ "$line_count" -eq 1 ]; then
    echo "File successfully copied and verified:"
else
    echo "Failed to copy"
    exit 1
fi

rm -f /tmp/"$NEWFILENAME"

# Empty the old alerts file by writing NULLing all alerts
# NOTE: Health alerts need to be enabled again on UI to get alerts from cost-model
kubectl exec -it -n "$NAMESPACE" $OLD_POD -c cost-model -- sh -c "echo '{}' > '$SOURCE_DIR/$OLDFILENAME'"

echo "Script run complete"

