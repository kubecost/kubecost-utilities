#!/bin/bash
#
# This script will use kubectl to copy the ETL backup directory to a temporary
# location, then tar the contents and remove the tmp directory.
#
set -eo pipefail

# Accept Optional Namespace -- default to kubecost
namespace=$1
if [[ "${namespace}" == "" ]]; then
  namespace=kubecost
fi

# Accept Optional ETL Store Directory -- default to /var/configs/db/etl
etlDir=$2
if [[ "${etlDir}" == "" ]]; then
  etlDir=/var/configs/db/etl
fi

# Hostpath used by ephemeral container
hostpath=/proc/1/root  

# Accept etl .tar file to upload
etlFile=$3
if [[ "${etlFile}" == "" ]]; then
  etlFile=kubecost-etl.tar.gz
fi

# Grab the Current Context for Prompt
currentContext=$(kubectl config current-context)

echo "This script will delete the Kubecost ETL storage and replace it with ETL files using the following:"
echo "  Kubectl Context: ${currentContext}"
echo "  Namespace: ${namespace}"
echo "  ETL File (source): ${etlFile}"
echo "  ETL Directory (destination): ${etlDir}"
echo -n "Would you like to continue [y/N]? "
read -r r

if [[ "${r}" == "${r#[y]}" ]]; then
  echo "Exiting..."
  exit 0
fi

# Grab the Pod Name of the cost-analyzer pod
podName=$(kubectl get pods -n "${namespace}" -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')

# Grab the Deployment name of the cost-analyzer pod
deployName=$(kubectl get deploy -n "${namespace}" -l app=cost-analyzer -o jsonpath='{.items[0].metadata.name}')

# Create a kubectl debug container to use as an ephemeral passthrough
# tar, used by kubectl cp, is no longer in Kubecost's base image 
# we remove this ephemeral container by restarting the deployment at the end of the script
kubectl debug -n "${namespace}"  "${podName}" \
  --image=busybox \
  --container=ephemeral \
  --target=cost-model \
  --attach=false \
  -- sh -c "sleep infinity"

# Wait until the ephemeral container shows up in pod status
# (loops until it finds a Running state or times out after ~30s)
for i in {1..30}; do
  state=$(kubectl get pod "${podName}" -n "${namespace}" -o jsonpath="{.status.ephemeralContainerStatuses[?(@.name=='ephemeral')].state.running}")
  [[ -n "${state}" ]] && break
  sleep 1
done

# Copy the Files to tmp directory via the ephemeral container
echo "Copying ETL Files from ${etlFile} to ${podName}..."
kubectl cp --container=ephemeral "${etlFile}" "${namespace}"/"${podName}":"${hostpath}"/var/configs/kubecost-etl.tar.gz

# Exec into the pod and replace the ETL
echo "Execing into the pod and replacing ${etlDir} "
kubectl exec -n "${namespace}" pod/"${podName}" --container=ephemeral -- sh -c " \
  rm -rf ${hostpath}/var/configs/kc-etl-tmp && \
  tar xzf ${hostpath}/var/configs/kubecost-etl.tar.gz --directory ${hostpath}/var/configs && \
  [ -d ${hostpath}/var/configs/kc-etl-tmp ] && rm -rf ${hostpath}/${etlDir} \
    || (echo '${etlFile} is invalid' && exit 1) && \
  mv ${hostpath}/var/configs/kc-etl-tmp ${hostpath}/${etlDir}"

# Restart the application to pull ETL data into memory
echo "Restarting the application"
kubectl -n "${namespace}" rollout restart deployment/"${deployName}"
