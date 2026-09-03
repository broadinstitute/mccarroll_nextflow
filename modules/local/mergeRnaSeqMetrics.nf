process MERGE_RNA_SEQ_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}"
    //tuple val("${task.process}"), val('MergeRnaSeqMetrics'), eval("MergeRnaSeqMetrics --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeRnaSeqMetrics
    
    script:
    output_file = "${library}.fracIntronicExonic.txt"

    """
    MergeRnaSeqMetrics \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}