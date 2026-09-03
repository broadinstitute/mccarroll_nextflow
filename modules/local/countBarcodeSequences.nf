process COUNT_BARCODE_SEQUENCES {
    label 'process_single'

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
    def barcodedRead = parsedBeadStructure.getReadIndexForElementType(BeadStructure.ElementType.Cellular) + 1 // Convert from zero-based to one-based indexing for Java command line argument
    """
    CountBarcodeSequences --VALIDATION_STRINGENCY SILENT --BASE_RANGE '${baseRange}' \
        --BARCODED_READ '${barcodedRead}' --ALLOWED_BARCODES '${allowedBarcodes}' \
        --OUTPUT '${output_file}' --INPUT ${bams.join(' --INPUT ')}
    """
}