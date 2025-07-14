import re
from collections import defaultdict, Counter
import argparse
import csv
import pandas as pd

PAGE_SIZE = 4096  # 페이지 크기 (4KB)

def read_address_counts_from_csv(csv_file):
    """Read address access counts from a CSV file produced by address_count_analysis.py"""
    address_access_count = {}

    df = pd.read_csv(csv_file)
    for index, row in df.iterrows():
        address = row['Address']
        count = row['Access Count']
        address_access_count[address] = count
    
    return address_access_count

def analyze_page_byte_usage(csv_file, access_threshold=200):
    # Use CSV file directly
    address_access_count = read_address_counts_from_csv(csv_file)
    
    # Filter addresses by access threshold
    filtered_addresses = {
        addr for addr, count in address_access_count.items() if count >= access_threshold
    }
    
    print(f"Number of addresses with access count >= {access_threshold}: {len(filtered_addresses)}")

    # Calculate page byte usage
    page_byte_usage = defaultdict(int)
    for address_hex in filtered_addresses:
        try:
            address = int(address_hex, 16)
            size = 1536  # Address size is fixed at 1536 bytes
            start_page = address // PAGE_SIZE * PAGE_SIZE
            end_page = (address + size - 1) // PAGE_SIZE * PAGE_SIZE

            if start_page == end_page:  # Data fits in one page
                page_byte_usage[start_page] += size
            else:  # Data spans multiple pages
                # Size in the start page
                size_in_start_page = start_page + PAGE_SIZE - address
                page_byte_usage[start_page] += size_in_start_page

                # Size in the end page
                size_in_end_page = (address + size) - end_page
                page_byte_usage[end_page] += size_in_end_page
        except ValueError:
            # Skip addresses that can't be converted to integers
            continue

    # Count pages by Bytes Used
    byte_usage_distribution = Counter(page_byte_usage.values())

    return byte_usage_distribution

def argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv-file", type=str, required=True, help="Path to the CSV file with address access counts")
    parser.add_argument("--access-threshold", type=int, default=200, help="Minimum number of accesses to consider an address")
    args = parser.parse_args()
    return args

# Example usage
if __name__ == "__main__":
    args = argument_parser()
    csv_file = args.csv_file
    access_threshold = args.access_threshold

    byte_usage_distribution = analyze_page_byte_usage(
        csv_file=csv_file, 
        access_threshold=access_threshold
    )

    # Save the results to byte_usage_distribution.log
    output_file = "access_count_page.log"
    with open(output_file, "w") as f:
        f.write("Bytes Used\tNumber of Pages\n")
        for bytes_used, num_pages in sorted(byte_usage_distribution.items()):
            f.write(f"{bytes_used}\t{num_pages}\n")

    print(f"Results saved to {output_file}")