#!/bin/bash
# set -euxo pipefail

if [ -z "$1" ]; then
  echo "No namespace provided, using default: kubecost"
  echo "Usage: $0 <namespace>"
  echo "Continue with namespace: kubecost?"
  read -p "Press enter to continue"
  NAMESPACE=kubecost
else
   NAMESPACE=$1
fi

echo "Expect some failures as not all files may be present"

# Check if aggregator is deployed as a statefulset
if kubectl -n "$NAMESPACE" get sts -l app=aggregator &> /dev/null; then
    echo "Aggregator StatefulSet with label 'app=aggregator' found in namespace $NAMESPACE"
else
    echo "Aggregator StatefulSet with label 'app=aggregator' not found in namespace $NAMESPACE"
    exit 1
fi

OLD_POD=$(kubectl get pod -n $NAMESPACE -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')
NEW_POD=$(kubectl get pod -n $NAMESPACE -l app=aggregator -o jsonpath='{.items[0].metadata.name}')
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
    kubectl cp $NAMESPACE/$OLD_POD:"$SOURCE_DIR/$FILE" /tmp/"$FILE" -c cost-model

    # Upload the file to the new reports location in Aggregator
    kubectl cp /tmp/"$FILE" $NAMESPACE/$NEW_POD:"$TARGET_DIR/$FILE" -c aggregator

    # Check the file in the new reports
    kubectl exec -it -n $NAMESPACE $NEW_POD -c aggregator -- ls -lh "$TARGET_DIR/$FILE"

    echo "Done!"
    echo
done

# Clean up specific files in /tmp directory
for FILE in "${FILES[@]}"; do
    rm -f /tmp/"$FILE"
done

echo "Temporary files in /tmp directory cleaned up."

