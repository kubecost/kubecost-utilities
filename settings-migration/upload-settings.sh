#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 <namespace> <folder with settings to upload>"
  exit 1
fi

NAMESPACE=$1
OUTPUT_DIR=$2

kubecost_aggregator=$(kubectl get pod -n $NAMESPACE -l app=aggregator -o jsonpath='{.items[0].metadata.name}')


if [ -f $OUTPUT_DIR/advanced-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/advanced-reports.json ${kubecost_aggregator}:/var/configs/advanced-reports.json
  echo "Uploaded advanced-reports.json"
fi
if [ -f $OUTPUT_DIR/apiconfig.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/apiconfig.json ${kubecost_aggregator}:/var/configs/apiconfig.json
  echo "Uploaded apiconfig.json"
fi
if [ -f $OUTPUT_DIR/asset-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/asset-reports.json ${kubecost_aggregator}:/var/configs/asset-reports.json
  echo "Uploaded asset-reports.json"
fi
if [ -f $OUTPUT_DIR/budgets.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/budgets.json ${kubecost_aggregator}:/var/configs/budgets.json
  echo "Uploaded budgets.json"
fi
if [ -f $OUTPUT_DIR/cloud-configurations.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/cloud-configurations.json ${kubecost_aggregator}:/var/configs/cloud-configurations.json
  echo "Uploaded cloud-configurations.json"
fi
if [ -f $OUTPUT_DIR/cloud-cost-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/cloud-cost-reports.json ${kubecost_aggregator}:/var/configs/cloud-cost-reports.json
  echo "Uploaded cloud-cost-reports.json"
fi
if [ -f $OUTPUT_DIR/collections.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/collections.json ${kubecost_aggregator}:/var/configs/collections.json
  echo "Uploaded collections.json"
fi
if [ -f $OUTPUT_DIR/group-reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/recurring-budget-rules.json ${kubecost_aggregator}:/var/configs/recurring-budget-rules.json
  echo "Uploaded recurring-budget-rules.json"
fi
if [ -f $OUTPUT_DIR/reports.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/reports.json ${kubecost_aggregator}:/var/configs/reports.json
  echo "Uploaded reports.json"
fi
if [ -f $OUTPUT_DIR/serviceAccounts.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/serviceAccounts.json ${kubecost_aggregator}:/var/configs/serviceAccounts.json
  echo "Uploaded serviceAccounts.json"
fi
if [ -f $OUTPUT_DIR/teams.json ]; then
  kubectl cp -n $NAMESPACE -c aggregator $OUTPUT_DIR/users.json ${kubecost_aggregator}:/var/configs/users.json
  echo "Uploaded users.json"
fi