process MERGE_SINGLE_CELL_RNA_SEQ_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}", emit: mergedSingleCellRnaSeqMetrics
    tuple val("${task.process}"), val('MergeSingleCellRnaSeqMetrics'), eval("MergeSingleCellRnaSeqMetrics --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeSingleCellRnaSeqMetrics

    script:
    output_file = "${library}.fracIntronicExonicPerCell.txt.gz"
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    """
    MergeSingleCellRnaSeqMetrics \
        -m ${javaMemMb}m \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}
