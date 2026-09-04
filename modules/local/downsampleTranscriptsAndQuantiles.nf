process DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(selectedCells)
        path molBc
    output:
    tuple val(meta), path("${output_file}"), emit: umiSaturationHistogram
    tuple val("${task.process}"), val('DownsampleTranscriptsAndQuantiles'), eval("DownsampleTranscriptsAndQuantiles --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_DownsampleTranscriptsAndQuantiles
    
    script:
    output_file = "${meta.id}.umi_saturation_histogram.txt"
    """
    DownsampleTranscriptsAndQuantiles \
          --INPUT ${molBc} \
          --CELL_BC_FILE ${selectedCells} \
          --OUTPUT_HISTOGRAM_FILE ${output_file}
    """
}