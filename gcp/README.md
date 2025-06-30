# GCP Kubecost Setup Scripts

This directory contains scripts for setting up Kubecost with BigQuery billing data access on Google Cloud Platform.

## Script Execution Order

**IMPORTANT: Run scripts in this order:**

1. [gcp/gcp-billing-project-setup.sh](gcp-kubecost-cluster-project-setup.sh) - Run this first
2. [gcp-billing-project-setup.sh](gcp-kubecost-cluster-project-setup.sh) - Run this second
3. [helmValues-gcp.yaml](helmValues-gcp.yaml) - Helm values for deploying Kubecost with the service account created in step 1

## Script Details

### 1. gcp-kubecost-cluster-project-setup.sh

**Purpose**: Creates Kubernetes Service Account and Google Service Account with Workload Identity setup.

**What it does**:

- Creates Kubernetes namespace and service account
- Creates Google Service Account in the cluster project
- Sets up Workload Identity binding
- Verifies cluster supports Workload Identity
- Generates test deployment configuration

**Configuration variables** (update before running):

- `PROJECT_K8S_CLUSTER`: GCP project where Kubernetes cluster is located
- `PROJECT_BILLING`: GCP project where billing data is located
- `K8S_NAMESPACE`: Kubernetes namespace (default: kubecost2)
- `K8S_SERVICE_ACCOUNT_CLOUD_COST`: K8s service account name
- `GSA_NAME`: Google service account name
- `CLUSTER_NAME`: Kubernetes cluster name
- `CLUSTER_ZONE`: Cluster zone
- `BIGQUERY_DATASET`: BigQuery billing dataset name
- `BIGQUERY_TABLE`: BigQuery table name

The values are the same in both scripts. Update one and copy to the other.

### 2. gcp-billing-project-setup.sh

**Purpose**: Grants BigQuery permissions to the service account created in step 1.

**What it does**:

- Grants BigQuery job permissions on billing project
- Grants data viewer permissions on dataset/table
- Configures Workload Identity binding for cross-project access

**Configuration variables** (update before running):

- Same variables as above script
- Must match the configuration from the first script

## Prerequisites

- `gcloud` CLI installed and authenticated
- `kubectl` configured for your cluster
- Appropriate IAM permissions in both projects
- Cluster with Workload Identity enabled

## Testing

After running both scripts, test the setup using:

```bash
kubectl apply -f bigquery-service-account-test.yaml
kubectl logs -f deployment/bigquery-service-account-test -n <namespace>
```

Clean up test resources:

```bash
kubectl delete deployment bigquery-service-account-test -n <namespace>
```
