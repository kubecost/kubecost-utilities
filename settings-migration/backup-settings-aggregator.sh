#!/bin/bash

if [ -z "$1" ]; then
  echo "No namespace provided, using default: kubecost"
  echo "Usage: $0 <namespace>"
  echo "Continue with namespace: kubecost?"
  read -p "Press enter to continue"
  NAMESPACE=kubecost
else
   NAMESPACE=$1
fi

AGGREGATOR_POD=$(kubectl get pod -n $NAMESPACE -l app=aggregator -o jsonpath='{.items[0].metadata.name}')
mkdir -p $NAMESPACE-backup
OUTPUT_DIR=$NAMESPACE-backup

FILES_TO_COPY=$(kubectl exec -n $NAMESPACE -c aggregator ${AGGREGATOR_POD} -- ls -1 /var/configs/)

for file in $FILES_TO_COPY; do
  if [[ $file == *.json ]]; then
    kubectl exec -n $NAMESPACE -c aggregator ${AGGREGATOR_POD} -- cat /var/configs/$file > $OUTPUT_DIR/$file
    echo "Copied $file"
  else
    continue
  fi
done

# Remove empty configs
find $OUTPUT_DIR -type f -size -3c -delete

echo "The following files were copied to $OUTPUT_DIR"
ls -l $OUTPUT_DIR

