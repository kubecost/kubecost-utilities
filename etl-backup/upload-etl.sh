#!/bin/bash
#
# This script will use kubectl to copy the ETL backup directory to a temporary
# location, then tar the contents and remove the tmp directory.
#

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


# Grab the Pod Name of the cost-analyzer pod
podName=`kubectl get pods -n $namespace -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}'`

# Accept etl .tar file to upload
etlFile=$3
if [ "$etlFile" == "" ]; then
  etlFile=kubecost-etl.tar.gz
fi

# Copy the Files to tmp directory
echo "Copying $etlFile to $namespace/$podName"

kubectl cp -c cost-model $etlFile $namespace/$podName:/var/configs/kubecost-etl.tar.gz

# Exec into the pod and replace the ETL
echo "Execing into the pod and replacing $etlDir "
set -e
kubectl exec -n $namespace pod/$podName -- sh -c " \
  rm -rf /var/configs/kc-etl-tmp && \
  tar xzf /var/configs/kubecost-etl.tar.gz --directory /var/configs && \
  [ -d /var/configs/kc-etl-tmp ] && rm -rf $etlDir \
    || (echo '$etlFile is invalid' && exit 1) && \
  mv /var/configs/kc-etl-tmp $etlDir"

# Restart the application to pull ETL data into memory
echo "Restarting the application"
echo "Restoring cost-model image to $costModelImage"
kubectl patch deployment $deploymentName -p '{"spec":{"template":{"spec":{"containers":[{"name":"cost-model","image":"'$costModelImage'","command":null,"args":null}]}}}}' --type=strategic -n $namespace
