#!/bin/bash
#
# This script is a modified version of download-etl.sh that allows you to query
# only for ETL files that are older than a specified window.
# 
# Note. Because script is meant to provide flexible/customizable download
# options, it is not yet compatible with upload-etl.sh
# 
# Usage:
#   $ ./download-etl-targeted.sh [namespace] [etlDir] [window]
# 
# Examples:
#   # Download the last 10 days of all your ETL files (this is the default)
#   $ ./download-etl-targeted.sh
# 
#   # Download the last 10 days of your daily Asset ETL files
#   $ ./download-etl-targeted.sh kubecost /var/configs/db/etl/bingen/assets/1d
# 
#   # Download the last 3 days of all your Allocation ETL files (replace with your own epoch timestamp)
#   $ ./download-etl-targeted.sh kubecost /var/configs/db/etl/bingen/allocations 1693785266

################################################################################
# Setup configuration
################################################################################

# Accept Optional Namespace -- default to kubecost
namespace=$1
if [ "$namespace" == "" ]; then
  namespace=kubecost
fi

# Accept Optional ETL Store Directory -- default to /var/configs/db/etl
etlDir=$2
if [ "$etlDir" == "" ]; then
  etlDir=/var/configs/db/etl
fi

# Accept Optional Window -- default to 10d
window=$3
if [ "$window" == "" ]; then
  currentTime=$(date +%s)
  tenDaysAgo=$((currentTime - 10 * 24 * 60 * 60))
  window=$tenDaysAgo
fi

# Grab the Current Context for Prompt
currentContext=`kubectl config current-context`

echo "This script will download the Kubecost ETL storage using the following:"
echo "  Kubectl Context: $currentContext"
echo "  Namespace: $namespace"
echo "  ETL Directory: $etlDir"
echo "  Window: $window"
echo -n "Would you like to continue [Y/n]? "
read r

if [ "$r" == "${r#[Y]}" ]; then
  echo "Exiting..."
  exit 0
fi

# Grab the Pod Name of the cost-analyzer pod
podName=`kubectl get pods -n $namespace -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}'`

################################################################################
# Copy all relevant files to a temporary directory on the pod
################################################################################

files=$(kubectl exec -n $namespace -c cost-model $podName -- sh -c "find $etlDir -type f")

# Iterate through all files in etlDir, and copy all files older than the window
for file in $files; do
    # Extract the last part of the filepath, which contains timestamps
    timestamps=$(basename "$file")
    firstTimestamp=$(echo $timestamps | awk -F '-' '{print $1}')

    # If the ETL file is older than the window, copy it to the temporary directory
    if [ "$firstTimestamp" -gt "$window" ]; then
        destPath=/var/configs/db/kc-etl-tmp$(dirname $file)  # concats tmpPodDir with the full ETL filepath
        echo "Copying $file to $destPath ..."
        kubectl exec -n $namespace -c cost-model $podName -- mkdir -p "$destPath"
        kubectl exec -n $namespace -c cost-model $podName -- cp "$file" "$destPath"
    fi
done

################################################################################
# Copy the compressed file to local machine
################################################################################

echo "Compressing ETL files ..."
kubectl exec -n $namespace -c cost-model $podName -- tar cfz /var/configs/db/kubecost-etl.tar.gz /var/configs/db/kc-etl-tmp

echo "Copying ETL Archive to local machine ..."
kubectl cp -c cost-model $namespace/$podName:/var/configs/db/kubecost-etl.tar.gz kubecost-etl.tar.gz

################################################################################
# Cleanup
################################################################################

echo "Cleaning up tmp files created on pod ..."
kubectl exec -n $namespace -c cost-model $podName -- rm -rf /var/configs/db/kc-etl-tmp
kubectl exec -n $namespace -c cost-model $podName -- rm -rf /var/configs/db/kubecost-etl.tar.gz
