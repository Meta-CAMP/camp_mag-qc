import argparse
import os
from os.path import getsize
import pandas as pd
import numpy as np

def main(args): # A FastA file
    # Load completeness and contamination (mag,completeness,contamination)
    raw_df = pd.read_csv(args.checkm, header = 0, sep = '\t')
    # raw_df['Name'] = raw_df.apply(lambda row : str(row[0]).split('.')[1], axis = 1) # Reshape bin.X into X
    summ_df = raw_df[['Name', 'Completeness', 'Contamination', 'Contig_N50', 'Genome_Size', 'GC_Content']]
    # summ_df = summ_df.reset_index()
    summ_df.columns = ['mag', 'completeness', 'contamination', 'N50', 'size', 'GC']
    summ_df['mag'] = summ_df['mag'].astype(str)  # Otherwise, interpreted as int
    # Load strain heterogeneity
    # cmsq_df = pd.read_csv(cmseq, sep = '\t', header = None)
    # cmsq_df[0] = cmsq_df.apply(lambda row : str(row[0]).split('/')[-1].split('.')[0], axis = 1) # Reshape /path/to/X.* into X
    # cmsq_df.columns = ['mag', 'strain_heterogeneity']
    # Load N50, MAG size (in terms of bp), GC
    # size_dct = {}
    # for line in open(args.n50_sz):
    #     info = line.strip().split('\t')
    #     size_dct[info[0]] = eval(info[1])
    # raw_df = pd.DataFrame(data = size_dct).transpose()
    if getsize(args.gtdb) != 0: # If there were classification results
        # Load taxonomic classification (all levels)
        raw_df = pd.read_csv(args.gtdb, sep = '\t')
        gtdb_df = raw_df[['user_genome', 'classification']]
        gtdb_df.columns = ['mag', 'classification']
        gtdb_df['mag'] = gtdb_df['mag'].astype(str) # Otherwise, interpreted as int
        # Load MAG-reference aligned length, reference genome coverage, ANI
        raw_df = pd.read_csv(args.diff, sep = '\t', header = None)
        raw_df[0] = raw_df.apply(lambda row : str(row[0]).split('/')[-1].split('.')[0], axis = 1) # Reshape /path/to/X.* into X
        raw_df.columns = ['mag', 'ref', 'ref_len', 'ref_cov', 'bin_size', 'bin_cov', 'ANI']
        diff_df = raw_df[['mag', 'bin_cov', 'ref_cov', 'ANI']]
    else:
        raw_lst = [[m, 'NA'] for m in summ_df['mag']]
        gtdb_df = pd.DataFrame(raw_lst, columns = ['mag', 'classification'])
        raw_lst = [[m, 'NA', 0, 0] for m in summ_df['mag']]
        diff_df = pd.DataFrame(raw_lst, columns = ['mag', 'bin_cov', 'ref_cov', 'ANI'])
    if getsize(args.quast) != 0: # If there were classification results
        # Load reference genome-based completion, misassembly, and unaligned statistics from QUAST report
        quas_df = pd.read_csv(args.quast, header = 0)
        quas_df['mag'] = quas_df['mag'].astype(str)
    else:
        raw_lst = [[m, 0, 0, 0, 'NA', 'NA', 'NA', 'NA', 'NA'] for m in summ_df['mag']]
        quas_df = pd.DataFrame(raw_lst, columns = ['mag', 'genome_fraction', 'NG50', 'NA50', 'num_misassemb', 'prop_misassemb_ctgs', 'prop_misassemb_len', 'prop_unaln_ctgs', 'prop_unaln_len'])
    # Put all of the dataframes together and output
    for df in [gtdb_df, diff_df, quas_df]: # size_df, cmsq_df,
        summ_df = pd.merge(summ_df, df, on = 'mag', how = 'outer')
    # Add in standard quality thresholds
    summ_df['Quality'] = np.where((summ_df['completeness'] >= 90) & (summ_df['contamination'] <= 5), 'High quality', 'Medium quality') # Quality labels for DNAdiff figure
    summ_df.to_csv(args.output, header = True, index = False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkm", help="CheckM report")
    # parser.add_argument("n50_sz", help="Bin size report")
    parser.add_argument("gtdb", help="GTDB classification report")
    parser.add_argument("diff", help="DNADiff report")
    parser.add_argument("quast", help="QUAST report")
    parser.add_argument("output", help="Summary output")
    args = parser.parse_args() 
    main(args)
