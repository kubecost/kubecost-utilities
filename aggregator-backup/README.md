# aggregator-backup
Back up Kubecost's Aggregator data to your local filesystem. Execs into the Aggregator Pod, `kubectl cp`s the important Aggregator data to your local machine, and builds a `.tar.gz` archive with that data.

Usage: 

With your kubectl connected to the cluster whose data you want to back up:

```
git clone https://github.com/kubecost/kubecost-utilities.git

cd kubecost-utilities/aggregator-backup

./download-aggregator.sh <kubecost-namespace>
```
