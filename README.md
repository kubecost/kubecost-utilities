# kubecost-utilities

Various utilities for more easily administering/maintaining/supporting a Kubecost install.

## ETL-BACKUP

Instructions to use the [ETL Backup Scripts](./etl-backup/README.md).

## API-SCRIPTS

These scripts are examples of what is possible. Feedback in this repo is welcomed. <https://github.com/kubecost/kubecost-utilities/issues>

### Python Virtual Environment Setup

Create virtual environment for python:

```sh
# Create a virtual environment
python3 -m venv venv

# Activate the virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
# .\venv\Scripts\activate

# Install requirements
pip install -r requirements.txt
```

### Request Sizing to CSV

Set API Key if using SSO:

```sh
export KUBECOST_API_KEY=YOURKEY
```

Run the [request sizing to csv script](api-scripts/requestSizing-json-2-csv.py):

See comments at the top of the script for usage.

A typical query is something like:

```sh
./api-scripts/requestSizing-json-2-csv.py requestSizing.csv "http://localhost:9008/savings/requestSizingV2?algorithmCPU=max&algorithmRAM=max&targetCPUUtilization=0.65&targetRAMUtilization=0.65&filter=&window=3d"
```

Add filters to reduce size, see API docs: <https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=apis-container-request-right-sizing-recommendation-api>

Append to the end:

```sh
&filterClusters=YOUR_CLUSTER
```

### NodeGroup to JSON

[nodeGroup-json-2-csv.py](./api-scripts/nodeGroup-json-2-csv.py) is a script that converts a Kubecost nodeGroup JSON file to a CSV file.

Usage: `python3 nodeGroup-json-2-csv.py <.json file or url>`

When passing a url, the output is printed to stdout in csv format.

When passing a file, a csv file is created in the current working directory with .csv appended to the filename.