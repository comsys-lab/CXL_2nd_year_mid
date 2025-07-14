import re
from collections import defaultdict, Counter
import csv
import argparse

def analyze_address_access(file_path, query_limit=10000):
    # Regular expression to extract key and address
    pattern = re.compile(r"Key: (\d+), address: (0x[0-9a-fA-F]+)")
    query_pattern = "/points/query"

    # Dictionary to store access counts per address
    address_access_count = defaultdict(int)
    total_lines = 0
    key_lines = 0
    query_count = 0

    with open(file_path, 'r') as file:
        print(f"file opened")
        for line in file:
            total_lines += 1

            # Check for "/points/query"
            if query_pattern in line:
                query_count += 1
                # Print progress every 10 queries
                if query_count % 10 == 0:
                    print(f"Processed {query_count} '/points/query' lines so far...")

                if query_count >= query_limit:
                    print(f"Query limit of {query_limit} reached. Stopping analysis.")
                    break

            # Check for key and address patterns
            match = pattern.search(line)
            if match:
                key_lines += 1
                key, address_hex = match.groups()
                # Increment the count for the specific address
                address_access_count[(key, address_hex)] += 1

    # sort address_access_count by count value
    sorted_address_access_count = dict(sorted(address_access_count.items(), key=lambda item: item[1], reverse=True))

    # Calculate the total number of unique addresses
    total_unique_addresses = len(address_access_count)

    return sorted_address_access_count, total_lines, key_lines, total_unique_addresses, query_count

def argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vectordb-file-path", type=str, help="Path to the vectorDB log file")
    parser.add_argument("--query-limit", type=int, default=10000, help="Limit the analysis to a certain number of queries")
    parser.add_argument("--csv-output-file", type=str, default="access_count_sorted.csv", help="Output file for sorted address access count")
    args = parser.parse_args()
    return args

if __name__ == "__main__":
    args = argument_parser()
    vectordb_file_path = args.vectordb_file_path
    query_limit = args.query_limit

    print(f"starting")

    sorted_address_access_count, total_lines, key_lines, total_unique_addresses, query_count = analyze_address_access(vectordb_file_path, query_limit)

    # Save the results to a CSV file
    csv_output_file = "access_count_sorted.csv"
    with open(csv_output_file, "w", newline='') as csvfile:
        csv_writer = csv.writer(csvfile)
        csv_writer.writerow(["Rank","Key", "Address", "Access Count"])

        for rank, ((key, address), count) in enumerate(sorted_address_access_count.items(), start=1):
            csv_writer.writerow([rank, key, address, count])
    
    print(f"Results saved to {csv_output_file}")