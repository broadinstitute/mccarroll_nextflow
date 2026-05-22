include {noMetaChannelHelper; collectInOrder; metaOnlyChannelHelper; combineIntoTupleChannel} from '../../modules/local/workflowUtil.nf'
include { buildReferenceMetadataLocator; loadNonAutosomes } from '../../modules/local/ReferenceMetadataLocator.nf'
include {FILTER_DGE} from '../../modules/local/filterDge.nf'
include {MAKE_TRIPLET_DGE} from '../../modules/local/makeTripletDge.nf'
include { GATHER_UMI_READ_INTERVALS } from '../../modules/local/gatherUmiReadIntervals.nf'
include { MERGE_UMI_READ_INTERVALS } from '../../modules/local/mergeUMIReadIntervals.nf'
include { CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE } from '../../modules/local/chimericReportEditDistanceCollapse.nf'
include { DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES } from '../../modules/local/downsampleTranscriptsAndQuantiles.nf'
include { GATHER_DIGITAL_ALLELE_COUNTS } from '../../modules/local/gatherDigitalAlleleCounts.nf'
include { MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES } from '../../modules/local/mergeGatherDigitalAlleleFrequencies.nf'

workflow standard_analysis_workflow {
    take:
    selectedCells
    dgeMatrix
    dgeSummary
    bams
    chimericTranscripts

    main    :
    functionalStrategy = params.metaGeneDgeFunctionalStrategy ?: params.dgeFunctionalStrategy
    FILTER_DGE(selectedCells, noMetaChannelHelper(dgeMatrix), noMetaChannelHelper(dgeSummary))
    referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    MAKE_TRIPLET_DGE(FILTER_DGE.out.filteredDge, referenceMetadataLocator.reducedGtf)
    GATHER_UMI_READ_INTERVALS(bams, noMetaChannelHelper(selectedCells).collect(), params.locusFunction, params.strandStrategy, functionalStrategy)
    meta = metaOnlyChannelHelper(selectedCells)
    MERGE_UMI_READ_INTERVALS(meta, collectInOrder(GATHER_UMI_READ_INTERVALS.out.umiReadIntervals))
    CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE(selectedCells, noMetaChannelHelper(chimericTranscripts).collect())
    DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES(selectedCells, noMetaChannelHelper(CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE.out.molBc).collect())

    if (params.vcf) {
        GATHER_DIGITAL_ALLELE_COUNTS(bams, noMetaChannelHelper(selectedCells).collect(), 
        params.donorFile, params.vcf, params.locusFunction, params.strandStrategy, loadNonAutosomes(referenceMetadataLocator.contigGroups))
        MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES(params.library, collectInOrder(GATHER_DIGITAL_ALLELE_COUNTS.out.digitalAlleleFrequencies))
        digitalAlleleFrequencies = combineIntoTupleChannel(meta, MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES.out.digitalAlleleFrequencies)
    } else {
        digitalAlleleFrequencies = channel.empty()
    }

    emit:
    dge = FILTER_DGE.out.filteredDge
    dgeSummary = FILTER_DGE.out.filteredDgeSummary
    sparseDgeMatrix = MAKE_TRIPLET_DGE.out.matrix
    sparseDgeFeatures = MAKE_TRIPLET_DGE.out.features
    sparseDgeBarcodes = MAKE_TRIPLET_DGE.out.barcodes
    umiReadIntervals = MERGE_UMI_READ_INTERVALS.out.umiReadIntervals
    molBc = CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE.out.molBc
    umiSaturationHistogram = DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES.out.umiSaturationHistogram
    digitalAlleleFrequencies = digitalAlleleFrequencies
}