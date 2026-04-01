process COUNT_BARCODE_SEQUENCES {
    label 'process_single'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        val baseRange
        val barcodedRead
        val libraryName
        path bams
        path allowedBarcodes

    output:
    path "${output_file}", emit: barcodeCounts

    script:
    output_file = "${libraryName}.expected_barcode_metrics.gz"
    """
    CountBarcodeSequences --VALIDATION_STRINGENCY SILENT --BASE_RANGE '${baseRange}' \
        --BARCODED_READ '${barcodedRead}' --ALLOWED_BARCODES '${allowedBarcodes}' \
        --OUTPUT '${output_file}' --INPUT ${bams.join(' --INPUT ')}
    """
}