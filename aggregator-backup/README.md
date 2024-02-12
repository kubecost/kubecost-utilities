# aggregator-backup
Back up Kubecost's Aggregator data to your local filesystem. Execs into the Aggregator Pod, `kubectl cp`s the important Aggregator data to your local machine, and builds a `.tar.gz` archive with that data.

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
