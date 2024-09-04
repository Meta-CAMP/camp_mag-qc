#!/usr/bin/env python
"""calc_mag_ra.py 
Calculate the average coverage of each MAG in the sample based on its member contig's coverage.
"""


import argparse
import pandas as pd


def main(args):
    # Load the TSV file into a pandas DataFrame
    df = pd.read_csv(args.f_in, sep='\t')
    
    # Get rid of the unbinned contigs
    df = df[df['Bin Id'] != 'unbinned']
    
    # Group the data by 'Bin Id' and calculate the weighted average of 'Coverage' by 'Sequence length (bp)'
    df['Weighted Coverage'] = df['Coverage'] * df['Sequence length (bp)']
    
    # Calculate the total length of sequences for each MAG
    total_length_per_mag = df.groupby('Bin Id')['Sequence length (bp)'].sum()
    
    # Calculate the total weighted coverage for each MAG
    total_weighted_coverage_per_mag = df.groupby('Bin Id')['Weighted Coverage'].sum()
    
    # Calculate the average coverage for each MAG
    average_coverage_per_mag = total_weighted_coverage_per_mag / total_length_per_mag
    
    # Add columns
    final_df = pd.DataFrame(average_coverage_per_mag).reset_index()
    final_df.columns = ['mag', 'avg_read_cov']
    final_df['avg_mag_ra'] = final_df['avg_read_cov'] / final_df['avg_read_cov'].sum()
    final_df = final_df[['mag', 'avg_mag_ra']]
    final_df.to_csv(args.f_out, header = True, index = False)
    


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("f_in", help="Input contig coverage TSV.")
    parser.add_argument("f_out", help="Output MAG coverage CSV")
    args = parser.parse_args()
    main(args)
