# kubecost-utilities

Various utilities for more easily administering/maintaining/supporting a Kubecost install.

## ETL-BACKUP
Instructions to use the [ETL Backup Scripts](./etl-backup/README.md). Use the tools by switching to `etl-backup` folder and uset he scripts there.

## API-SCRIPTS

[nodeGroup-json-2-csv.py](./api-scripts/nodeGroup-json-2-csv.py) is a script that converts a Kubecost nodeGroup JSON file to a CSV file.

Usage: `python3 nodeGroup-json-2-csv.py <.json file or url>`

When passing a url, the output is printed to stdout in csv format.

When passing a file, a csv file is created in the current working directory with .csv appended to the filename.