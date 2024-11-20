#!/usr/bin/env bash
#
# This script will use kubectl to copy the aggregator data files to a temporary
# location, then tar the contents and remove the temp directory

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
# If you use zsh and this line isn't working, it is likely due to your partial line response
# and zsh adds a % delimeter to the end. Add the following line to your ~/.zshrc file:
# PROMPT_EOL_MARK=''
podName="$(kubectl get pods -n "$namespace" -l app=aggregator -o jsonpath='{.items[0].metadata.name}')"

# find read db file
readDbFile="$(kubectl exec -c aggregator "$podName" -n "$namespace" -- find /var/configs/waterfowl -type f -name '*.read')"
echo "Found read db file: $readDbFile"

# Download file from container and store it in the same filename in current directory
echo "Copying aggregator Files from $namespace/$podName:$aggDir to $tmpDir..."
kubectl exec -c aggregator "$podName" -n "$namespace" -- bash -c "base64 $readDbFile" | base64 -d > "./$tmpDir/$podName.read.b64"

# Then decode it locally
base64 -d -i "./$tmpDir/$podName.read.b64" -o "./$tmpDir/$podName.read"

# Clean up the base64 encoded file
rm "./$tmpDir/$podName.read.b64"

# Archive the directory
tar cfz kubecost-aggregator.tar.gz $tmpDir && \
  echo "Archive created successfully" || \
  echo "Failed to create archive\nNote: if you have an error like: Cannot stat: No such file or directory\nYou will need to run the script again because the Read-DB changed while running the script."
# Delete the temporary directory
rm -rf $tmpDir

# Log final messages
echo "DB Archive Created kubecost-aggregator.tar.gz"
echo "Done"
