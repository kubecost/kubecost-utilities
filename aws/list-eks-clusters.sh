#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# List All EKS Clusters Across an AWS Account (All Regions)
#
# What this script does
# - Confirms the caller’s AWS Account and ARN (via STS) and asks for consent.
# - Iterates through AWS regions and runs `aws eks list-clusters` in each.
# - Collects results in memory and prints a clean, deduplicated summary at the end.
# - Shows a lightweight progress indicator (dots) while scanning regions.
#
# Usage
#   ./list-eks-all-regions.sh
#
# Optional environment variables
#   AWS_PROFILE=<profile>          Use a named profile instead of default creds.
#   AWS_MAX_ATTEMPTS=2             (Already set in script) Reduce CLI retries.
#   AWS_RETRY_MODE=standard        (Already set in script) Retry behavior.
#   REGIONS="us-east-1 us-west-2"  (If you modify the loop) Limit to specific regions.
#
# Prerequisites
# - AWS CLI v2 installed and on PATH.
# - Valid AWS credentials (env vars, default profile, or AWS SSO/session) with:
#     sts:GetCallerIdentity
#     ec2:DescribeRegions
#     eks:ListClusters
# - Network access to regional EKS endpoints.
# ==============================================================================
export AWS_MAX_ATTEMPTS=2
export AWS_RETRY_MODE=standard

# Get the current AWS account ID and user
account_id=$(aws sts get-caller-identity --query "Account" --output text)
user_arn=$(aws sts get-caller-identity --query "Arn" --output text)

echo "You are about to list all EKS clusters in AWS account: $account_id"
echo "Authenticated as: $user_arn"
read -rp "Proceed? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

echo "Fetching EKS clusters across all regions..."
echo "------------------------------------------------"

results=()

# iterate through each region, storing a string of the region and cluster
for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  echo -n "."
  clusters=$(aws eks list-clusters \
    --region "$region" \
    --query "clusters[]" \
    --cli-connect-timeout 5 \
    --cli-read-timeout 10 \
    --output text)

  if [[ -n "$clusters" ]]; then
    for cluster in $clusters; do
      results+=("Region: $region | Cluster: $cluster")
    done
  fi
done
echo
echo "------------------------------------------------"

# print the results 
for line in "${results[@]}"; do
  echo "$line"
done

echo "------------------------------------------------"
echo "Done."
