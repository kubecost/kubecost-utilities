# Copy Alerts Script

This script copies the alerts configuration from the cost-model container to the aggregator container in a Kubecost deployment.

## Usage

sh copy-alerts/copy-alerts.sh namespace

For example to copy alerts in namespace kubecost:

```
sh copy-alerts/copy-alerts.sh kubecost
```

## Description

The script performs the following actions:
1. Copies the alerts configuration from the cost-model container to the aggregator container.
2. Verifies that the file was successfully copied.
3. Empties the original alerts file in the cost-model container.

## Important Note

This script should only be run when alerts are not created via ConfigMap as part of the Helm values passed during Kubecost installation.

## Prerequisites

- kubectl must be installed and configured to access your cluster.
- You must have the necessary permissions to execute commands in the specified namespace.

## Troubleshooting

If you encounter any issues, the script will provide error messages to help diagnose the problem. Ensure that the specified namespace exists and that the Kubecost pods are running correctly.