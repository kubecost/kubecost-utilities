#!/bin/bash
#
# This script will use kubectl to copy the ETL backup directory to a temporary
# location, then tar the contents and remove the tmp directory.
#

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
currentContext=`kubectl config current-context`
# Get the current cost-model image before patching
# Find the deployment name with "cost-analyzer" in it
deploymentName=$(kubectl get deployments -n $namespace -o jsonpath='{.items[?(@.metadata.name contains "cost-analyzer")].metadata.name}' | tr ' ' '\n' | grep cost-analyzer)

echo "This script will download the Kubecost ETL storage using the following:"
echo "  Kubectl Context: $currentContext"
echo "  Namespace: $namespace"
echo "  Deployment: $deploymentName"
echo "  ETL Directory: $etlDir"
echo -n "Would you like to continue [y/N]? "
read r

if [ "$r" == "${r#[y]}" ]; then
  echo "Exiting..."
  exit 0
fi

if [ -z "$deploymentName" ]; then
    echo "Error: No deployment found with 'cost-analyzer' in its name in namespace $namespace"
    exit 1
fi

echo "Found deployment: $deploymentName"

costModelImage=$(kubectl get deployment $deploymentName -n $namespace -o jsonpath='{.spec.template.spec.containers[?(@.name=="cost-model")].image}')

kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"cost-model","image":"busybox"}]}}}}' --type=strategic -n $namespace
kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"cost-model","command":["sleep"],"args":["infinity"]}]}}}}' --type=strategic -n $namespace
kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"cost-model","livenessProbe":null,"readinessProbe":null}]}}}}' --type=strategic -n $namespace
kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"aggregator","livenessProbe":null,"readinessProbe":null}]}}}}' --type=strategic -n $namespace
kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"cloud-cost","livenessProbe":null,"readinessProbe":null}]}}}}' --type=strategic -n $namespace
kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"cost-analyzer-frontend","livenessProbe":null,"readinessProbe":null}]}}}}' --type=strategic -n $namespace

# Wait for the cost-analyzer deployment to be ready
echo "Waiting for cost-analyzer deployment to be ready..."
kubectl rollout status deployment/$deploymentName -n $namespace --timeout=300s

if [ $? -ne 0 ]; then
  echo "Error: Deployment did not become ready within 5 minutes"
  exit 1
fi

echo "Cost-analyzer deployment is ready"


# Create a temporary directory to write files
echo "Creating temporary directory $tmpDir..."
mkdir $tmpDir

# Grab the Pod Name of the cost-analyzer pod
podName=`kubectl get pods -n $namespace -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}'`

# Copy the Files to tmp directory
echo "Copying ETL Files from $namespace/$podName:$etlDir to $tmpDir..."
kubectl cp -c cost-model $namespace/$podName:$etlDir $tmpDir

# Archive the directory
tar cfz kubecost-etl.tar.gz $tmpDir

# Delete the temporary directory
rm -rf $tmpDir

echo "Restoring cost-model image to $costModelImage"
kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"cost-model","image":"'$costModelImage'","command":null,"args":null}]}}}}' --type=strategic -n $namespace

# Log final messages
echo "ETL Archive Created: kubecost-etl.tar.gz"
echo "Done"
