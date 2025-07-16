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
K8S_SERVICE_ACCOUNT_CLOUD_COST="kc-all-billing-bq-viewer" # This is the name of the Kubernetes Service Account that will be used.
GSA_NAME="kc-all-billing-bq-viewer-gsa"                   # This is the name of the Google Service Account that will be created. Must be less than 31 characters.
CLUSTER_NAME="KUBERNETES_CLUSTER_NAME"                            # This is the name of the Kubernetes cluster where Kubecost primary cluster is located.
CLUSTER_ZONE="us-central1"                                      # This is the zone where the Kubernetes cluster is located.
BIGQUERY_DATASET="BIGQUERY_DATASET_NAME"                          # This is the name of the BigQuery billing dataset.
BIGQUERY_TABLE="BIGQUERY_TABLE_NAME"                              # or "*" for all tables in the dataset. The name is usually gcp_billing_export_resource_*

# END Configuration


# Make the script exit if any command fails
set -euo pipefail

echo "=== Kubernetes Service Account with BigQuery Access Setup ==="
echo "K8s Cluster Project: $PROJECT_K8S_CLUSTER"
echo "Billing Project: $PROJECT_BILLING"
echo "BigQuery Dataset: $BIGQUERY_DATASET"
echo "BigQuery Table: $BIGQUERY_TABLE"
echo "K8s Service Account: $K8S_SERVICE_ACCOUNT_CLOUD_COST"
echo "Google Service Account: $GSA_NAME"
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

# Prompt to check if the script should create the Kubernetes resources
echo "Do you want to create the Kubernetes resources?"
echo "This script will create a Kubernetes Service Account and namespace if they don't exist."
echo "If you choose not to create the Kubernetes resources, you can create them later."
read -p "Enter your choice (y/n): " choice
if [ "$choice" = "y" ]; then
    CREATE_K8S_RESOURCES=true
else
    CREATE_K8S_RESOURCES=false
fi
# this is only used after confirming during a prompt above
create_k8s_resources() {
    check_command kubectl

    # Get current kubectl context
    set +e
    echo "Getting current kubectl context..."
    CURRENT_CONTEXT=$(kubectl config current-context)
    echo "Current kubectl context: $CURRENT_CONTEXT"
    echo ""
    set -e
    if [ -z "$CURRENT_CONTEXT" ]; then
        echo "Error: No kubectl context found"
        echo "Please run:"
        echo "gcloud container clusters get-credentials $CLUSTER_NAME --zone=$CLUSTER_ZONE --project=$PROJECT_K8S_CLUSTER"
        echo "to get the credentials for the cluster."
        exit 1
    fi

    # Prompt user to confirm if this is the correct context
    echo "Please confirm if this is the correct kubectl context to use for creating the Kubernetes resources."
    echo "This context should point to the cluster where you want to deploy Kubecost."
    read -p "Is '$CURRENT_CONTEXT' the correct context? (y/n): " context_choice

    if [ "$context_choice" != "y" ]; then
        echo "Exiting..."
        echo "Please switch to the correct kubectl context."
        echo "Based on the settings you provided, you can run this command to get the credentials for the cluster:"
        echo "gcloud container clusters get-credentials $CLUSTER_NAME --zone=$CLUSTER_ZONE --project=$PROJECT_K8S_CLUSTER"
        echo "Then run this script again."
        exit 1
    fi

    echo "✓ Using kubectl context: $CURRENT_CONTEXT"
    echo ""

    # Get cluster credentials
    # echo "Getting cluster credentials..."
    # gcloud container clusters get-credentials $CLUSTER_NAME --zone=$CLUSTER_ZONE --project=$PROJECT_K8S_CLUSTER
    # echo "✓ Retrieved cluster credentials"
    # echo ""

    # Check if the cluster supports Workload Identity
    echo "Checking if the cluster supports Workload Identity..."
    echo "kubectl get nodes --show-labels | grep 'gke-metadata-server-enabled=true'"
    # Temporarily disable set -e to prevent failure on this command
    WORKLOAD_IDENTITY_CHECK=1
    if kubectl get nodes --show-labels | grep -q 'gke-metadata-server-enabled=true'; then
        WORKLOAD_IDENTITY_CHECK=0 # Workload Identity enabled
        echo "Workload Identity enabled"
    fi

    if [ $WORKLOAD_IDENTITY_CHECK -eq 0 ]; then
        echo "✓ Cluster supports Workload Identity"
    else
        echo "Error: Cluster does not support Workload Identity"
        echo ""
        echo "To enable Workload Identity on your cluster, run this command:"
        echo "gcloud container clusters update $CLUSTER_NAME --zone=$CLUSTER_ZONE --project=$PROJECT_K8S_CLUSTER --workload-pool=$PROJECT_K8S_CLUSTER.svc.id.goog"
        echo ""
        echo "And then enable it on the nodes:"
        echo "gcloud container node-pools list --cluster=$CLUSTER_NAME --zone=$CLUSTER_ZONE --project=$PROJECT_K8S_CLUSTER"
        echo "gcloud container node-pools update --cluster=$CLUSTER_NAME --zone=$CLUSTER_ZONE --project=$PROJECT_K8S_CLUSTER --workload-metadata=GKE_METADATA POOL_NAME"
        echo ""
        echo "After running the commands above, run this script again."
        exit 1
    fi
    echo ""

    # Create Kubernetes namespace if it doesn't exist
    echo "Creating Kubernetes namespace if needed..."
    kubectl create namespace $K8S_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ Namespace $K8S_NAMESPACE is ready"
    echo ""

    # Create Kubernetes Service Account
    echo "Creating Kubernetes Service Account..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $K8S_SERVICE_ACCOUNT_CLOUD_COST
  namespace: $K8S_NAMESPACE
  annotations:
    iam.gke.io/gcp-service-account: $GSA_NAME@$PROJECT_K8S_CLUSTER.iam.gserviceaccount.com
EOF
    echo "✓ Created Kubernetes Service Account: $K8S_SERVICE_ACCOUNT_CLOUD_COST"
    echo ""
}
# end of create_k8s_resources function

