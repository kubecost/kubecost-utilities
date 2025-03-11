#!/bin/bash
# usage: ./backup-settings.sh [--container container] [--namespace namespace]
# example: ./backup-settings.sh --container cost-model --namespace kubecost

container="aggregator"

while [[ $# -gt 0 ]]; do
  case $1 in
    --container)
      container="$2"
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
echo "Looking for pod running $container container in namespace $namespace"

pod=$(kubectl get pods -n "$namespace" -o json | jq -r ".items[] | select(.spec.containers[].name == \"$container\") | .metadata.name")

if ! [ -n "$pod" ]; then
    echo "No pod found running $container container in namespace $namespace"
    exit 1
fi

mkdir -p $namespace-backup
OUTPUT_DIR=$namespace-backup

FILES_TO_COPY=$(kubectl exec -n $namespace -c $container ${pod} -- ls -1 /var/configs/)

for file in $FILES_TO_COPY; do
  if [[ $file == *.json ]]; then
    kubectl exec -n $namespace -c $container ${pod} -- cat /var/configs/$file > $OUTPUT_DIR/$file
    echo "Copied $file"
  else
    continue
  fi
done

# copy alerts
FILES_TO_COPY=$(kubectl exec -n $namespace -c $container ${pod} -- ls -1 /var/configs/alerts/)

for file in $FILES_TO_COPY; do
  if [[ $file == *.json ]]; then
    mkdir -p $OUTPUT_DIR/alerts
    kubectl exec -n $namespace -c $container ${pod} -- cat /var/configs/alerts/$file > $OUTPUT_DIR/alerts/$file
    echo "Copied $file"
  else
    continue
  fi
done

# copy cloud-integration
FILES_TO_COPY=$(kubectl exec -n $namespace -c $container ${pod} -- ls -1 /var/configs/cloud-integration/)

for file in $FILES_TO_COPY; do
  if [[ $file == *.json ]]; then
    mkdir -p $OUTPUT_DIR/cloud-integration
    kubectl exec -n $namespace -c $container ${pod} -- cat /var/configs/cloud-integration/$file > $OUTPUT_DIR/cloud-integration/$file
    echo "Copied $file"
  else
    continue
  fi
done

# Remove empty configs
find $OUTPUT_DIR -type f -size -3c -delete

echo "The following files were copied to $OUTPUT_DIR"
ls -l $OUTPUT_DIR