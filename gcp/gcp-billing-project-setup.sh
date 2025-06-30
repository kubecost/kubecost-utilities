#!/bin/bash

# Kubernetes Service Account with BigQuery Access Setup
# This script creates a secure setup using Workload Identity (no passwords/secrets)
# This script is used to create a Kubernetes Service Account with
# BigQuery Access to the billing data. It can be used where the
# billing data is located in a different project than the one where
# the Kubernetes cluster where Kubecost is located.

# Configuration variables
PROJECT_K8S_CLUSTER="GCP_PROJECT_ID_WHERE_KUBECOST_CLUSTER_IS_LOCATED"
PROJECT_BILLING="GCP_PROJECT_ID_WHERE_BILLING_DATA_IS_LOCATED" # Can be the same as the project where the Kubernetes cluster is located.
K8S_NAMESPACE="kubecost"  # This is the namespace where the Kubernetes Service Account will be created.
K8S_SERVICE_ACCOUNT_CLOUD_COST="kubecost-billing-bigquery-viewer"  # This is the name of the Kubernetes Service Account that will be used. It is needed here to give it permissions with workload identity.
GSA_NAME="kubecost-billing-bigquery-viewer-gsa"  # This is the name of the Google Service Account that will be created.
CLUSTER_NAME="KUBERNETES_CLUSTER_NAME"
CLUSTER_ZONE="us-central1-a"
BIGQUERY_DATASET="BIGQUERY_DATASET_NAME"
BIGQUERY_TABLE="BIGQUERY_TABLE_NAME"  # or "*" for all tables in the dataset. The name is usually gcp_billing_export_resource_*

# END Configuration

# Make the script exit if any command fails
set -euo pipefail

echo "=== Kubernetes Service Account with BigQuery Access Setup ==="
echo "Billing Project: $PROJECT_BILLING"
echo "BigQuery Dataset: $BIGQUERY_DATASET"
echo "BigQuery Table: $BIGQUERY_TABLE"
echo "K8s Service Account: $K8S_SERVICE_ACCOUNT_CLOUD_COST"
echo "Google Service Account: $GSA_NAME"
echo ""

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "Error: $1 is not installed or not in PATH"
        exit 1
    fi
}

# Check required tools
echo "Checking required tools..."
check_command gcloud
echo "✓ Required tools are available"
echo ""

# Create Google Service Account in k8s cluster project
echo "Creating Google Service Account in $PROJECT_K8S_CLUSTER..."

# Check if service account already exists
if gcloud iam service-accounts describe $GSA_NAME@$PROJECT_K8S_CLUSTER.iam.gserviceaccount.com --project=$PROJECT_K8S_CLUSTER &>/dev/null; then
    echo "⚠️  Service account $GSA_NAME already exists in project $PROJECT_K8S_CLUSTER"
    echo ""
    echo "Options:"
    echo "To continue with existing service account, press y"
    echo "or any other key to exit"
    echo ""
    read -p "Enter your choice (y or any other key): " choice

    case $choice in
        "y")
            echo "✓ Using existing Google Service Account: $GSA_NAME"
            ;;
        *)
            echo "Exiting..."
            exit 0
            ;;
    esac
else
    gcloud iam service-accounts create $GSA_NAME \
        --description="Service account for BigQuery access from Kubernetes" \
        --display-name="BigQuery Reader GSA" \
        --project=$PROJECT_K8S_CLUSTER
    echo "✓ Created Google Service Account: $GSA_NAME"
fi
echo ""

# Grant specific BigQuery permissions
echo "Granting BigQuery job permissions on $PROJECT_BILLING..."
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
