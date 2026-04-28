process CORRECT_SCRNA_READ_PAIRS {
    label 'process_single'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    memory {
        // TODO: It looks like this value is not being used based on looking at .command.run
        // 7e-8 is the MemoryReservationMbPerByte used by Zamboni
        long totalInputSizeBytes = bams.collect { bam -> bam.size() }.sum()
        long memoryMb = (long) (totalInputSizeBytes * 7e-8)
        // Set a minimum memory requirement to avoid issues with very small input files.
        1.MB * Math.max(memoryMb, 16000)
    }

    input:
        tuple(val(meta), path (bams))
        val beadStructure
        val cellBarcodeTag
        val libraryName
        path allowedBarcodeCounts
        val output_file
        val tagBothReads

    output:
    tuple(val(meta), path("${output_file}"), emit: correctedBam)
    tuple(val(meta), path("${metrics_file}"), emit: correctedBarcodeMetrics)

    script:
    if (!output_file.any()) {
        def firstBam = bams.getAt(0)
        output_file = firstBam.getName().replace(".raw.bam", ".cbc_corrected.bam")
    }
    metrics_file = output_file.replace(".cbc_corrected.bam", ".corrected_barcode_metrics")
    def parsedBeadStructure = new BeadStructure(beadStructure)
    def baseRange = parsedBeadStructure.getBaseRangeForElementType(BeadStructure.ElementType.Cellular)
    def barcodedRead = parsedBeadStructure.getReadIndexForElementType(BeadStructure.ElementType.Cellular) + 1 // Convert from zero-based to one-based indexing for Java command line argument
    """
    CorrectScrnaReadPairs --INPUT ${bams.join(' --INPUT ')}  --BASE_RANGE '${baseRange}' \
        --BARCODED_READ '${barcodedRead}' \
        --ALLOWED_BARCODE_COUNTS '${allowedBarcodeCounts}' \
        --OUTPUT '${output_file}' \
        --BARCODE_TAG '${cellBarcodeTag}' \
        --TAG_BOTH_READS ${tagBothReads} \
        --METRICS '${metrics_file}'
    """
}