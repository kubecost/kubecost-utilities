#!/bin/bash

# Kubernetes Service Account with BigQuery Access Setup
# This script creates a secure setup using Workload Identity (no passwords/secrets)
# This script is used to create a Kubernetes Service Account with
# BigQuery Access to the billing data. It can be used where the
# billing data is located in a different project than the one where
# the Kubernetes cluster where Kubecost is located.

# Configuration variables
PROJECT_K8S_CLUSTER="GCP_PROJECT_ID_WHERE_KUBECOST_CLUSTER_IS_LOCATED"
PROJECT_BILLING="GCP_PROJECT_ID_WHERE_BILLING_DATA_IS_LOCATED"    # Can be the same as the project where the Kubernetes cluster is located.
K8S_NAMESPACE="kubecost"                                          # This is the namespace where the Kubernetes Service Account will be created.
K8S_SERVICE_ACCOUNT_CLOUD_COST="kc-all-billing-bq-viewer2" # This is the name of the Kubernetes Service Account that will be used.
GSA_NAME="kc-all-billing-bq-viewer2-gsa"                   # This is the name of the Google Service Account that will be created. Must be less than 31 characters.
CLUSTER_NAME="KUBERNETES_CLUSTER_NAME"                            # This is the name of the Kubernetes cluster where Kubecost primary cluster is located.
CLUSTER_ZONE="us-central1"                                      # This is the zone where the Kubernetes cluster is located.
BIGQUERY_DATASET="BIGQUERY_DATASET_NAME"                          # This is the name of the BigQuery billing dataset.
BIGQUERY_TABLE="BIGQUERY_TABLE_NAME"                              # or "*" for all tables in the dataset. The name is usually gcp_billing_export_resource_*

# END Configuration

# Make the script exit if any command fails
set -e
# Also exit if any command in a pipeline fails
set -o pipefail
# Exit if trying to use an unset variable
set -u

echo "=== Kubernetes Service Account with BigQuery Access Setup ==="
echo "Please review the configuration values:"
echo ""
echo "K8s Cluster Project: $PROJECT_K8S_CLUSTER"
echo "Billing Project: $PROJECT_BILLING"
echo "K8s Namespace: $K8S_NAMESPACE"
echo "K8s Service Account: $K8S_SERVICE_ACCOUNT_CLOUD_COST"
echo "Google Service Account: $GSA_NAME"
echo "Cluster Name: $CLUSTER_NAME"
echo "Cluster Zone: $CLUSTER_ZONE"
echo "BigQuery Dataset: $BIGQUERY_DATASET"
echo "BigQuery Table: $BIGQUERY_TABLE"
echo ""
echo "Are these values correct? (y/n): "
read -p "" confirm_values

if [ "$confirm_values" != "y" ]; then
    echo "Please update the configuration variables at the top of this script and run it again."
    exit 0
fi

echo "✓ Configuration values confirmed"
echo ""

# Function to check if command exists
check_command() {
  if ! command -v $1 &>/dev/null; then
    echo "Error: $1 is not installed or not in PATH"
    exit 1
  fi
}

# Check required tools
echo "Checking required tools..."
check_command gcloud
echo "✓ Required tools are available"
echo ""

# Grant specific BigQuery permissions
echo "Granting BigQuery job permissions on $PROJECT_BILLING..."
# set the project to the billing project
gcloud config set project $PROJECT_BILLING

# Grant job user at project level (required to run queries)
gcloud projects add-iam-policy-binding $PROJECT_BILLING \
  --member="serviceAccount:$GSA_NAME@$PROJECT_K8S_CLUSTER.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"

echo "Granting dataset and table permissions on $PROJECT_BILLING:$BIGQUERY_DATASET..."
# Grant data viewer permission at dataset level
if [[ "$BIGQUERY_TABLE" != *"*"* ]]; then
  # If specific table is provided, grant table-level permissions only
  echo "Granting table-level permissions on $PROJECT_BILLING:$BIGQUERY_DATASET.$BIGQUERY_TABLE..."
  bq add-iam-policy-binding \
    --member="serviceAccount:$GSA_NAME@$PROJECT_K8S_CLUSTER.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataViewer" \
    $PROJECT_BILLING:$BIGQUERY_DATASET.$BIGQUERY_TABLE
else
  # If wildcard table or multiple tables needed, grant dataset-level permissions
  echo "Granting dataset-level permissions on $PROJECT_BILLING:$BIGQUERY_DATASET..."
  bq add-iam-policy-binding \
    --member="serviceAccount:$GSA_NAME@$PROJECT_K8S_CLUSTER.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataViewer" \
    $PROJECT_BILLING:$BIGQUERY_DATASET
fi
echo "✓ Granted minimal BigQuery permissions"
echo ""

# Enable Workload Identity binding
echo "Setting up Workload Identity binding..."
gcloud iam service-accounts add-iam-policy-binding \
  $GSA_NAME@$PROJECT_K8S_CLUSTER.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_K8S_CLUSTER.svc.id.goog[$K8S_NAMESPACE/$K8S_SERVICE_ACCOUNT_CLOUD_COST]" \
  --project=$PROJECT_K8S_CLUSTER
echo "✓ Configured Workload Identity binding"
echo ""

echo "=== Setup Complete! ==="
echo ""
