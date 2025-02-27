#!/bin/bash

# Accept Optional Namespace -- default to kubecost
namespace=$1
if [ "$namespace" == "" ]; then
  namespace=$(kubectl config view --minify -o jsonpath='{..namespace}')
  if [ "$namespace" == "default" ] || [ "$namespace" == "" ]; then
    namespace=kubecost
  fi
fi

echo "Namespace: $namespace"

# Find pod running aggregator container
echo "Finding pod running aggregator container..."
pod=$(kubectl get pods -n "$namespace" -o json | jq -r '.items[] | select(.spec.containers[].name == "aggregator") | .metadata.name')

if [ -n "$pod" ]; then
    echo "Found pod running aggregator: $pod"
else
    echo "No pod found running aggregator container in namespace $namespace"
    exit 1
fi

latest_file=$(kubectl exec -i "$pod" -c aggregator -n "$namespace" -- ls -1t /var/configs/db/etl/bingen/allocations/1d/ |head -n1 )

if [ -n "$latest_file" ]; then
    echo "Latest file found: $latest_file"
else
    echo "No files found in /var/configs/db/etl/bingen/allocations/1d/"
    exit 1
fi
my_file="/var/configs/db/etl/bingen/allocations/1d/$latest_file"
echo "my_file: $my_file"

echo "Running: kubectl exec -i -n "$namespace" "$pod" -c aggregator -- /go/bin/app bingentojson "$my_file""

kubectl exec -i -n "$namespace" "$pod" -c aggregator -- /go/bin/app bingentojson "$my_file"




