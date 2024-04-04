# aggregator-backup
Back up Kubecost's Aggregator data to your local filesystem. Execs into the Aggregator Pod, `kubectl cp`s the important Aggregator data to your local machine, and builds a `.tar.gz` archive with that data.

Usage: 

With your kubectl connected to the cluster whose data you want to back up:

```
git clone https://github.com/kubecost/kubecost-utilities.git

cd kubecost-utilities/aggregator-backup

./download-aggregator.sh <kubecost-namespace>
```

## Reliable usage

With large database files or if you get unlucky, it is possible to download the
Aggregator database and have it be in a bad state because the process is
working with the database in the middle of the download. To get a reliable download,
the following process must be followed:

1. Edit the Aggregator StatefulSet via `kubectl edit`, e.g. `kubectl edit statefulset -n kubecost kubecost-aggregator`.

   Add the following right underneath `name: aggregator` in the Pod `spec` inside the StatefulSet:

   ```
   command:
     - /bin/bash
     - -c
     - |
        sleep 36000;
   ```

   This will start the pod up in sleeping mode and will not start the app. This
   guarantees that the database will not be concurrently accessed during the
   download.

3. After saving the edits, the `kubecost-aggregator-0` Pod should terminate and restart
4. Check the logs on the `kubecost-aggregator-0` Pod to ensure there are no logs. This is expected, because it is sleeping.
5. Run the download script: `./download-aggregator.sh <kubecost-namespace>`
6. Remove the `command:` block added in step 1. Aggregator should restart with normal log behavior.
