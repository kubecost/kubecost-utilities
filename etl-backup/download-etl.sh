#!/bin/bash
#
# This script will use kubectl to copy the ETL backup directory to a temporary
# location, then tar the contents and remove the tmp directory.
#
set -eo pipefail

# Temporary Dir Name
tmpDir=kc-etl-tmp

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

# Grab the Current Context for Prompt
currentContext=$(kubectl config current-context)

echo "This script will download the Kubecost ETL storage using the following:"
echo "  Kubectl Context: $currentContext"
echo "  Namespace: $namespace"
echo "  ETL Directory: $etlDir"
echo -n "Would you like to continue [y/N]? "
read -r r

if [ "$r" == "${r#[y]}" ]; then
  echo "Exiting..."
  exit 0
fi

# Create a temporary directory to write files
echo "Creating temporary directory $tmpDir..."
mkdir $tmpDir

# Grab the Pod Name of the cost-analyzer pod
podName=$(kubectl get pods -n "$namespace" -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')

# Create a kubectl debug container to use as an ephemeral passthrough
# tar, used by kubectl cp, is no longer in Kubecost's base image 
# we can remove this ephemeral container by restarting the deployment at the end of the script
kubectl debug -n "$namespace"  "$podName" --image=busybox --container=ephemeral --target=cost-model --attach=false -- sh -c "sleep infinity"

# Copy the Files to tmp directory
echo "Copying ETL Files from $namespace/$podName:$etlDir to $tmpDir..."
kubectl cp --container=ephemeral "$namespace"/"$podName":/proc/1/root"$etlDir" $tmpDir

# Archive the directory
tar cfz kubecost-etl.tar.gz $tmpDir

# Delete the temporary directory
rm -rf $tmpDir

# Log tar creation messages
echo "ETL Archive Created: kubecost-etl.tar.gz"
echo "Done"

# Restart to remove the ephemeral container
echo -n "Would you like to restart the Kubecost deployment to remove the ephemeral container [y/N]? "
read -r r

if [ "$r" == "${r#[y]}" ]; then
  echo "Exiting..."
  exit 0
fi

echo "Restarting the application"
kubectl -n "$namespace" rollout restart deployment/kubecost-cost-analyzer