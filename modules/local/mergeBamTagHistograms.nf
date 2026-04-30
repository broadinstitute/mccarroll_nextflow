process MERGE_BAM_TAG_HISTOGRAMS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics
    val extension

    output:
    path "${output_file}"

    script:
    output_file = "${library}.${extension}"

    """
    MergeBamTagHistograms \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}