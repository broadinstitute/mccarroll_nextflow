process ASSIGN_CELLS_TO_SAMPLES {
    tag "$sample_name"
    publishDir "${params.output_dir}/assignments", mode: 'copy'
    
    input:
    path dge_subset
    path individual_names
    path annotation_gtf
    val sample_name
    val nref
    
    output:
    path "${sample_name}.assignments.tsv", emit: assignments
    path "${sample_name}.assignments_plot.pdf", emit: plot
    
    script:
    """
    AssignCellsToSamples.py \\
        --input ${dge_subset} \\
        --individuals ${individual_names} \\
        --annotation ${annotation_gtf} \\
        --output ${sample_name}.assignments.tsv \\
        --plot ${sample_name}.assignments_plot.pdf \\
        --nref ${nref}
    """
}
