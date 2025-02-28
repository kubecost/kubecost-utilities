#!/bin/bash

# Accept Optional Namespace -- default to kubecost
# Accept Optional Container -- default to cost-model otherwise aggregator
# Accept Optional Data Type -- default to assets otherwise allocations
# Accept Optional jq -- parse with jq otherwise print raw
# usage: ./json-output.sh [--namespace namespace] [--container container] [--data-type data_type] [--jq]
# example: ./json-output.sh --namespace kc26 --container aggregator --jq --data-type allocations

run_jq="false"
while [[ $# -gt 0 ]]; do
  case $1 in
    --jq)
      run_jq="true"
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
if [ -z "$container" ]; then
  container="cost-model"
fi

if [ -z "$data_type" ]; then
  data_type="assets"
fi

# Validate container input
if [ "$container" != "cost-model" ] && [ "$container" != "aggregator" ]; then
  echo "Container must be either 'cost-model' or 'aggregator'"
  exit 1
fi

if [ -z "$namespace" ]; then
  namespace=$(kubectl config view --minify -o jsonpath='{..namespace}')
  if [ "$namespace" == "default" ] || [ "$namespace" == "" ]; then
    namespace=kubecost
  fi
fi

echo "Namespace: $namespace"

# Find pod running $container container
echo "Finding pod running $container container..."
pod=$(kubectl get pods -n "$namespace" -o json | jq -r ".items[] | select(.spec.containers[].name == \"$container\") | .metadata.name")

if [ -n "$pod" ]; then
    echo "Found pod running $container: $pod"
else
    echo "No pod found running $container container in namespace $namespace"
    exit 1
fi

latest_file=$(kubectl exec -i "$pod" -c $container -n "$namespace" -- ls -1t /var/configs/db/etl/bingen/$data_type/1d/ |head -n1 )

if [ -n "$latest_file" ]; then
    echo "Latest file found: $latest_file"
else
    echo "No files found in /var/configs/db/etl/bingen/$data_type/1d/"
    exit 1
fi
my_file="/var/configs/db/etl/bingen/$data_type/1d/$latest_file"
echo "my_file: $my_file"

echo "Running: kubectl exec -n "$namespace" "$pod" -c $container -- /go/bin/app bingentojson "$my_file""

my_output=$(kubectl exec -n "$namespace" "$pod" -c $container -- /go/bin/app bingentojson "$my_file")
# echo "my_output: $my_output"
# Remove all text before the first {
my_json=$(echo "$my_output" | sed '0,/{/s/^[^{]*//')

if [ "$run_jq" == "true" ]; then
  echo "$my_json" | jq
else
  echo "$my_json"
fi





