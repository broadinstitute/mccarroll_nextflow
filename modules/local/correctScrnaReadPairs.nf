process CORRECT_SCRNA_READ_PAIRS {
    label 'process_single'
    label 'correction'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    memory {
        // TODO: It looks like this value is not being used based on looking at .command.run
        // 7e-8 is the MemoryReservationMbPerByte used by Zamboni
        long totalInputSizeBytes = bams.collect { it.size() }.sum()
        long memoryMb = (long) (totalInputSizeBytes * 7e-8)
        // Set a minimum memory requirement to avoid issues with very small input files.
        1.MB * Math.max(memoryMb, 16000)
    }

    input:
        path bams
        val baseRange
        val barcodedRead
        val libraryName
        path allowedBarcodeCounts
        val output_file
        val tagBothReads

    output:
    path "${output_file}", emit: correctedBam
    path "${metrics_file}", emit: correctedBarcodeMetrics

    script:
    if (!output_file.any()) {
        def firstBam = bams.getAt(0)
        output_file = firstBam.getName().replace(".bam", ".cbc_corrected.bam")
    }
    metrics_file = output_file.replace(".cbc_corrected.bam", "corrected_barcode_metrics")
    //          "METRICS" -> outputMetrics,
    """
    CorrectScrnaReadPairs --INPUT ${bams.join(' --INPUT ')}  --BASE_RANGE '${baseRange}' \
        --BARCODED_READ '${barcodedRead}' \
        --ALLOWED_BARCODE_COUNTS '${allowedBarcodeCounts}' \
        --OUTPUT '${output_file}' \
        --BARCODE_TAG '${params.cellBarcodeTag}' \
        --TAG_BOTH_READS ${tagBothReads} \
        --METRICS '${metrics_file}'
    """
}