if [ "$CREATE_K8S_RESOURCES" = true ]; then
    create_k8s_resources
fi

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

# Enable Workload Identity binding
echo "Setting up Workload Identity binding..."
gcloud iam service-accounts add-iam-policy-binding \
    $GSA_NAME@$PROJECT_K8S_CLUSTER.iam.gserviceaccount.com \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:$PROJECT_K8S_CLUSTER.svc.id.goog[$K8S_NAMESPACE/$K8S_SERVICE_ACCOUNT_CLOUD_COST]" \
    --project=$PROJECT_K8S_CLUSTER
echo "✓ Configured Workload Identity binding"
echo ""

# Create example deployment that uses the service account
echo "Creating example job configuration..."
cat <<EOF >bigquery-service-account-test.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bigquery-service-account-test
  namespace: $K8S_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bigquery-service-account-test
  template:
    metadata:
      labels:
        app: bigquery-service-account-test
    spec:
      serviceAccountName: $K8S_SERVICE_ACCOUNT_CLOUD_COST
      containers:
        - name: bigquery-client
          image: google/cloud-sdk:slim
          command: ["/bin/bash"]
          resources:
            requests:
              cpu: "10m"
              memory: "10Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          args:
            - "-c"
            - |
              while true; do
                echo "\$(date): Running BigQuery query:"
                echo 'bq query --use_legacy_sql=false --project_id=$PROJECT_BILLING "SELECT DISTINCT project.id FROM $BIGQUERY_DATASET.$BIGQUERY_TABLE LIMIT 100"'
                echo "As user: \$(gcloud config get-value account)"
                bq query --use_legacy_sql=false --project_id=$PROJECT_BILLING "SELECT DISTINCT project.id FROM $BIGQUERY_DATASET.$BIGQUERY_TABLE LIMIT 100"
                sleep 60
              done

EOF
echo "✓ A pod to test the configuration is based saved to: bigquery-service-account-test.yaml"
echo ""

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Deploy your application:"
echo "   kubectl apply -f bigquery-service-account-test.yaml"
echo ""
echo "2. Check the logs of the test pod to verify the configuration:"
echo "   kubectl logs -f deployment/bigquery-service-account-test -n $K8S_NAMESPACE"
echo ""
echo "3. When complete, you can delete it:"
echo "   kubectl delete deployment bigquery-service-account-test -n $K8S_NAMESPACE"
echo "   To re-run the job, delete it and run kubectl apply again."
echo ""
echo "4. You can now use this service account in the cloud-cost pod by adding:"
echo "   spec:"
echo "     serviceAccountName: $K8S_SERVICE_ACCOUNT_CLOUD_COST"
echo ""
echo "You can test the query using your own user account with this command:"
echo "bq query --use_legacy_sql=false --project_id=$PROJECT_BILLING \"SELECT DISTINCT project.id FROM $BIGQUERY_DATASET.$BIGQUERY_TABLE LIMIT 100\""
echo ""
echo "If it returns a list of project IDs, the query is successful."
