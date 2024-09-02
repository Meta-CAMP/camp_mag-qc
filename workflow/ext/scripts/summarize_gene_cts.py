#!/usr/bin/env python
"""summarize_gene_cts.py 
Summarizes the number of CDSes, genes, mRNAs, tRNAs, total rRNAs, and 23S, 16S, and 5S rRNAs found in a MAG.
"""


import argparse
import pandas as pd


# Create an empty dictionary to store the counts
def main(args):
    data = {'CDS': 0, 'genes': 0, 'mRNA': 0, 'tRNA': 0, 'rRNA_total': 0, 'rRNA_5s': 0, 'rRNA_16s': 0, 'rRNA_23s': 0}
    
    # Open the file and extract counts
    with open(args.f_summ, 'r') as file:
        for line in file:
            line = line.strip()
            if line.startswith('CDS:'):
                data['CDS'] = int(line.split(': ')[1])
            elif line.startswith('gene:'):
                data['genes'] = int(line.split(': ')[1])
            elif line.startswith('mRNA:'):
                data['mRNA'] = int(line.split(': ')[1])
            elif line.startswith('tRNA:'):
                data['tRNA'] = int(line.split(': ')[1])
            elif line.startswith('rRNA:'):
                data['rRNA_total'] = int(line.split(': ')[1])
    
    if data['rRNA_total'] != 0:
        # Read the TSV file into a pandas DataFrame
        df = pd.read_csv(args.f_all, sep='\t')
        # Filter rows where the 'ftype' column is 'rRNA'
        rrna_df = df[df['ftype'] == 'rRNA']
        # Count occurrences of each rRNA type in the 'product' column
        for product in rrna_df['product']:
            if '5S' in product:
                data['rRNA_5s'] += 1
            elif '16S' in product:
                data['rRNA_16s'] += 1
            elif '23S' in product:
                data['rRNA_23s'] += 1
    
    # Convert the dictionary to a pandas DataFrame
    df = pd.DataFrame(data, index = [args.mag])
    df.rename(columns = {'index': 'mag'}, inplace = True)
    df.to_csv(f_out, header = False, index = False)
    

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("f_summ", help="Prokka summary TXT.")
    parser.add_argument("f_all", help="Prokka extended contig-gene annotation TSV")
    parser.add_argument("f_out", help="Output gene count CSV.")
    args = parser.parse_args()
    main(args)
