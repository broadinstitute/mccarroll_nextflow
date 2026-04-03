
process PREALIGNMENT_TAG_AND_TRIM {
    label 'process_medium'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
        val libraryName
        path inputBams
        val fivePrimeAdapter
        val beadStructure
        path allowedBarcodes
        val inputExtension
        val outputExtension
    output:
    path "${output_file}", emit: taggedAndTrimmedBams
    // TODO: emit metrics

    script:
    parsedBeadStructure = new BeadStructure(beadStructure)
    print("Bead structure: ${parsedBeadStructure}")
    // TODO: This doesn't seem like the right way to do this, but it works.
    output_file = inputBams.collect({it.getName().replace(inputExtension, outputExtension)} ).head()
    """
    echo $output_file > $output_file
    """
}

/*
"TagBamWithReadSequenceExtended \
          --I ${inputBams} \
          --O /dev/stdout \
          --SUMMARY ${output_file}.${params.molecularBarcodeTag}_bam_summary.txt \
          --BASE_RANGE TODO \
          --BASE_QUALITY 10 \
          --BARCODED_READ {params.barcodedRead} \
          --DISCARD_READ true \
          --TAG_BOTH_READS false \
          --TAG_NAME ${params.molecularBarcodeTag} \
          --NUM_BASES_BELOW_QUALITY 1 \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT | \
    FilterBam \
            --I/dev/stdin \
            --O /dev/stdout \
            --TAG_REJECT XQ \
            --PASSING_READ_THRESHOLD 0.1 \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT | \
    FilterBamByTag" \
 */