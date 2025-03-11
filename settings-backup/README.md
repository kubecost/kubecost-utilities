# Copy Settings, Reports & Budgets Scripts

This script will backup all settings in the cost-model or aggregator pod. This can be useful when migrating settings to a new cluster.

## Description

- [backup-settings.sh](backup-settings.sh): Backup all Kubecost settings
- [upload-settings.sh](upload-settings.sh): This script uploads all config files from a folder on this machine to the new Aggregator.

## Usage example

1. Backup the settings

```bash
bash backup-settings.sh [--container container] [--namespace namespace]
```

2. Upload the settings to the new Aggregator

```bash
bash upload-settings.sh NEW_NAMESPACE BACKUP_FOLDER
```
