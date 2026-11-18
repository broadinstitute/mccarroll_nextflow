process COUNT_BARCODE_SEQUENCES {
    tag "${libraryName}"
    label 'process_low'
    // CPUs come from the label.  Memory is set in conf/modules.config (withName: COUNT_BARCODE_SEQUENCES)
    // because a label's memory would otherwise override a directive here.

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val beadStructure
    val libraryName
    path bams
    path allowedBarcodes

    output:
    path "${output_file}", emit: barcodeCounts
    tuple val("${task.process}"), val('CountBarcodeSequences'), eval("CountBarcodeSequences --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_CountBarcodeSequences

    script:
    output_file = "${libraryName}.expected_barcode_metrics.gz"
    def parsedBeadStructure = new BeadStructure(beadStructure)
    def baseRange = parsedBeadStructure.getBaseRangeForElementType(BeadStructure.ElementType.Cellular)
    def barcodedRead = parsedBeadStructure.getReadIndexForElementType(BeadStructure.ElementType.Cellular) + 1
    // Convert from zero-based to one-based indexing for Java command line argument
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    """
    CountBarcodeSequences \
        -m ${javaMemMb}m \
        --VALIDATION_STRINGENCY SILENT \
        --BASE_RANGE '${baseRange}' \
        --BARCODED_READ '${barcodedRead}' \
        --ALLOWED_BARCODES '${allowedBarcodes}' \
        --OUTPUT '${output_file}' \
        --INPUT ${bams.join(' --INPUT ')} \
        --NUM_THREADS ${task.cpus} ${task.ext.libdeflateArgs ?: ''}
    """
}
