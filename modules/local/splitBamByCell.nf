process SPLIT_BAM_BY_CELL {
    label 'process_single'
    label 'conversion'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        val libraryName
        path taggedBams

    output:
    path "${libraryName}.[0-9]*.unmapped.bam", emit: splitBams
    path "${report}", emit: splitBamReport
    path "${manifest}", emit: splitBamManifest
    path "${bam_list}", emit: bamList

    script:
    report = "${libraryName}.split_bam_report"
    manifest = "${libraryName}.split_bam_manifest.gz"
    bam_list = "${libraryName}.unmapped.bam_list"
    """
    SplitBamByCell --VALIDATION_STRINGENCY SILENT \
        --OUTPUT ${libraryName}.__SPLITNUM__.unmapped.bam --INPUT ${taggedBams.join(' --INPUT ')} \
        --TARGET_BAM_SIZE ${params.targetBamSizeBytes} --REPORT ${report} --OUTPUT_MANIFEST ${manifest} \
        --OUTPUT_LIST ${bam_list}
    """
}