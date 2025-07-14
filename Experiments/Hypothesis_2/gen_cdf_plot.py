import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import argparse

def set_plot_style():
    """Plot style config"""
    # font
    # plt.rcParams['font.family'] = 'Arial'
    plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Helvetica', 'Arial']
    plt.rcParams['font.weight'] = 'bold'
    plt.rcParams['font.size'] = 20
    plt.rcParams['axes.labelsize'] = 16
    plt.rcParams['axes.titlesize'] = 16
    plt.rcParams['xtick.labelsize'] = 14
    plt.rcParams['ytick.labelsize'] = 14
    plt.rcParams['legend.fontsize'] = 10
    
    # line
    plt.rcParams['axes.linewidth'] = 2.0
    plt.rcParams['grid.linewidth'] = 0.5

def plot_normalized_distributions(
    csv_file,
    output_file='normalized_address_distributions_cdf.png',
    output_file2='normalized_address_distributions_cdf.svg',
    dpi=300
):
    set_plot_style()
    
    # we use grey-scale color
    color = '#666666'

    fig, ax = plt.subplots(figsize=(8, 4))

    df = pd.read_csv(csv_file)
    x = np.linspace(1, len(df), len(df))
    cdf = df['Access Count'].cumsum() / df['Access Count'].sum()
    ax.plot(x, cdf, 
            '-',
            color=color,
            linewidth=3.5,
            alpha=1.0)
    
    # axis configs
    ax.set_yscale('linear')
    ax.set_xscale('linear')
    ax.set_xlabel(r'Number of Accessed Embedding Vectors ($\times 10^6$)', fontweight='bold', labelpad=10)  # Add x-axis label with padding
    ax.set_ylabel('Access Count (CDF)', fontweight='bold')  # Add y-axis label
    ax.set_xticks([0, 1e7, 2e7, 3e7, 4e7, 5e7, 6e7, 7e7])  # Set x-axis ticks
    ax.set_xticklabels(['0', '10', '20', '30', '40', '50', '60', '70'])  # Set x-axis tick labels
    ax.set_xlim(left=0)  # Start x-axis from 0
    ax.grid(True, axis='y', linestyle='-', alpha=0.5)
    ax.set_ylim(0, 1)

    # title
    # ax.set_title('Normalized Embedding Index Access Distribution', 
    #              pad=20, fontweight='bold')
    
    plt.tick_params(bottom=True, labelbottom=True)  # Enable x-axis ticks and labels

    # the point df['Access_count'] changes from 200 to 199 is the threshold
    # x_threshold = df[df['Access Count'] == 199].index[0]
    # y_threshold = df['Access Count'].cumsum()[x_threshold] / df['Access Count'].sum()

    # # draw threshold line and show the threshold value
    # ax.axvline(x=x_threshold, color='red', linestyle='--', linewidth=2.0)
    # ax.axhline(y=y_threshold, color='red', linestyle='--', linewidth=2.0)

    plt.tight_layout()
    plt.savefig(output_file, dpi=dpi, bbox_inches='tight')
    plt.savefig(output_file2, dpi=dpi, bbox_inches='tight')
    plt.close()
    
    print(f"Graph saved as '{output_file}'")

def print_half_access_info(csv_file):
    df = pd.read_csv(csv_file)
    portion = 55
    total_access = df['Access Count'].sum()
    threshold = total_access * portion * 0.01
    df = df.sort_values(by='Access Count', ascending=False)
    cumulative = 0
    count = 0
    for freq in df['Access Count']:
        cumulative += freq
        count += 1
        if cumulative >= threshold:
            print(f"{csv_file}: {count} addresses for {portion}% access.")
            break

def argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv-file", type=str, required=True, help="CSV file containing address access count")
    return parser.parse_args()

if __name__ == "__main__":

    args = argument_parser()
    csv_file = args.csv_file

    plot_normalized_distributions(csv_file)
    print_half_access_info(csv_file)
