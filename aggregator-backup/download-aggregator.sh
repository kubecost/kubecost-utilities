#!/bin/bash
#
# This script will use kubectl to copy the aggregator data files to a temporary
# location, then tar the contents and remove the temp directory

# Temporary Directory Name
tmpDir=kc-aggregator-tmp

# Accept Optional Namespace -- default to kubecost
namespace=$1
if [ "$namespace" == "" ]; then
    namespace=kubecost
fi

# Accept Optional duckdb Storage Directory -- default to /var/configs/waterfowl/duckdb
aggDir=$2
if [ "$aggDir" == "" ]; then
    aggDir=/var/configs/waterfowl/duckdb
fi

# Grab the Current Context for Prompt
currentContext=`kubectl config current-context`

echo "This script will downlaod the Aggregator Read DB using the following:"
echo "  Kubectl Context: $currentContext"
echo "  Namespace: $namespace"
echo "  Kubecost Aggregator Directory: $aggDir"
echo -n "Would you like to continue [Y/n]? "
read r

if [ "$r" == "${r#[Y]}" ]; then
  echo "Exiting..."
  exit 0
fi

# Grab the Pod Name of the aggregator pod
# If you use zsh and this line isn't working, it is likely due to your partial line response
# and zsh adds a % delimeter to the end. Add the following line to your ~/.zshrc file:
# PROMPT_EOL_MARK=''
podName=`kubectl get pods -n $namespace -l app=aggregator -o jsonpath='{.items[0].metadata.name}'`

# Download file from container and store it in the same filename in current directory
echo "Copying aggregator Files from $namespace/$podName:$aggDir to $tmpDir..."
kubectl cp $namespace/$podName:$aggDir/ ./$tmpDir/

# Archive the directory
tar cfz kubecost-aggregator.tar.gz $tmpDir

# Delete the temporary directory
rm -rf $tmpDir

# Log final messages
echo "DB Archive Created kubecost-aggregator.tar.gz"
echo "Done"
