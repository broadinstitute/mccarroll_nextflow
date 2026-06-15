process MERGE_BARCODE_CORRECTION_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}"

    script:
    output_file = "${library}.corrected_barcode_metrics"

    """
    MergeBarcodeCorrectionMetrics \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        --DELETE_INPUTS false
    """
}