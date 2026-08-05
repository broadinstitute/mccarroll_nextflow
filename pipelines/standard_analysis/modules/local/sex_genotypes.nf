process SEX_GENOTYPES {
    tag "$sample_name"
    publishDir "${params.output_dir}/sex_genotypes", mode: 'copy'
    
    input:
    path dge_subset
    path sex_gene_names
    val sample_name
    
    output:
    path "${sample_name}.sex_genotypes.tsv", emit: genotypes
    path "${sample_name}.sex_genotypes_plot.pdf", emit: plot
    
    script:
    """
    SexGenotypes.py \\
        --input ${dge_subset} \\
        --sex-genes ${sex_gene_names} \\
        --output ${sample_name}.sex_genotypes.tsv \\
        --plot ${sample_name}.sex_genotypes_plot.pdf
    """
}
