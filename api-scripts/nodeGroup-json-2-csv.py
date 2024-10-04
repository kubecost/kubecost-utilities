# usage: python3 nodeGroup-json-2-csv.py <.json file or url>
# when passing a url, the output is printed to stdout in csv format
# when passing a file, a csv file is created in the current working directory with .csv appended to the filename

import json
import csv
import sys

def flatten_data(json_data):
    flattened = []
    data = json_data.get('data', {})
    for cluster, node_groups in data.items():
        for node_group, details in node_groups.items():
            # print(cluster,"/",node_group,details.get('warning', '').replace('\n', '').replace('\t', ''))
            if details.get('recommendation', {}) is None:
                row = {
                    'Cluster': cluster,
                    'NodeGroup': node_group,
                    'MonthlySavings': '',
                    'CurrentCount': details.get('current', {}).get('count', ''),
                    'CurrentNodeType': details.get('current', {}).get('name', ''),
                    'CurrentMonthlyRate': details.get('current', {}).get('monthlyRate', ''),
                    'CurrentTotalVCPUs': details.get('current', {}).get('totalVCPUs', ''),
                    'CurrentTotalRAMGiB': details.get('current', {}).get('totalRAMGiB', ''),
                    'CurrentVCPUUtilization': details.get('current', {}).get('vCPUUtilization', ''),
                    'CurrentRAMGiBUtilization': details.get('current', {}).get('RAMGiBUtilization', ''),
                    'RecommendedCount': '',
                    'RecommendedNodeType': details.get('warning', '').replace('\n', '').replace('\t', ''),
                    'RecommendedMonthlyRate': '',
                    'RecommendedTotalVCPUs': '',
                    'RecommendedTotalRAMGiB': '',
                    'RecommendedVCPUUtilization': '',
                    'RecommendedRAMGiBUtilization': ''
                }
            else:
                row = {
                    'Cluster': cluster,
                    'NodeGroup': node_group,
                    'MonthlySavings': details.get('recommendation', {}).get('monthlyRate', '') - details.get('current', {}).get('monthlyRate', ''),
                    'CurrentCount': details.get('current', {}).get('count', ''),
                    'CurrentNodeType': details.get('current', {}).get('name', ''),
                    'CurrentMonthlyRate': details.get('current', {}).get('monthlyRate', ''),
                    'CurrentTotalVCPUs': details.get('current', {}).get('totalVCPUs', ''),
                    'CurrentTotalRAMGiB': details.get('current', {}).get('totalRAMGiB', ''),
                    'CurrentVCPUUtilization': details.get('current', {}).get('vCPUUtilization', ''),
                    'CurrentRAMGiBUtilization': details.get('current', {}).get('RAMGiBUtilization', ''),
                    'RecommendedCount': details.get('recommendation', {}).get('count', ''),
                    'RecommendedNodeType': details.get('recommendation', {}).get('name', ''),
                    'RecommendedMonthlyRate': details.get('recommendation', {}).get('monthlyRate', ''),
                    'RecommendedTotalVCPUs': details.get('recommendation', {}).get('totalVCPUs', ''),
                    'RecommendedTotalRAMGiB': details.get('recommendation', {}).get('totalRAMGiB', ''),
                    'RecommendedVCPUUtilization': details.get('recommendation', {}).get('vCPUUtilization', ''),
                    'RecommendedRAMGiBUtilization': details.get('recommendation', {}).get('RAMGiBUtilization', '')
                }
            flattened.append(row)
    return flattened

def json_to_csv():
    if "http" in sys.argv[1].lower():
        import requests

        try:
            response = requests.get(sys.argv[1])
            response.raise_for_status()  # Raise an exception for bad status codes
            json_data = response.json()
        except requests.RequestException as e:
            print(f"Error fetching data from URL: {e}")
            return
    else:
        try:
            json_file = sys.argv[1]
            csv_file = sys.argv[1] + ".csv"
            with open(json_file, 'r') as f:
                json_data = json.load(f)
        except IOError as e:
            print(f"Error reading JSON file: {e}")
            return

    flattened_data = flatten_data(json_data)

    # with open(json_file, 'r') as f:
    #     json_data = json.load(f)

    # flattened_data = flatten_data(json_data)

    if flattened_data:
        keys = flattened_data[0].keys()
        if "http" in sys.argv[1]:
            import io
            csv_output = io.StringIO()
            writer = csv.DictWriter(csv_output, fieldnames=keys)
            writer.writeheader()
            writer.writerows(flattened_data)
            print(csv_output.getvalue())
        else:
            with open(csv_file, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=keys)
                writer.writeheader()
                writer.writerows(flattened_data)
            print(f"CSV file '{csv_file}' has been written.")
    else:
        print("No data to write to CSV.")

# Usage
json_to_csv()