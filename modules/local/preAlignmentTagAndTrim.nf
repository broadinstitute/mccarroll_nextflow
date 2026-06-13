
process PREALIGNMENT_TAG_AND_TRIM {
    label 'process_medium'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(inputBam)
        val fivePrimeAdapter
        val beadStructure
        val cellularBarcodeTag
        val molecularBarcodeTag
        path allowedBarcodes
        val outputExtension
    output:
    tuple val(meta), path("${output_file}"), emit: taggedAndTrimmedBams
    // TODO: emit metrics

    script:
    output_file = meta.id + "." + outputExtension
    def parsedBeadStructure = new BeadStructure(beadStructure)
    def baseRange = parsedBeadStructure.getBaseRangeForElementType(BeadStructure.ElementType.Molecular)
    // Convert from zero-based to one-based indexing for Java command line argument
    def barcodedRead = parsedBeadStructure.getReadIndexForElementType(BeadStructure.ElementType.Molecular) + 1
    def templateRead = parsedBeadStructure.getReadIndexForElementType(BeadStructure.ElementType.Template) + 1
    """
    TagBamWithReadSequenceExtended \
          --I ${inputBam} \
          --O /dev/stdout \
          --SUMMARY ${output_file}.${molecularBarcodeTag}_bam_summary.txt \
          --BASE_RANGE ${baseRange} \
          --BASE_QUALITY 10 \
          --BARCODED_READ ${barcodedRead} \
          --DISCARD_READ true \
          --TAG_BOTH_READS false \
          --TAG_NAME ${molecularBarcodeTag} \
          --NUM_BASES_BELOW_QUALITY 1 \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT | \
    FilterBam \
            --I /dev/stdin \
            --O /dev/stdout \
            --TAG_REJECT XQ \
            --PASSING_READ_THRESHOLD 0.1 \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT | \
    FilterBamByTag \
            --I /dev/stdin \
            --O /dev/stdout \
            --TAG_VALUES_FILE ${allowedBarcodes} \
            --TAG ${cellularBarcodeTag} \
            --ACCEPT_TAG true \
            --SUMMARY ${output_file}.${cellularBarcodeTag}_bam_summary.txt \
            --PASSING_READ_THRESHOLD 0.1 \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT | \
    TrimStartingSequence \
            --I /dev/stdin \
            --O /dev/stdout \
          --OUTPUT_SUMMARY ${output_file}.adapter_trimming_report.txt \
          --SEQUENCE ${fivePrimeAdapter} \
          --MISMATCH_RATE 0.1 \
          --NUM_BASES 5 \
          --LENGTH_TAG Zl \
          --WHICH_READ ${templateRead} \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT | \
          PolyATrimmer \
            --I /dev/stdin \
            --O ${output_file} \
          --OUTPUT_SUMMARY ${output_file}.polyA_trimming_report.txt \
          --MISMATCHES 0 \
          --NUM_BASES 6 \
          --LENGTH_TAG ZL \
          --ADAPTER_TAG ZA \
          --WHICH_READ ${templateRead} \
          --NEW true \
          --VALIDATION_STRINGENCY SILENT
    """
}
