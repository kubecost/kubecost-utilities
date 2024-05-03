todo
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/advanced-reports.json ${kubecost_cost_analyzer}:/var/configs/advanced-reports.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/apiconfig.json ${kubecost_cost_analyzer}:/var/configs/apiconfig.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/asset-reports.json ${kubecost_cost_analyzer}:/var/configs/asset-reports.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/budgets.json ${kubecost_cost_analyzer}:/var/configs/budgets.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/cloud-configurations.json ${kubecost_cost_analyzer}:/var/configs/cloud-configurations.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/cloud-cost-reports.json ${kubecost_cost_analyzer}:/var/configs/cloud-cost-reports.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/collections.json ${kubecost_cost_analyzer}:/var/configs/collections.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/group-reports.json ${kubecost_cost_analyzer}:/var/configs/group-reports.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/recurring-budget-rules.json ${kubecost_cost_analyzer}:/var/configs/recurring-budget-rules.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/reports.json ${kubecost_cost_analyzer}:/var/configs/reports.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/serviceAccounts.json ${kubecost_cost_analyzer}:/var/configs/serviceAccounts.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/teams.json ${kubecost_cost_analyzer}:/var/configs/teams.json
kubectl cp -n $NAMESPACE -c cost-model $OUTPUT_DIR/users.json ${kubecost_cost_analyzer}:/var/configs/users.json
