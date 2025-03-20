# usage: python requestSizing-json-2-csv.py <csv to output> <http requestSizing query>
# example: python requestSizing-json-2-csv.py requestSizing.csv "https://demo.kubecost.xyz/model/savings/requestSizingV2?algorithmCPU=max&algorithmRAM=max&filter=&targetCPUUtilization=0.65&targetRAMUtilization=0.65&window=3d&sortByOrder=descending&offset=0&limit=5"
# For ease of use, use the kubecost UI to generate the requestSizing query with applicable filters and copy it from the browser inspect>network tab and find the requestSizingV2 query
# This will be slow

import json
import csv
import sys

import requests

if len(sys.argv) != 3:
    print("usage: python requestSizing-json-2-csv.py <csv to output> <http requestSizing query>")
    exit(1)

def flatten_data(json_data):
    flattened = []
    recommendations = json_data.get('Recommendations', [])
    for rec in recommendations:
        labels, namespace_labels = get_labels(rec.get('clusterID', ''), rec.get('namespace', ''), rec.get('controllerKind', ''), rec.get('controllerName', ''), rec.get('containerName', ''))
        row = {
            'clusterID': rec.get('clusterID', ''),
            'namespace': rec.get('namespace', ''),
            'controllerKind': rec.get('controllerKind', ''),
            'controllerName': rec.get('controllerName', ''),
            'containerName': rec.get('containerName', ''),
            'recommendedRequest_cpu': rec.get('recommendedRequest', {}).get('cpu', ''),
            'recommendedRequest_memory': rec.get('recommendedRequest', {}).get('memory', ''),
            'latestKnownRequest_cpu': rec.get('latestKnownRequest', {}).get('cpu', ''),
            'latestKnownRequest_memory': rec.get('latestKnownRequest', {}).get('memory', ''),
            'averageUsage_cpu': rec.get('averageUsage', {}).get('cpu', ''),
            'averageUsage_memory': rec.get('averageUsage', {}).get('memory', ''),
            'normalizedAverageUsage_cpuInMilliCores': rec.get('normalizedAverageUsage', {}).get('cpuInMilliCores', ''),
            'normalizedAverageUsage_memoryInMiB': rec.get('normalizedAverageUsage', {}).get('memoryInMiB', ''),
            'maxUsage_cpu': rec.get('maxUsage', {}).get('cpu', ''),
            'maxUsage_memory': rec.get('maxUsage', {}).get('memory', ''),
            'normalizedMaxUsage_cpuInMilliCores': rec.get('normalizedMaxUsage', {}).get('cpuInMilliCores', ''),
            'normalizedMaxUsage_memoryInMiB': rec.get('normalizedMaxUsage', {}).get('memoryInMiB', ''),
            'monthlySavings_cpu': rec.get('monthlySavings', {}).get('cpu', ''),
            'monthlySavings_memory': rec.get('monthlySavings', {}).get('memory', ''),
            'monthlySavings_total': rec.get('monthlySavings', {}).get('total', ''),
            'currentEfficiency_cpu': rec.get('currentEfficiency', {}).get('cpu', ''),
            'currentEfficiency_memory': rec.get('currentEfficiency', {}).get('memory', ''),
            'currentEfficiency_total': rec.get('currentEfficiency', {}).get('total', ''),
            'labels': labels,
            'namespaceLabels': namespace_labels
        }
        flattened.append(row)
    return flattened

def get_labels(clusterID, namespace, controllerKind, controllerName, containerName):
    baseUrl = sys.argv[2].split("/model/")[0]
    allocationAPI = baseUrl + "/model/allocation"
    query_params = (
        "?window=3d"
        "&aggregate=unaggregated"
        "&idle=false"
        "&accumulate=false"
        "&filter="
        f"cluster:\"{clusterID}\""
        f"+namespace:\"{namespace}\""
        f"+controllerKind:\"{controllerKind}\""
        f"+controllerName:\"{controllerName}\""
        f"+container:\"{containerName}\""
    )
    # This will take a while to run
    print(f"Getting labels for {allocationAPI + query_params}")
    response = requests.get(allocationAPI + query_params)
    response.raise_for_status()
    json_data = response.json()
    
    # Get the first item from data array (if it exists)
    if json_data.get('data') and len(json_data['data']) > 0:
        # Get the first key from the first item
        first_key = next(iter(json_data['data'][0]))
        labels = json_data['data'][0][first_key]['properties'].get('labels', {})
        namespace_labels = json_data['data'][0][first_key]['properties'].get('namespaceLabels', {})
        return json.dumps(labels, ensure_ascii=False), json.dumps(namespace_labels, ensure_ascii=False)
    return '{}', '{}'


def json_to_csv():
    if "http" in sys.argv[2].lower():
        import requests
        print(sys.argv[2])
        try:
            response = requests.get(sys.argv[2])
            response.raise_for_status()  # Raise an exception for bad status codes
            json_data = response.json()
        except requests.RequestException as e:
            print(f"Error fetching data from URL: {e}")
            return
    else:
        print(f"usage: python requestSizing-json-2-csv.py <csv to output> <http requestSizing query>")
        exit(1)

    flattened_data = flatten_data(json_data)

    # with open(json_file, 'r') as f:
    #     json_data = json.load(f)

    # flattened_data = flatten_data(json_data)

    if flattened_data:
        keys = flattened_data[0].keys()
        if "csv" in sys.argv[1]:
            import io
            csv_output = io.StringIO()
            writer = csv.DictWriter(csv_output, fieldnames=keys)
            writer.writeheader()
            writer.writerows(flattened_data)
            print(csv_output.getvalue())

            with open(sys.argv[1], 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=keys)
                writer.writeheader()
                writer.writerows(flattened_data)
            print(f"CSV file '{sys.argv[1]}' has been written.")
        else:
            print("Usage: python requestSizing-json-2-csv.py <csv to output> <http requestSizing query>")
    else:
        print("No data to write to CSV.")

# Usage
json_to_csv()