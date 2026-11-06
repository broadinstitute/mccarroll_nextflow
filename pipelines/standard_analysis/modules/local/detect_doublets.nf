process DETECT_DOUBLETS {
    tag "$sample_name"
    publishDir "${params.output_dir}/doublets", mode: 'copy'
    
    input:
    path dge_subset
    path assignments
    val sample_name
    
    output:
    path "${sample_name}.doublets.tsv", emit: doublets
    path "${sample_name}.doublets_plot.pdf", emit: plot
    
    script:
    """
    DetectDoublets.py \\
        --input ${dge_subset} \\
        --assignments ${assignments} \\
        --output ${sample_name}.doublets.tsv \\
        --plot ${sample_name}.doublets_plot.pdf
    """
}
