#!/bin/bash

# This script will exec into a kubecost pod and output the json for a given data type
# It will default to the cost-model container and assets data type if no arguments are provided
# It will output raw json by default, or pipe to jq if the --jq flag is provided

# usage: ./json-output.sh [--namespace namespace] [--container container] [--data-type data_type] [--jq]
# example: ./json-output.sh --namespace kc26 --container aggregator --jq --data-type allocations

json_output="false"
while [[ $# -gt 0 ]]; do
  case $1 in
    --jq)
      json_output="true"
      shift
      ;;
    --container)
      container="$2"
      shift 2
      ;;
    --data-type)
      data_type="$2"
      shift 2
      ;;
    --namespace)
      namespace="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Set defaults if not provided
if [[ -z "${container}" ]]; then
  container="cost-model"
fi

if [[ -z "${data_type}" ]]; then
  data_type="assets"
fi

# Validate container input
if [[ "${container}" != "cost-model" ]] && [[ "${container}" != "aggregator" ]]; then
  echo "Container must be either 'cost-model' or 'aggregator'"
  exit 1
fi

if [[ -z "${namespace}" ]]; then
  namespace=$(kubectl config view --minify -o jsonpath='{..namespace}')
  if [[ "${namespace}" == "default" ]] || [[ "${namespace}" == "" ]]; then
    namespace=kubecost
  fi
fi

pod=$(kubectl get pods -n "${namespace}" -o json | jq -r ".items[] | select(.spec.containers[].name == \"${container}\") | .metadata.name")

if ! [[ -n "${pod}" ]]; then
    echo "No pod found running ${container} container in namespace ${namespace}"
    exit 1
fi

latest_file=$(kubectl exec -i "${pod}" -c "${container}" -n "${namespace}" -- ls -1t /var/configs/db/etl/bingen/"${data_type}"/1d/ |head -n1 )

if ! [[ -n "${latest_file}" ]]; then
    echo "No files found in /var/configs/db/etl/bingen/${data_type}/1d/"
    exit 1
fi
my_file="/var/configs/db/etl/bingen/${data_type}/1d/${latest_file}"

my_output=$(kubectl exec --quiet -n "${namespace}" "${pod}" -c "${container}" -- /go/bin/app bingentojson "${my_file}")
# echo "my_output: $my_output"
# Remove all text before the first {
my_json=$(echo "${my_output}" | sed '0,/{/s/^[^{]*//')

if [[ "${json_output}" == "true" ]]; then
  echo "${my_json}" 
else
  echo "Namespace: ${namespace}"
  echo "Finding pod running ${container} container..."
  echo "Found pod running ${container}: ${pod}"
  echo "Latest file found: ${latest_file}"
  echo "my_file: ${my_file}"
  echo "Running: kubectl exec --quiet -n \"${namespace}\" \"${pod}\" -c ${container} -- /go/bin/app bingentojson \"${my_file}\""
  echo "${my_json}"
fi
