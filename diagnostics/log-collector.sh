#!/bin/bash

# Temporary directory
tmp_dir="/tmp/kubernetes_diagnostics"
mkdir -p "${tmp_dir}"

# Execute kubectl commands
execute_kubectl() {
    command=$1
    output_file="${tmp_dir}/$(echo "${command}" | tr -s ' ' '_').yaml"
    echo "Running command: kubectl ${command}"
    kubectl "${command}" -o yaml > "${output_file}"
    echo "Output saved to: ${output_file}"
    echo ""
}

# Execute helm command
execute_helm() {
    command=$1
    output_file="${tmp_dir}/helm_values_kubecost.yaml"
    echo "Running command: ${command}"
    ${command} > "${output_file}"
    echo "Output saved to: ${output_file}"
    echo ""
}

# Define kubectl commands to execute
kubectl_commands=(
    "cluster-info"
    "get nodes"
    "describe nodes"
    "get pods --all-namespaces -o wide"
    "get services --all-namespaces -o wide"
    "get endpoints --all-namespaces -o wide"
    "get deployments --all-namespaces -o wide"
    "get rs --all-namespaces -o wide"
    "get statefulsets --all-namespaces -o wide"
    "get daemonsets --all-namespaces -o wide"
    "get pv"
    "get pvc --all-namespaces -o wide"
    "get namespaces"
    "get events --all-namespaces"
)

# Execute kubectl commands
for cmd in "${kubectl_commands[@]}"; do
    execute_kubectl "${cmd}"
done

# Execute helm command
execute_helm "helm get values -a kubecost -n kubecost"

# Zip all output files
zip_file="${tmp_dir}/kubernetes_diagnostics.zip"
echo "Zipping all output files to: ${zip_file}"
zip -j "${zip_file}" "${tmp_dir}"/*.yaml
echo "Zip file created: ${zip_file}"

