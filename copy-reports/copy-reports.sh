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

# Check if aggregator is deployed as a statefulset
if kubectl -n "$NAMESPACE" get sts -l app=aggregator &> /dev/null; then
    echo "Aggregator StatefulSet with label 'app=aggregator' found in namespace $NAMESPACE"
else
    echo "Aggregator StatefulSet with label 'app=aggregator' not found in namespace $NAMESPACE"
    exit 1
fi

OLD_POD=$(kubectl get pod -n kubecost -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')
NEW_POD=$(kubectl get pod -n kubecost -l app=aggregator -o jsonpath='{.items[0].metadata.name}')
SOURCE_DIR="/var/configs"
TARGET_DIR="/var/configs"

FILES=(
    "budgets.json"
    "asset-reports.json"
    "cloud-cost-reports.json"
    "reports.json"
)

for FILE in "${FILES[@]}"; do
    echo "Copying file: $FILE"

    # Download the file from the old reports
    kubectl cp kubecost/$OLD_POD:"$SOURCE_DIR/$FILE" /tmp/"$FILE" -c cost-model

    # Upload the file to the new reports location in Aggregator
    kubectl cp /tmp/"$FILE" kubecost/$NEW_POD:"$TARGET_DIR/$FILE" -c aggregator

    # Check the file in the new reports
    kubectl exec -it -n kubecost $NEW_POD -c aggregator -- ls -lh "$TARGET_DIR/$FILE"

    echo "Done!"
    echo
done

# Clean up specific files in /tmp directory
for FILE in "${FILES[@]}"; do
    rm -f /tmp/"$FILE"
done

echo "Temporary files in /tmp directory cleaned up."

