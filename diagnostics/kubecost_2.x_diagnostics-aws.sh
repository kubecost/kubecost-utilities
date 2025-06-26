#!/bin/bash

BUCKET="YOUR_BUCKET"

# download the diagnostics:
aws s3 ls --recursive "s3://$BUCKET/diagnostics/" \
  | grep -v history \
  | awk '{print $4}' | xargs -I {} aws s3 cp "s3://$BUCKET/{}" "{}" \
  | tee diagnostics.csv

# Create CSV header
echo "folder,date,kubecostVersion,kubecostEmittingMetric,prometheusHasKubecostMetric,prometheusHasCadvisorMetric,prometheusHasKSMMetric,dailyAllocationEtlHealthy,dailyAssetEtlHealthy,kubecostPodsNotOOMKilled,kubecostPodsNotPending" > diagnostics.csv

# Process each JSON file in the diagnostics directory
find diagnostics -name "*.json" -type f | while read -r file; do
    # Extract folder name from path
    folder=$(dirname "$file" | sed "s|^diagnostics/||")
    
    # Extract and format data from JSON file
    jq -r --arg folder "$folder" '
        [
            $folder,
            .date,
            .kubecostVersion,
            .kubecostEmittingMetric.diagnosticPassed,
            .prometheusHasKubecostMetric.diagnosticPassed,
            .prometheusHasCadvisorMetric.diagnosticPassed,
            .prometheusHasKSMMetric.diagnosticPassed,
            .dailyAllocationEtlHealthy.diagnosticPassed,
            .dailyAssetEtlHealthy.diagnosticPassed,
            .kubecostPodsNotOOMKilled.diagnosticPassed,
            .kubecostPodsNotPending.diagnosticPassed
        ] | @csv' "$file"
done >> diagnostics.csv