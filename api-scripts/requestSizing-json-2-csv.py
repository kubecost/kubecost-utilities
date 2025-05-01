#!/usr/bin/env python3

# usage: python requestSizing-json-2-csv.py <csv to output> <http requestSizing query>
# example: python requestSizing-json-2-csv.py requestSizing.csv "https://demo.kubecost.xyz/model/savings/requestSizingV2?algorithmCPU=max&algorithmRAM=max&filter=&targetCPUUtilization=0.65&targetRAMUtilization=0.65&window=3d&sortByOrder=descending&offset=0&limit=5"
# To get the requestSizing query, use the kubecost UI to build the query with applicable filters and copy it from the browser inspect>network. It is the requestSizingV2 query
# If SSO is enabled in kubecost, you can set the KUBECOST_API_KEY environment variable to your API key. This is only needed if querying the kubecost frontend.
# Alternatively, if SSO is enabled: if you port-forward directly to the aggregator service, you can use the 9008 port that does not require authentication.
# To use a port-forwarded aggregator service, run `kubectl port-forward svc/KUBECOST_RELEASE_NAME-aggregator -n KUBECOST_NAMESPACE 9008:9008`
# When port-forwarding, the requestSizing query is available at http://localhost:9008/savings/requestSizingV2 (note that /model is not part of the path)
# As of version 2.7, this request can take a long time to complete. As an example, and unfiltered 30 day window with 500,000 containers takes 1.5 hours. The Kubecost UI has a 300 second timeout by default. A port-forwarded aggregator service does not have this timeout.
 

import json
import csv
import sys
import os
import time

import requests

# export KUBECOST_API_KEY=YOURKEY
# This is only needed if querying the kubecost frontend and SSO is enabled
KUBECOST_API_KEY = os.environ.get('KUBECOST_API_KEY', None)

if len(sys.argv) != 3:
    print("usage: python requestSizing-json-2-csv.py <csv to output> <http requestSizing query>")
    exit(1)

def flatten_data(json_data):
    flattened = []
    recommendations = json_data.get('Recommendations', [])
    for i, rec in enumerate(recommendations, 1):
        if i % 10000 == 0:
            print(f"Processed {i} rows...")
        
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
            'currentEfficiency_total': rec.get('currentEfficiency', {}).get('total', '')
        }
        flattened.append(row)
    print(f"Processed {i} rows...")
    return flattened


def json_to_csv():
    query_processing_time = 0
    if "http" in sys.argv[2].lower():
        print(sys.argv[2])
        try:
            print(f"Running query: {sys.argv[2]}")
            if KUBECOST_API_KEY is not None: print(f"Using API Key: {KUBECOST_API_KEY[:4]}{'*' * (len(KUBECOST_API_KEY) - 4)}")
            start_time = time.time()
            response = requests.get(sys.argv[2], headers={"X-API-KEY": f"{KUBECOST_API_KEY}"})
            response.raise_for_status()  # Raise an exception for bad status codes
            json_data = response.json()
            query_processing_time = time.time() - start_time
        except requests.RequestException as e:
            print(f"Error fetching data from URL: {e}")
            print(f"Request took {time.time() - start_time:.2f} seconds")
            return None, query_processing_time
    else:
        print(f"usage: python requestSizing-json-2-csv.py <csv to output> <requestSizing query>, including http/https")
        exit(1)

    flattened_data = flatten_data(json_data)

    if flattened_data:
        keys = flattened_data[0].keys()
        if "csv" in sys.argv[1]:
            import io
            csv_output = io.StringIO()
            writer = csv.DictWriter(csv_output, fieldnames=keys)
            writer.writeheader()
            writer.writerows(flattened_data)

            with open(sys.argv[1], 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=keys)
                writer.writeheader()
                writer.writerows(flattened_data)
            print(f"CSV file '{sys.argv[1]}' has been written.")
        else:
            print("Usage: python requestSizing-json-2-csv.py <csv to output> <http requestSizing query>")
    else:
        print("No data to write to CSV.")
    
    return flattened_data, query_processing_time

# Usage
result, processing_time = json_to_csv()
print(f"Query processing time: {processing_time:.2f} seconds")