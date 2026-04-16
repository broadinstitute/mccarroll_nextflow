include {PREALIGNMENT_TAG_AND_TRIM} from '../../modules/local/preAlignmentTagAndTrim.nf'
include { STAR_ALIGN } from '../../modules/nf-core/star/align/main'
include { PICARD_SORTSAM } from '../../modules/nf-core/picard/sortsam/main'
include { GATK4_MERGEBAMALIGNMENT } from '../../modules/nf-core/gatk4/mergebamalignment/main'
include { GATK4_BASERECALIBRATOR } from '../../modules/nf-core/gatk4/baserecalibrator/main'
include { GATK4_GATHERBQSRREPORTS } from '../../modules/nf-core/gatk4/gatherbqsrreports/main'
include { GATK4_APPLYBQSR } from '../../modules/nf-core/gatk4/applybqsr/main'     
include { buildReferenceMetadataLocator } from '../../modules/local/ReferenceMetadataLocator.nf'
include {TAG_READ_WITH_GENE_FUNCTION} from '../../modules/local/tagReadWithGeneFunction.nf'
include {MARK_CHIMERIC_READS} from '../../modules/local/markChimericReads.nf'
include {VALIDATE_ALIGNED_SAM} from '../../modules/local/validateAlignedSam.nf'
include {VALIDATE_SAM_FILE} from '../../modules/local/validateSamFile.nf'
workflow align_locus_function_workflow {
    take:
        unmappedBams
        beadStructure

    main:
    ch_unmapped_bams = unmappedBams.map { bam -> 
        def bamBase = bam.getName().replaceFirst(/\.unmapped\.bam$/, '')
        tuple([id: bamBase, bamBase: bamBase], bam)
    }
    PREALIGNMENT_TAG_AND_TRIM(
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
    null_file = tuple([], [])
    STAR_ALIGN(
            ch_star_input,
            tuple([], genome_index_dir),
            null_file, // no GTF
            true // ignore junctions
    )

    PICARD_SORTSAM(
        STAR_ALIGN.out.bam.map { meta, file -> tuple(meta + [id: meta.id + ".aligned_sorted"], file) },
        'queryname'
    )
    // This magic is needed to make sure the right BAM files get merged together by GATK4_MERGEBAMALIGNMENT.  Join on bamBase.
    ch_aligned_sorted_bams = PICARD_SORTSAM.out.bam.map { meta, file -> tuple(meta.bamBase, file) }
    ch_prealigned_bams = PREALIGNMENT_TAG_AND_TRIM.out.taggedAndTrimmedBams.map { meta, file -> tuple(meta.bamBase, file) }
    ch_aligned_sorted_bams.combine(ch_prealigned_bams, by:0).map { bamBase, alignedSortedBam, prealignedBam ->
        tuple([id: bamBase  + ".merged", bamBase: bamBase], alignedSortedBam, prealignedBam)
    }.set { ch_merge_input }

    // Although GATK4_MERGEBAMALIGNMENT process code doesn't use the sequence dictionary explicitly, it is found
    // relative to the reference FASTA file and is required to be present in order for the process to run successfully.  
    // Thus we need to build a locator for it and pass it in as an argument so that it is localized into the execution environment.
    referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    GATK4_MERGEBAMALIGNMENT(
        ch_merge_input,
        tuple([], params.reference),
        tuple([], referenceMetadataLocator.sequenceDictionary)
    )
    // Stick the reference name into the metadata so that it can be used downstream for naming output subdirectory.
    TAG_READ_WITH_GENE_FUNCTION(
        GATK4_MERGEBAMALIGNMENT.out.bam.map { meta, file -> tuple(meta + [id: meta.bamBase, referenceName: referenceMetadataLocator.referenceName], file) },
        referenceMetadataLocator.gtf
    )
    doBQSR = referenceMetadataLocator.dbSnp.exists()
    MARK_CHIMERIC_READS(
        TAG_READ_WITH_GENE_FUNCTION.out.taggedBam,
        params.strandStrategy,
        params.locusFunction,
        !doBQSR)
    if (doBQSR) {
        dbsnpIntervals = referenceMetadataLocator.dbSnpIntervals.exists() ? referenceMetadataLocator.dbSnpIntervals : []
        GATK4_BASERECALIBRATOR(
            TAG_READ_WITH_GENE_FUNCTION.out.taggedBam.map({ meta, file -> 
            tuple(meta, file, [], dbsnpIntervals) }), // no index, no intervals
            tuple([], params.reference),
            tuple([], [referenceMetadataLocator.gzi, referenceMetadataLocator.fai]), // Apparently GATK4_BASERECALIBRATOR needs both the fai and gzi
            tuple([], referenceMetadataLocator.sequenceDictionary),
            tuple([], referenceMetadataLocator.dbSnp),
            tuple([], referenceMetadataLocator.dbSnpIndex)
        )
        // TODO: There has to be a simpler way to do this.  I just want to gather all the tables emitted by GATK4_BASERECALIBRATOR and then pass them as a list to 
        // GATK4_GATHERBQSRREPORTS.  groupTuple shouldn't be necessary.
        gatherMeta = [id: params.library]
        GATK4_GATHERBQSRREPORTS(GATK4_BASERECALIBRATOR.out.table.map({ _meta, file -> tuple(gatherMeta, file) }).groupTuple())
        
        // TODO: There has to be a simpler way, given that there is a single output table from GATK4_GATHERBQSRREPORTS.
        ch_apply_bqsr = MARK_CHIMERIC_READS.out.chimericMarkedBam.combine(GATK4_GATHERBQSRREPORTS.out.table)
        .map { meta, bam, _meta, table ->
            tuple(tuple(meta, bam, [], table, []))
        }
        GATK4_APPLYBQSR(
            ch_apply_bqsr,
            params.reference,
            [referenceMetadataLocator.gzi, referenceMetadataLocator.fai],
            referenceMetadataLocator.sequenceDictionary
        )
        alignedBams = GATK4_APPLYBQSR.out.bam
        alignedBais = GATK4_APPLYBQSR.out.bai
    } else {
        alignedBams = MARK_CHIMERIC_READS.out.chimericMarkedBam
        alignedBais = MARK_CHIMERIC_READS.out.bai
    }
    VALIDATE_ALIGNED_SAM(alignedBams)
    VALIDATE_SAM_FILE(alignedBams, params.reference)
    emit:
    alignedBam = alignedBams
    alignedBai = alignedBais
    // TODO: These should be merged.
    chimericReadMetrics = MARK_CHIMERIC_READS.out.chimericReadMetrics
    chimericTranscripts = MARK_CHIMERIC_READS.out.chimericTranscripts
}