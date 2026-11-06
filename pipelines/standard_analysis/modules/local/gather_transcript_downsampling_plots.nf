process GATHER_TRANSCRIPT_DOWNSAMPLING_PLOTS {
    tag "$sample_name"
    publishDir "${params.output_dir}/downsampling_summary", mode: 'copy'
    
    input:
    path downsampling_plots
    val sample_name
    
    output:
    path "${sample_name}.downsampling_summary.pdf", emit: summary_plot
    
    script:
    def plots_input = downsampling_plots instanceof List ? 
        downsampling_plots.join(' ') : downsampling_plots
    """
    GatherTranscriptDownsamplingPlots.py \\
        --inputs ${plots_input} \\
        --output ${sample_name}.downsampling_summary.pdf
    """
}
