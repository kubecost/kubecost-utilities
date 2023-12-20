#!/bin/bash
#
# This script will use kubectl to copy the aggregator backup directory 
# into the aggregator container and then restart the container.
# 

set -eo pipefail

# Temporary Directory Name
tmpDir=kc-aggregator-tmp

if [ -d "${tmpDir}" ]; then
    echo "Temp dir '${tmpDir}' already exists. Please manually remove it before running this script."
    exit 1
fi

# Accept Optional Namespace -- default to kubecost
namespace=$1
if [ "$namespace" == "" ]; then
  namespace=kubecost
fi

# Accept Optional aggregator Store Directory -- default to aggDir=/var/configs/waterfowl/duckdb
aggDir=$2
if [ "$aggDir" == "" ]; then
  aggDir=aggDir=/var/configs/waterfowl/duckdb
fi

# Accept aggregator .tar file to upload
aggFile=$3
if [ "$aggFile" == "" ]; then
  aggFile=kubecost-aggregator.tar.gz
fi

if [ -f "$aggFile" ]
then
  echo " $aggFile found, continuing."
else
  echo " File: $aggFile does not exist, please check your file, and try again."
  exit 1
fi

# Grab the Current Context for Prompt
currentContext="$(kubectl config current-context)"
ro=0
derive=0
copy=0

echo "This script can perform 3 different options for loading aggregator data into the container."
echo "  Would you like to:"
echo "  1 Load data in Read only mode (no derivation)"
echo "  2 Load Read data in over write data and re-derive"
echo "  3 Load read/write data as it is in the backup and manually interact"
echo -n "Choose an option [1/2/3]: "
read o
if [ "$o" == "1" ]; then
  ro=1
fi
if [ "$o" == "2" ]; then
  derive=1
fi
if [ "$o" == "3" ]; then
  copy=1
fi

if [ $ro -eq 0 -a $derive -eq 0 -a $copy -eq 0 ]; then 
  echo "  Must select option 1/2/3 to continue. Please try again."
  exit 1
fi


echo "This script will delete the Kubecost aggregator storage and replace it with aggregator files using the following:"
echo "  Kubectl Context: $currentContext"
echo "  Namespace: $namespace"
echo "  ETL File (source): $aggFile"
echo "  ETL Directory (destination): $aggDir"
if [ $ro -eq 1 ]; then
  echo "  Mode: Copy files and set pod to read-only - no derivation..."
fi

if [ $derive -eq 1 ]; then
  echo "  Mode: Copy read file over the write file and derive data..."
fi

if [ $copy -eq 1 ]; then
  echo "  Mode: Copy file as is..."
fi

echo -n "Would you like to continue [Y/n]? "
read r

if [ "$r" == "${r#[Y]}" ]; then
  echo "Exiting..."
  exit 0
fi

fileToSendToContainer=$aggFile
if [ $derive -eq 1 ]; then
  # Prepare files for option selected above.
  tar xzf $aggFile
  pushd $tmpDir
  readFile=`ls | grep "read"`
  writeFile=`ls | grep "write"`
  echo "  Replacing $writeFile with $readFile"
  rm -rf $writeFile
  cp $readFile $writeFile
  for i in $(ls -d */);
  do 
    if [[ $i = v* ]]; then
      readFile="$(ls $i | grep 'read')"
      writeFile="$(ls $i | grep 'write')"
      echo "  Replacing $i/$writeFile with $i/$readFile"
      rm -rf $i/$writeFile
      cp $i/$readFile $i/$writeFile
    fi
  done
  popd
  fileToSendToContainer=kubecost-aggregator-$(date +"%s").tar.gz
  tar cfz $fileToSendToContainer $tmpDir
  rm -rf $tmpDir
fi




# Grab the Pod Name of the aggregator pod
podName=`kubectl get pods -n $namespace -l app=aggregator -o jsonpath='{.items[0].metadata.name}'`

# Grab the Deployment name of the aggregator pod
deployName=`kubectl get deploy -n $namespace -l app=aggregator -o jsonpath='{.items[0].metadata.name}'`

# Copy the Files to tmp directory
echo "Copying aggregator Files from $aggFile to $podName..."
kubectl cp -c cost-model $aggFile $namespace/$podName:/var/configs/kubecost-aggregator.tar.gz

# Exec into the pod and replace the ETL
echo "Execing into the pod and replacing $aggDir "
set -e
kubectl exec -n $namespace pod/$podName -- ash -c " \
  rm -rf /var/configs/$tmpDir && \
  tar xzf /var/configs/kubecost-aggregator.tar.gz --directory /var/configs && \
  [ -d /var/configs/$tmpDir ] && rm -rf $aggDir \
    || (echo '$aggFile is invalid' && exit 1) && \
  mv /var/configs/$tmpDir $aggDir"
  rm -rf /var/configs/$tmpDir

if [ $ro -eq 1 ]; then
# Set Environment Variable for DB_READ_ONLY so that we don't go through
# derivation on the write db, and the read db persists.
kubectl set env deployment/$deployName DB_READ_ONLY=true
fi



# Restart the application to pull ETL data into memory
echo "Restarting the application"
kubectl -n $namespace rollout restart deployment/$deployName
