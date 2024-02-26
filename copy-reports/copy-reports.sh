#!/bin/bash

OLD_POD=$(kubectl get pod -n kubecost -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')
NEW_POD=$(kubectl get pod -n kubecost -l app=aggregator -o jsonpath='{.items[0].metadata.name}')
SOURCE_DIR="/var/configs"
TARGET_DIR="/var/configs"

FILES=(
    "budgets.json"
    "asset-reports.json"
    "cloud-cost-reports.json"
    "reports.json"
    "alerts/alerts.json"
)

for FILE in "${FILES[@]}"; do
    echo "Copying file: $FILE"

    # Check the file in the old reports
    kubectl exec -it -n kubecost $OLD_POD -c cost-model -- ls -lh "$SOURCE_DIR/$FILE"

    # Download the file from the old reports
    kubectl cp kubecost/$OLD_POD:"$SOURCE_DIR/$FILE" /tmp/"$FILE" -c cost-model

    # Upload the file to the new reports location in Aggregator
    kubectl cp /tmp/"$FILE" kubecost/$NEW_POD:"$TARGET_DIR/$FILE" -c aggregator

    # Check the file in the new reports
    kubectl exec -it -n kubecost $NEW_POD -c aggregator -- ls -lh "$TARGET_DIR/$FILE"

    echo "Done!"
    echo
done

