#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 <namespace> <folder with settings to upload>"
  exit 1
fi

NAMESPACE=$1
OUTPUT_DIR=$2

kubecost_aggregator=$(kubectl get pod -n $NAMESPACE -l app=aggregator -o jsonpath='{.items[0].metadata.name}')

for file in $OUTPUT_DIR/*; do
  if [ -f $file ]; then
    echo "Uploading $file"
    cat "$file" | kubectl exec -i -n "$NAMESPACE" $kubecost_aggregator -c aggregator -- sh -c "cat > /var/configs/$(basename "$file")"
    echo "Uploaded $file"
  fi
done