#!/usr/bin/env bash
#
# This script will use kubectl to copy the aggregator data files using an ephemeral container

set -eo pipefail

# Temporary Directory Name
tmpDir=kc-aggregator-tmp

if [ -d "${tmpDir}" ]; then
    echo "Temp dir '${tmpDir}' already exists. Please manually remove it before running this script."
    exit 1
fi

# Accept Optional Namespace -- default to kubecost
namespace="${1:-kubecost}"

# Accept Optional duckdb Storage Directory -- default to /var/configs/waterfowl/duckdb
aggDir="${2:-/var/configs/waterfowl/duckdb}"

# Grab the Current Context for Prompt
currentContext="$(kubectl config current-context)"

echo "This script will downlaod the Aggregator Read DB using the following:"
echo "  Kubectl Context: $currentContext"
echo "  Namespace: $namespace"
echo "  Kubecost Aggregator Directory: $aggDir"
echo -n "Would you like to continue [y/N]? "
read -r r

if [ "$r" == "${r#[y]}" ]; then
  echo "Exiting..."
  exit 0
fi

# Grab the Pod Name of the aggregator pod
podName="$(kubectl get pods -n "$namespace" -l app=aggregator -o jsonpath='{.items[0].metadata.name}')"

# Use ephemeral container to access and copy the read DB file
echo "Accessing aggregator filesystem using ephemeral container..."
kubectl debug -n "$namespace" "$podName" -it --image=busybox --target=aggregator --share-processes -- /bin/sh -c "
  cd /proc/1/root${aggDir}
  readDbFile=\$(find . -type f -name '*.read')
  if [ -z \"\$readDbFile\" ]; then
    echo 'Read DB file not found'
    exit 1
  fi
  echo \"Found read db file: \$readDbFile\"
  mkdir -p /tmp/$tmpDir
  cp \"\$readDbFile\" /tmp/$tmpDir/
  echo 'File copied to ephemeral container'
" || { echo "Failed to access or copy file from ephemeral container"; exit 1; }

# Copy file from ephemeral container to local machine
echo "Copying file from ephemeral container to local machine..."
kubectl cp -n "$namespace" "$podName":/tmp/$tmpDir ./$tmpDir

# Archive the directory
tar cfz kubecost-aggregator.tar.gz $tmpDir && \
  echo "Archive created successfully" || \
  echo "Failed to create archive\nNote: if you have an error like: Cannot stat: No such file or directory\nYou will need to run the script again because the Read-DB changed while running the script."
# Delete the temporary directory
rm -rf $tmpDir

# Log final messages
echo "DB Archive Created kubecost-aggregator.tar.gz"
echo "Done"
