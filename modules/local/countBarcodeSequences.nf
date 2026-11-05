process COUNT_BARCODE_SEQUENCES {
    tag "${libraryName}"
    cpus  { 1                   }
    memory  { 8.GB * task.attempt + AllowListUtils.memoryForAllowList(allowedBarcodes) }
    time  { 4.h  * task.attempt }

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
        --INPUT ${bams.join(' --INPUT ')}
    """
}
