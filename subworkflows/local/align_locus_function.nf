include {PREALIGNMENT_TAG_AND_TRIM} from '../../modules/local/preAlignmentTagAndTrim.nf'
include { STAR_ALIGN } from '../../modules/nf-core/star/align/main'
include { PICARD_SORTSAM } from '../../modules/nf-core/picard/sortsam/main'
include { GATK4_MERGEBAMALIGNMENT } from '../../modules/nf-core/gatk4/mergebamalignment/main'
include { GATK4_BASERECALIBRATOR } from '../../modules/nf-core/gatk4/baserecalibrator/main'
include { GATK4_GATHERBQSRREPORTS } from '../../modules/nf-core/gatk4/gatherbqsrreports/main'
include { GATK4_APPLYBQSR } from '../../modules/nf-core/gatk4/applybqsr/main'     
include { buildReferenceMetadataLocator; loadMtSequences } from '../../modules/local/ReferenceMetadataLocator.nf'
include {TAG_READ_WITH_GENE_FUNCTION} from '../../modules/local/tagReadWithGeneFunction.nf'
include {MARK_CHIMERIC_READS} from '../../modules/local/markChimericReads.nf'
include {VALIDATE_ALIGNED_SAM} from '../../modules/local/validateAlignedSam.nf'
include {VALIDATE_SAM_FILE} from '../../modules/local/validateSamFile.nf'
include {SELECT_CELLS_BY_NUM_TRANSCRIPTS} from '../../modules/local/selectCellsByNumTranscripts.nf'
include {DIGITAL_EXPRESSION} from '../../modules/local/digitalExpression.nf'
include {SINGLE_CELL_RNA_SEQ_METRICS_COLLECTOR} from '../../modules/local/singleCellRnaSeqMetricsCollector.nf'
include {MERGE_CELLS_BY_NUM_TRANSCRIPTS} from '../../modules/local/mergeCellsByNumTranscripts.nf'
include {MERGE_DGE_SUMMARIES} from '../../modules/local/mergeDgeSummaries.nf'
include {collectInOrder} from '../../modules/local/workflowUtil.nf'
include {MERGE_SPLIT_DGES} from '../../modules/local/mergeSplitDges.nf'
include {MERGE_SINGLE_CELL_RNA_SEQ_METRICS} from '../../modules/local/mergeSingleCellRnaSeqMetrics.nf'
include { MAKE_SPARSE_DGE } from '../../modules/local/makeSparseDge.nf'

