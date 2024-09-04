import argparse
import os
from os.path import getsize
import pandas as pd
from math import log10
import numpy as np

def main(args): # A FastA file
    # Load completeness and contamination (mag,completeness,contamination)
    raw_df = pd.read_csv(args.checkm2, header = 0, sep = '\t')
    summ_df = raw_df[['Name', 'Completeness', 'Contamination', 'Contig_N50', 'Genome_Size', 'GC_Content']]
    summ_df.columns = ['mag', 'completeness', 'contamination', 'N50', 'size', 'GC']
    summ_df['mag'] = summ_df['mag'].astype(str)  # Otherwise, interpreted as int
    summ_df['completeness'] = summ_df['completeness'].astype(float)  # Otherwise, interpreted as str
    summ_df['contamination'] = summ_df['contamination'].astype(float)  # Otherwise, interpreted as str
    summ_df['N50'] = summ_df['N50'].astype(int)  # Otherwise, interpreted as str
    # Load strain heterogeneity
    strain_df = pd.read_csv(args.checkm1, header = 0, sep = '\t')
    strain_df = strain_df[['Bin Id', 'Strain heterogeneity']]
    strain_df.columns = ['mag', 'strain_het']
    strain_df['mag'] = strain_df['mag'].astype(str)  # Otherwise, interpreted as int
    strain_df['strain_het'] = strain_df['strain_het'].astype(float)  # Otherwise, interpreted as str
    # Load MAG relative abundance
    ra_df = pd.read_csv(args.mag_ra, header = 0)
    ra_df['mag'] = ra_df['mag'].astype(str)  # Otherwise, interpreted as int
    # Load taxonomy-based contamination
    raw_df = pd.read_csv(args.gunc, header = 0, sep = '\t')
    gunc_df = raw_df[['genome', 'clade_separation_score', 'n_effective_surplus_clades']]
    gunc_df.rename(columns = {'genome' : 'mag'}, inplace = True)
    gunc_df['mag'] = gunc_df['mag'].astype(str)  # Otherwise, interpreted as int
    # Load MAG tRNA and rRNA gene content
    gene_cts_df = pd.read_csv(args.gene_cts, header = None)
    gene_cts_df.columns = ['mag', 'num_cds', 'num_trna', 'num_rrna_total', 'num_rrna_5s', 'num_rrna_16s', 'num_rrna_23s']
    gene_cts_df['mag'] = gene_cts_df.apply(lambda row : str(row[0]).split('.')[1], axis = 1) # Reshape bin.X into X
    # Load classification results
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
    for df in [gunc_df, strain_df, gene_cts_df, ra_df, gtdb_df, diff_df, quas_df]: # size_df, cmsq_df,
        summ_df = pd.merge(summ_df, df, on = 'mag', how = 'outer')
    # Add in standard quality thresholds
    conditions = [
        ((summ_df['completeness'] < 50)& (summ_df['contamination'] < 10)),
        ((summ_df['completeness'] >= 50) & (summ_df['completeness'] <= 90) & (summ_df['contamination'] < 10)),
        ((summ_df['completeness'] > 90) & (summ_df['contamination'] > 5) & (summ_df['contamination'] < 10)),
        ((summ_df['completeness'] > 90) & (summ_df['contamination'] <= 5)),
        ((summ_df['completeness'] > 90) & (summ_df['contamination'] < 5) & (summ_df['num_trna'] >= 18) & (summ_df['num_rrna_5s'] > 0) & (summ_df['num_rrna_16s'] > 0) & (summ_df['num_rrna_23s'] > 0)),
    ]
    summ_df['MIMAG_Quality'] = np.select(conditions, ['Low', 'Medium', 'Medium', 'High', 'Near_Complete'], default = np.nan)
    summ_df['GUNC_Status'] = np.where((summ_df['clade_separation_score'] < 0.45), 'Pass', 'Fail')
    # Defaults are A = 1, B = 0.5, C = 5, D = 1
    summ_df['Overall_Score'] = summ_df.apply(lambda row : row[1] + 0.5 * log10(row[3]) - 5 * row[2] - row[8], axis = 1)
    # summ_df['completeness'] + 0.5 * log10(summ_df['N50']) - 5 * summ_df['contamination'] - summ_df['strain_het']
    summ_df.to_csv(args.output, header = True, index = False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkm2", help="CheckM2 report")
    parser.add_argument("checkm1", help="CheckM1 report (strain heterogeneity)")
    parser.add_argument("mag_ra", help="MAG relative abundance report")
    parser.add_argument("gunc", help="GUNC report")
    parser.add_argument("gtdb", help="GTDB classification report")
    parser.add_argument("diff", help="DNADiff report")
    parser.add_argument("quast", help="QUAST report")
    parser.add_argument("gene_cts", help="rRNA and total gene counts")
    parser.add_argument("output", help="Summary output")
    args = parser.parse_args() 
    main(args)
