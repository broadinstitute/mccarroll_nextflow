process SPLIT_BAM_BY_CELL {
    errorStrategy 'retry'
    maxRetries 3
    cpus    { 1                   }
    memory  {
        taggedBams.each { bam -> log.info "taggedBam size: ${bam.size()} bytes (${bam})" }
        // This is triple the 7e-8 used by Zamboni, because for some reason there were stlll OOMs
        int memoryMb = (taggedBams*.size().sum() * 21e-8 * task.attempt).intValue()
        1.MB * Math.max(memoryMb, 8000)
    }
    time    { 4.h  * task.attempt }

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        val libraryName
        path taggedBams
        val targetBamSizeMBytes

    output:
    path "${libraryName}.[0-9]*.unmapped.bam", emit: splitBams
    path "${report}", emit: splitBamReport
    path "${manifest}", emit: splitBamManifest
    path "${bam_list}", emit: bamList

    script:
    report = "${libraryName}.split_bam_report"
    manifest = "${libraryName}.split_bam_manifest.gz"
    bam_list = "${libraryName}.unmapped.bam_list"
   def avail_mem = task.memory ? (task.memory.mega * 0.8).intValue() : 7000
     """
    SplitBamByCell -m ${avail_mem}M --VALIDATION_STRINGENCY SILENT \
        --OUTPUT ${libraryName}.__SPLITNUM__.unmapped.bam --INPUT ${taggedBams.join(' --INPUT ')} \
        --TARGET_BAM_SIZE ${targetBamSizeMBytes}M --REPORT ${report} --OUTPUT_MANIFEST ${manifest} \
        --OUTPUT_LIST ${bam_list}
    """
}