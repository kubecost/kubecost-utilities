# Copy Reports & Budgets Scripts

## Description

- [copy-reports.sh](copy-reports.sh): This script automates the migration of specific configuration files from the old Cost Analyzer to the new Aggregator in the Kubecost namespace. It copies files listed in the script from the old pod to the new pod, ensuring a seamless transition.
- [backup-settings.sh](backup-settings.sh): This script downloads all config files to a local folder that is created where the script is run. These files can then be copied to the new pod or simply stored for backup.

