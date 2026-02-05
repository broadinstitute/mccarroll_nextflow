process TRANSCRIPT_DOWNSAMPLING {
    tag "$sample_name"
    publishDir "${params.output_dir}/downsampling", mode: 'copy'
    
    input:
    path collapsed_umis_files
    path dge_subset
    val sample_name
    val num_downsample
    
    output:
    path "${sample_name}.downsampling_*.pdf", emit: downsampling_plots
    
    script:
    def collapsed_input = collapsed_umis_files instanceof List ? 
        collapsed_umis_files.join(' ') : collapsed_umis_files
    """
    TranscriptDownsampling.py \\
        --collapsed-umis ${collapsed_input} \\
        --dge ${dge_subset} \\
        --output-prefix ${sample_name}.downsampling \\
        --num-downsample ${num_downsample}
    """
}
