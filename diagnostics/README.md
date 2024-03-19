# Simple Log Collector for Kubecost

This script is designed to collect essential information about a Kubernetes cluster, with a focus on environments utilizing Kubecost for cost monitoring. It gathers various details such as cluster configuration, node information, pod statuses, service configurations, and more. Additionally, it fetches values from the Kubecost Helm chart for further analysis.

## Usage

1. **Prerequisites**: Ensure that `kubectl` and `helm` are installed and configured to interact with your Kubernetes cluster.

2. **Download the Script**: Download the script `kubernetes_diagnostics.sh` to your local machine.

3. **Execute the Script**: Run the script in your terminal by navigating to the directory containing the script and executing the following command:
   
   ```bash
   bash kubernetes_diagnostics.sh

## Review Outputs
The script will start gathering information about your Kubernetes cluster and store it in a temporary directory. Upon completion, it will create a zip file named `kubernetes_diagnostics.zip` containing all the collected information.

## Share Results
Please feel free to share this with Kubecost Support for a full review. 

## Notes
- **Temporary Directory**: The collected information is stored in a temporary directory (`/tmp/kubernetes_diagnostics`). This directory is automatically created if it doesn't exist.
  
- **Script Customization**: Feel free to modify the script according to your specific requirements. You can add or remove commands to tailor the data collection process to your needs.

- **Permissions**: Ensure that you have the necessary permissions to execute the script. If not, you can grant execute permissions using the command `chmod +x kubernetes_diagnostics.sh`.

- **Feedback and Contributions**: Feedback and contributions are welcome! If you have suggestions for improvements or encounter any issues, please feel free to open an issue or submit a pull request on GitHub.

## Acknowledgments
This script was created with the aim of simplifying the process of collecting diagnostic information for Kubernetes clusters, particularly those utilizing Kubecost for cost monitoring.

