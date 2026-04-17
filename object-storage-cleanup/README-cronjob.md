# Kubernetes CronJob Setup for Object Storage Cleanup

This guide explains how to deploy the Kubecost object storage cleanup script as a Kubernetes CronJob that runs automatically on a schedule.

## Prerequisites

- Kubecost installed in your cluster
- `kubectl` access to the cluster
- The cleanup script (`kubecost-object-store-cleaner.sh`)

## Setup Instructions

### Step 1: Create the ConfigMap

Create a ConfigMap containing the cleanup script in the same namespace as Kubecost (typically `kubecost`):

```bash
kubectl create configmap kubecost-object-store-cleaner-script \
  --from-file=./object-storage-cleanup/kubecost-object-store-cleaner.sh \
  --namespace kubecost
```

### Step 2: Configure the CronJob

Edit the `cronJob.yaml` file and update the following values:

1. **Namespace**: Ensure it matches your Kubecost installation (default: `kubecost`)
2. **S3 Bucket**: Update the `BUCKET` environment variable with your bucket name
3. **AWS Region**: Update the `AWS_REGION` environment variable
4. **Schedule**: Adjust the cron schedule if needed (default: daily at 2 AM UTC)
5. **Retention Period**: Modify `DAYS_OLD` to change how many days of data to keep (default: 7)
6. **Search Patterns**: Adjust `SEARCH_PATTERNS` for specific resolutions (default: `1h,10m`)

### Step 3: Deploy the CronJob

Apply the CronJob manifest:

```bash
kubectl apply -f ./object-storage-cleanup/cronJob.yaml -n kubecost
```

### Step 4: Verify the CronJob

Run the cronJob a minute from now:

```bash
NEXT_MIN=$(date -u -v+1M +'%M %H * * *')
kubectl patch cronjob kubecost-object-store-cleaner -p "{\"spec\":{\"schedule\":\"$NEXT_MIN\"}}" -n kubecost
kubectl get cronjob kubecost-object-store-cleaner -n kubecost
```

View the CronJob schedule and status:

```bash
kubectl describe cronjob kubecost-object-store-cleaner -n kubecost
```

## ServiceAccount and Permissions

The CronJob uses the same ServiceAccount as the Kubecost aggregator (`kubecost-cost-analyzer`). This is a best practice because:

- The aggregator already has the necessary S3 permissions for the federated storage bucket
- No additional IAM configuration is required
- Simplified permission management

**Important**: Ensure the Kubecost aggregator's ServiceAccount has the following S3 permissions:

- `s3:ListBucket`
- `s3:GetObject`
- `s3:DeleteObject`

These permissions should already be configured if you're using Kubecost's federated storage feature.

## Monitoring

### View Recent Job Runs

```bash
kubectl get jobs -n kubecost -l app=kubecost-object-store-cleaner
```

### Check Job Logs

```bash
# Get the most recent job pod
POD=$(kubectl get pods -n kubecost -l app=kubecost-object-store-cleaner --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# View logs
kubectl logs $POD -n kubecost
```

### Manual Trigger

To manually trigger a job run for testing:

```bash
kubectl create job --from=cronjob/kubecost-object-store-cleaner manual-cleanup-$(date +%s) -n kubecost
```

## Customization

### Change Schedule

The default schedule runs daily at 2 AM UTC. To modify:

```yaml
spec:
  schedule: "0 2 * * *" # Cron format: minute hour day month weekday
```

Common schedules:

- Daily at 2 AM UTC: `"0 2 * * *"`
- Every 12 hours: `"0 */12 * * *"`
- Weekly on Sunday at 3 AM: `"0 3 * * 0"`
- Monthly on the 1st at midnight: `"0 0 1 * *"`

### Adjust Retention Period

Modify the `DAYS_OLD` environment variable:

```yaml
- name: DAYS_OLD
  value: "14" # Keep 14 days of data
```

### Target Specific Resolutions

Modify the `SEARCH_PATTERNS` environment variable to target specific resolution folders:

```yaml
- name: SEARCH_PATTERNS
  value: "1h,10m,1m" # Clean up 1h, 10m, and 1m resolution data
```

Or set to empty to clean all files under the prefix:

```yaml
- name: SEARCH_PATTERNS
  value: ""
```

## Troubleshooting

### Job Fails with Permission Errors

Verify the ServiceAccount has proper S3 permissions:

```bash
kubectl describe serviceaccount kubecost-cost-analyzer -n kubecost
```

For AWS IRSA, check the IAM role annotation:

```bash
kubectl get serviceaccount kubecost-cost-analyzer -n kubecost -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

### ConfigMap Not Found

Ensure the ConfigMap was created in the correct namespace:

```bash
kubectl get configmap kubecost-object-store-cleaner-script -n kubecost
```

### Script Not Executing

The job installs `jq` at runtime using `yum` or `dnf` (Amazon Linux). This requires internet access from within the pod. If the cluster restricts egress, pre-bake a custom image based on `amazon/aws-cli` with `jq` already installed and update the `image` field in `cronJob.yaml`.

## Updating the Script

To update the cleanup script after making changes:

```bash
# Delete the old ConfigMap
kubectl delete configmap kubecost-object-store-cleaner-script -n kubecost

# Create the new ConfigMap
kubectl create configmap kubecost-object-store-cleaner-script \
  --from-file=kubecost-object-store-cleaner.sh \
  --namespace kubecost
```

The next scheduled job run will use the updated script.

## Cleanup

To remove the CronJob:

```bash
kubectl delete cronjob kubecost-object-store-cleaner -n kubecost
kubectl delete configmap kubecost-object-store-cleaner-script -n kubecost
```
