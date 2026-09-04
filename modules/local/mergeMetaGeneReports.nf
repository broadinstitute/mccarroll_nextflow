process MERGE_META_GENE_REPORTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        val library
        path metaGeneReports

    output:
    path "${output_file}", emit: metaGeneReport
    tuple val("${task.process}"), val('MergeMetaGeneReports'), eval("MergeMetaGeneReports --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeMetaGeneReports
    
    script:
    output_file = "${library}.meta_gene_report.txt"
    """
    MergeMetaGeneReports \
          --INPUT ${metaGeneReports.join(' --INPUT ')} \
          --OUTPUT ${output_file}
    """
}