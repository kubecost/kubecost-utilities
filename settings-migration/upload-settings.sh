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

kubecost_aggregator=$(kubectl get pod -n $NAMESPACE -l app=aggregator -o jsonpath='{.items[0].metadata.name}')
mkdir -p $NAMESPACE-backup
OUTPUT_DIR=.

echo "Expect some failures as not all files may be present"

if [ -f $OUTPUT_DIR/advanced-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/advanced-reports.json ${kubecost_aggregator}:/var/configs/advanced-reports.json
fi
if [ -f $OUTPUT_DIR/apiconfig.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/apiconfig.json ${kubecost_aggregator}:/var/configs/apiconfig.json
fi
if [ -f $OUTPUT_DIR/asset-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/asset-reports.json ${kubecost_aggregator}:/var/configs/asset-reports.json
fi
if [ -f $OUTPUT_DIR/budgets.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/budgets.json ${kubecost_aggregator}:/var/configs/budgets.json
fi
if [ -f $OUTPUT_DIR/cloud-configurations.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/cloud-configurations.json ${kubecost_aggregator}:/var/configs/cloud-configurations.json
fi
if [ -f $OUTPUT_DIR/cloud-cost-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/cloud-cost-reports.json ${kubecost_aggregator}:/var/configs/cloud-cost-reports.json
fi
if [ -f $OUTPUT_DIR/collections.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/collections.json ${kubecost_aggregator}:/var/configs/collections.json
fi
if [ -f $OUTPUT_DIR/group-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/recurring-budget-rules.json ${kubecost_aggregator}:/var/configs/recurring-budget-rules.json
fi
if [ -f $OUTPUT_DIR/reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/reports.json ${kubecost_aggregator}:/var/configs/reports.json
fi
if [ -f $OUTPUT_DIR/serviceAccounts.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/serviceAccounts.json ${kubecost_aggregator}:/var/configs/serviceAccounts.json
fi
if [ -f $OUTPUT_DIR/teams.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/users.json ${kubecost_aggregator}:/var/configs/users.json
fi