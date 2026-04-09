include {PREALIGNMENT_TAG_AND_TRIM} from '../../modules/local/preAlignmentTagAndTrim.nf'
include { STAR_ALIGN } from '../../modules/nf-core/star/align/main'
include { PICARD_SORTSAM } from '../../modules/nf-core/picard/sortsam/main'

workflow align_locus_function_workflow {
    take:
        unmappedBams
        beadStructure

    main:
    ch_unmapped_bams = unmappedBams.map { bam ->
        tuple([id: bam.name.replaceFirst(/\.unmapped\.bam$/, '')], bam)
    }
    PREALIGNMENT_TAG_AND_TRIM(
            params.library,
            ch_unmapped_bams,
            params.fivePrimeAdapter,
            beadStructure,
            params.cellBarcodeTag,
            params.molecularBarcodeTag,
            params.allowedBarcodes,
            "unmapped_tagged_trimmed_filtered.bam"
    )
    ch_star_input = PREALIGNMENT_TAG_AND_TRIM.out.taggedAndTrimmedBams.map { meta, bam ->
        tuple(meta + [single_end: true], bam)
    }
    // Zamboni alignment workflow streams STAR output into SortSam, but I don't think this can be done using nf-core
    // STAR_ALIGN.  Instead, I'll have STAR_ALIGN write BAM files to disk and then invoke SortSam.  It is possible
    // that sorting is unnecessary, because perhaps single-threaded STAR produces BAM that is in the same order
    // as input BAM.
    // TODO: Figure out how to get the STAR version in order to get the correct genome index directory.  For now, just hardcode the version.

    // STAR is configured to alway run in the cloud, so use cloud reference if provided, for speed.
    reference = params.cloudReference ?: params.reference
    // TODO: Why do I need to use file() here?  params.reference is defined as a Path.
    genome_index_dir = file(reference).parent + "/STAR_indices/2.7.11a"
    STAR_ALIGN(
            ch_star_input,
            tuple([], genome_index_dir),
            tuple([], file("/dev/null")), // no GTF
            true // ignore junctions
    )

    PICARD_SORTSAM(
        STAR_ALIGN.out.bam.map { meta, file -> tuple([id: meta.id + ".aligned_sorted", bamBase: meta.id], file) },
        'queryname'
    )
    ch_aligned_sorted_bams = PICARD_SORTSAM.out.bam.map { _meta, file -> file }

    emit:
    taggedAndTrimmedBam = PREALIGNMENT_TAG_AND_TRIM.out.taggedAndTrimmedBams
    alignedSortedBam = ch_aligned_sorted_bams
}