# aggregator-backup
Back up Kubecost's aggregator data to your local filesystem. Execs into the kubecost pod, tars the contents of the ETL files, and `kubectl cp`'s them down to your local machine.

Usage: 

With your kubectl connected to the cluster whose data you want to back up:

```
git clone https://github.com/kubecost/kubecost-utilities.git

cd kubecost-utilities/aggregator-backup

./download-aggregator.sh <kubecost-namespace>
```

## Use aggregator data from backed-up data

To query the data:
If this is your first time querying our aggregator data install the [duckdb cli](https://duckdb.org/docs/installation/?version=latest&environment=cli&installer=binary&platform=linux).
Storing this file in a known location and adding that to your `PATH` is recommended.
You will need to look at the files in the downloaded folder and grab the `.duckdb.read` filename and use it in the command below.
```
tar xzf kubecost-aggregator.tar.gz --directory ./
cd kc-aggregator-tmp
cd v0_9_2
duckdb kubecost-%%TIMESTAMP%%.duckdb.read
```
