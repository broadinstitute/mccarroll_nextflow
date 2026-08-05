process COLLAPSE_BARCODE_CHIMERIC_TRANSCRIPTS {
    tag "${sample_name}_${interval}"
    publishDir "${params.output_dir}/collapsed_umis", mode: 'copy'
    
    input:
    val interval
    path molbc_umis
    val sample_name
    val bead_synthesis_error_rate
    val bead_synthesis_size
    
    output:
    path "${sample_name}.${interval}.collapsed_umis.txt.gz", emit: collapsed_umis
    
    script:
    """
    CollapseBarcodeChimericTranscripts.py \\
        --input ${molbc_umis} \\
        --output ${sample_name}.${interval}.collapsed_umis.txt.gz \\
        --interval ${interval} \\
        --synthesis-error-rate ${bead_synthesis_error_rate} \\
        --synthesis-size ${bead_synthesis_size}
    """
}
