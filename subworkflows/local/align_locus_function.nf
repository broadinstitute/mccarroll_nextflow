include {PREALIGNMENT_TAG_AND_TRIM} from '../../modules/local/preAlignmentTagAndTrim.nf'
include { STAR_ALIGN } from '../../modules/nf-core/star/align/main'

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

    ch_star_input = PREALIGNMENT_TAG_AND_TRIM.out.taggedAndTrimmedBams.map { bam ->
        tuple([id: bam.baseName.replaceFirst(/\.bam$/, ''), single_end: true], bam)
    }
    // TODO: Figure out how to get the STAR version in order to get the correct genome index directory.  For now, just hardcode the version.
    // TODO: Why do I need to use file() here?  params.reference is defined as a Path.
    genome_index_dir = file(params.reference).parent + "/STAR_indices/2.7.11a"
    STAR_ALIGN(
            ch_star_input,
            tuple([], genome_index_dir),
            tuple([], file("/dev/null")), // no GTF
            true // ignore junctions
    )
    ch_star_output = STAR_ALIGN.out.bam.map { meta, file -> file }
    emit:
    taggedAndTrimmedBam = PREALIGNMENT_TAG_AND_TRIM.out.taggedAndTrimmedBams
    alignedBam = ch_star_output
}