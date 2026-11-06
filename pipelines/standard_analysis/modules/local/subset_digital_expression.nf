process SUBSET_DIGITAL_EXPRESSION {
    tag "$sample_name"
    publishDir "${params.output_dir}/subset_dge", mode: 'copy'
    
    input:
    path dge_loom
    val sample_name
    
    output:
    path "${sample_name}.subset.loom", emit: dge_subset
    
    script:
    """
    SubsetDigitalExpression.py \\
        --input ${dge_loom} \\
        --output ${sample_name}.subset.loom \\
        --sample ${sample_name}
    """
}
