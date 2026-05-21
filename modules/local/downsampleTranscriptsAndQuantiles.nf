process DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
        tuple val(meta), path(selectedCells)
        path molBc
    output:
    tuple val(meta), path("${output_file}"), emit: umiSaturationHistogram

    script:
    output_file = "${meta.id}.umi_saturation_histogram.txt"
    """
    DownsampleTranscriptsAndQuantiles \
          --INPUT ${molBc} \
          --CELL_BC_FILE ${selectedCells} \
          --OUTPUT_HISTOGRAM_FILE ${output_file}
    """
}