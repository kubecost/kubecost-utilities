# Copy Reports & Budgets Scripts

This script will backup and upload settings from one Aggregator to another.

## Description

- [backup-settings-cost-model.sh](backup-settings-cost-model.sh): This script automates the migration of specific configuration files from the old Cost Analyzer to a folder on this machine.
- [backup-settings-aggregator.sh](backup-settings-aggregator.sh): This script automates the migration of specific configuration files from the old Aggregator to a folder on this machine.
- [upload-settings.sh](upload-settings.sh): This script uploads all config files from a folder on this machine to the new Aggregator.

## Usage example

1. Backup the settings from the old Aggregator

```bash
bash settings-migration/backup-settings-aggregator.sh OLD_NAMESPACE
```

2. Upload the settings to the new Aggregator

```bash
bash settings-migration/upload-settings.sh NEW_NAMESPACE BACKUP_FOLDER
```