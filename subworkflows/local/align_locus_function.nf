include {PREALIGNMENT_TAG_AND_TRIM} from '../../modules/local/preAlignmentTagAndTrim.nf'

workflow align_locus_function_workflow {
    take:
        unmappedBams
        beadStructure

    main:
    PREALIGNMENT_TAG_AND_TRIM(
            params.library,
            unmappedBams,
            params.fivePrimeAdapter,
            params.beadStructure,
            params.cellBarcodeTag,
            params.molecularBarcodeTag,
            params.allowedBarcodes,
            "unmapped.bam",
            "unmapped_tagged_trimmed_filtered.bam"
    )
    emit:
    taggedAndTrimmedBam = PREALIGNMENT_TAG_AND_TRIM.out.taggedAndTrimmedBams
}