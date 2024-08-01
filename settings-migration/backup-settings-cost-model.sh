#!/bin/bash

if [ -z "$1" ]; then
  echo "No namespace provided, using default: kubecost"
  echo "Usage: $0 <namespace>"
  echo "Continue with namespace: kubecost?"
  read -p "Press enter to continue"
  NAMESPACE=kubecost
else
   NAMESPACE=$1
fi

kubecost_cost_analyzer=$(kubectl get pod -n $NAMESPACE -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')
mkdir -p $NAMESPACE-backup
OUTPUT_DIR=$NAMESPACE-backup

echo "Expect some failures as not all files may be present"

kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/advanced-reports.json $OUTPUT_DIR/advanced-reports.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/apiconfig.json $OUTPUT_DIR/apiconfig.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/asset-reports.json $OUTPUT_DIR/asset-reports.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/budgets.json $OUTPUT_DIR/budgets.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/cloud-configurations.json $OUTPUT_DIR/cloud-configurations.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/cloud-cost-reports.json $OUTPUT_DIR/cloud-cost-reports.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/collections.json $OUTPUT_DIR/collections.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/group-reports.json $OUTPUT_DIR/group-reports.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/recurring-budget-rules.json $OUTPUT_DIR/recurring-budget-rules.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/reports.json $OUTPUT_DIR/reports.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/serviceAccounts.json $OUTPUT_DIR/serviceAccounts.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/teams.json $OUTPUT_DIR/teams.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/users.json $OUTPUT_DIR/users.json
kubectl cp -n $NAMESPACE -c cost-model ${kubecost_cost_analyzer}:/var/configs/alerts/alerts.json $OUTPUT_DIR/alerts.json

# Remove empty configs
find $OUTPUT_DIR -type f -size -65c -delete

echo "The following files were copied to $OUTPUT_DIR"
ls -l $OUTPUT_DIR

