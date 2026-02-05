process DISCOVER_META_GENES {
    tag "$sample_name"
    publishDir "${params.output_dir}/meta_genes", mode: 'copy'
    
    input:
    path dge_subset
    val sample_name
    
    output:
    path "${sample_name}.meta_genes.tsv", emit: meta_genes
    path "${sample_name}.meta_genes_plot.pdf", emit: plot
    
    script:
    """
    DiscoverMetaGenes.py \\
        --input ${dge_subset} \\
        --output ${sample_name}.meta_genes.tsv \\
        --plot ${sample_name}.meta_genes_plot.pdf
    """
}
