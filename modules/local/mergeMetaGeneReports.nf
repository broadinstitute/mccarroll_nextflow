process MERGE_META_GENE_REPORTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
        val library
        path metaGeneReports

    output:
    path "${output_file}", emit: metaGeneReport

    script:
    output_file = "${library}.meta_gene_report.txt"
    """
    MergeMetaGeneReports \
          --INPUT ${metaGeneReports.join(' --INPUT ')} \
          --OUTPUT ${output_file}
    """
}