process DROPULATION_PLOT {
    tag "$sample_name"
    publishDir "${params.output_dir}/dropulation", mode: 'copy'
    
    input:
    path assignments
    val sample_name
    
    output:
    path "${sample_name}.dropulation.pdf", emit: plot
    
    script:
    """
    DropulationPlot.py \\
        --input ${assignments} \\
        --output ${sample_name}.dropulation.pdf
    """
}