workflow align_locus_function_workflow {
    take:
        unmappedBams
        beadStructure

    main:
    ch_unmapped_bams = unmappedBams.map { bam -> 
        def bamBase = bam.getName().replaceFirst(/\.unmapped\.bam$/, '')
        def bamIndex = bamBase.replaceFirst(/.*\./, '') as Integer
        tuple([id: bamBase, bamBase: bamBase, collectIndex: bamIndex], bam)
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
    // TODO: This isn't good.  It should retain most everything from the original meta rather than reconstructing.
    // This magic is needed to make sure the right BAM files get merged together by GATK4_MERGEBAMALIGNMENT.  Join on bamBase.
    ch_aligned_sorted_bams = PICARD_SORTSAM.out.bam.map { meta, file -> tuple(meta.bamBase, file) }
    ch_prealigned_bams = PREALIGNMENT_TAG_AND_TRIM.out.taggedAndTrimmedBams.map { meta, file -> tuple(meta.bamBase, file) }
    ch_aligned_sorted_bams.combine(ch_prealigned_bams, by:0).map { bamBase, alignedSortedBam, prealignedBam ->
        tuple([id: bamBase  + ".merged", bamBase: bamBase, collectIndex: bamBase.replaceFirst(/.*\./, '') as Integer], alignedSortedBam, prealignedBam)
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
        // order the tables by collectIndex but give them all the same meta
        gatherMeta = [id: params.library]
        GATK4_GATHERBQSRREPORTS(collectInOrder(GATK4_BASERECALIBRATOR.out.table).map({ file -> tuple(gatherMeta, file) }))
        
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

    // BAMs complete! DGE below
    SELECT_CELLS_BY_NUM_TRANSCRIPTS(
        alignedBams,
        params.locusFunction,
        params.minimumTranscriptsPerCell,
        params.dgeMinReadMq,
        params.dgeFunctionalStrategy,
        params.strandStrategy
    )
    DIGITAL_EXPRESSION(
        alignedBams.join(SELECT_CELLS_BY_NUM_TRANSCRIPTS.out.selectedCells),
        params.locusFunction,
        params.library,
        params.strandStrategy,
        params.minimumTranscriptsPerCell,
        params.dgeMinReadMq,
        params.dgeFunctionalStrategy,
        params.cellBarcodeTag,
        params.molecularBarcodeTag
    )
    SINGLE_CELL_RNA_SEQ_METRICS_COLLECTOR(
        alignedBams.join(SELECT_CELLS_BY_NUM_TRANSCRIPTS.out.selectedCells),
        params.reference,
        referenceMetadataLocator.gtf,
        referenceMetadataLocator.ribosomalIntervals,
        params.dgeMinReadMq,
        loadMtSequences(referenceMetadataLocator.contigGroups),
        params.cellBarcodeTag
    )

    // Merging of split-bam 20-transcript DGE stuff
    selectedCellsList = collectInOrder(SELECT_CELLS_BY_NUM_TRANSCRIPTS.out.selectedCells)
    selectedCellMetricsList = collectInOrder(SELECT_CELLS_BY_NUM_TRANSCRIPTS.out.metrics)
    MERGE_CELLS_BY_NUM_TRANSCRIPTS(
        params.library,
        selectedCellsList,
        selectedCellMetricsList
    )
    MERGE_DGE_SUMMARIES(
        params.library,
        collectInOrder(DIGITAL_EXPRESSION.out.dge_summary)
    )
    MERGE_SPLIT_DGES(
        params.library,
        collectInOrder(DIGITAL_EXPRESSION.out.dge)
    )
    MERGE_SINGLE_CELL_RNA_SEQ_METRICS(
        params.library,
        collectInOrder(SINGLE_CELL_RNA_SEQ_METRICS_COLLECTOR.out.metrics)
    )

    finalMeta = [id: params.library, library: params.library, referenceName: referenceMetadataLocator.referenceName]
    MAKE_SPARSE_DGE(
        MERGE_SPLIT_DGES.out.dge.map {f -> tuple(finalMeta, f) }
    )
    // Dropseq.cellselection::buildCellFeaturesSimple

    

    sizeSelectedCells = MERGE_CELLS_BY_NUM_TRANSCRIPTS.out.mergedCells.map {f -> tuple(finalMeta, f) }
    sizeSelectedCellsMetrics = MERGE_CELLS_BY_NUM_TRANSCRIPTS.out.mergedCellsMetrics.map {f -> tuple(finalMeta, f) }
    dgeSummary = MERGE_DGE_SUMMARIES.out.map {f -> tuple(finalMeta, f) }
    dge = MERGE_SPLIT_DGES.out.dge.map {f -> tuple(finalMeta, f) }
    singleCellRnaSeqMetrics = MERGE_SINGLE_CELL_RNA_SEQ_METRICS.out.map {f -> tuple(finalMeta, f) }
    sparseDgeMatrix = MAKE_SPARSE_DGE.out.matrix
    sparseDgeFeatures = MAKE_SPARSE_DGE.out.features
    sparseDgeBarcodes = MAKE_SPARSE_DGE.out.barcodes
    emit:
    alignedBam = alignedBams
    alignedBai = alignedBais
    // TODO: These should be merged.
    chimericReadMetrics = MARK_CHIMERIC_READS.out.chimericReadMetrics
    chimericTranscripts = MARK_CHIMERIC_READS.out.chimericTranscripts
    sizeSelectedCells = sizeSelectedCells
    sizeSelectedCellsMetrics = sizeSelectedCellsMetrics
    dgeSummary = dgeSummary
    dge = dge
    singleCellRnaSeqMetrics = singleCellRnaSeqMetrics
    sparseDgeMatrix = sparseDgeMatrix
    sparseDgeFeatures = sparseDgeFeatures
    sparseDgeBarcodes = sparseDgeBarcodes
}