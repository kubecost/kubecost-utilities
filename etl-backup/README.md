# etl-backup
Back up Kubecost's ETL data to your local filesystem. Execs into the kubecost pod, tars the contents of the ETL files, and `kubectl cp`'s them down to your local machine.

Usage: 

With your kubectl connected to the cluster whose data you want to back up:

```
git clone https://github.com/kubecost/etl-backup.git

cd etl-backup

./download-etl.sh <kubecost-namespace>
```

## Run ETL from backed-up data

If this is the first time using backed up data, create the relevant directory:
```
sudo mkdir -p /var/configs/db/etl
sudo chmod -R 755 /var/configs/db/etl
```

Move the given backed-up data into the directory, so that `bingen` is the first directory nested under `etl`:
```
cd kc-etl-tmp
sudo mv bingen /var/configs/db/etl
```

Now you shold be able to make an ETL and query it:
```go
// Create and run an ETL instance using the default ETL settings, with file backup
// enabled so that the backed-up ETL files are loaded.
conf := DefaultETLConfig()
conf.FileBackupEnabled = true
etl := RunETL(DefaultMockAllocationSource(), DefaultMockAssetSource(), nil, conf)

// Let the ETL run for a second
time.Sleep(time.Second)

// Let 'er rip
asr, err := etl.QueryAllocation(s, e, &kubecost.AllocationQueryOptions{
	AggregateBy: []string{"cluster", "namespace"},
})
```
