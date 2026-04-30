process MERGE_SINGLE_CELL_RNA_SEQ_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}"

    script:
    output_file = "${library}.fracIntronicExonicPerCell.txt.gz"

    """
    MergeSingleCellRnaSeqMetrics \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}