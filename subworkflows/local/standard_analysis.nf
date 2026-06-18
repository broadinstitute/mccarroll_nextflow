include {noMetaChannelHelper; collectInOrder; metaOnlyChannelHelper; combineIntoTupleChannel} from '../../modules/local/workflowUtil.nf'
include { buildReferenceMetadataLocator; loadNonAutosomes } from '../../modules/local/ReferenceMetadataLocator.nf'
include {FILTER_DGE; FILTER_DGE as FILTER_DONOR_DGE} from '../../modules/local/filterDge.nf'
include {MAKE_TRIPLET_DGE} from '../../modules/local/makeTripletDge.nf'
include { GATHER_UMI_READ_INTERVALS } from '../../modules/local/gatherUmiReadIntervals.nf'
include { MERGE_UMI_READ_INTERVALS } from '../../modules/local/mergeUMIReadIntervals.nf'
include { CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE } from '../../modules/local/chimericReportEditDistanceCollapse.nf'
include { DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES } from '../../modules/local/downsampleTranscriptsAndQuantiles.nf'
include { GATHER_DIGITAL_ALLELE_COUNTS } from '../../modules/local/gatherDigitalAlleleCounts.nf'
include { MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES } from '../../modules/local/mergeGatherDigitalAlleleFrequencies.nf'
include { ASSIGN_CELLS_TO_SAMPLES } from '../../modules/local/assignCellsToSamples.nf'
include { DETECT_DOUBLETS } from '../../modules/local/detectDoublets.nf'
include { withExtension } from '../../modules/local/FileUtil.nf'
include { MERGE_CELL_TO_SAMPLE_ASSIGNMENTS } from '../../modules/local/mergeCellToSampleAssignments.nf'
include { MERGE_DOUBLET_ASSIGNMENTS } from '../../modules/local/mergeDoubletAssignments.nf'
include { DONOR_ASSIGNMENT_QC } from '../../modules/local/donorAssignmentQC.nf'
include { CREATE_METACELLS } from '../../modules/local/createMetacells.nf'
include { DISCOVER_META_GENES } from '../../modules/local/discoverMetaGenes.nf'
include { MERGE_META_GENE_REPORTS } from '../../modules/local/mergeMetaGeneReports.nf'
include { CREATE_META_GENE_BAM } from '../../modules/local/createMetaGeneBam.nf'
include { DIGITAL_EXPRESSION } from '../../modules/local/digitalExpression.nf'
include { MERGE_SPLIT_DGES } from '../../modules/local/mergeSplitDges.nf'
include { MERGE_DGE_SUMMARIES; MERGE_DGE_SUMMARIES as MERGE_GMG_DGE_SUMMARIES } from '../../modules/local/mergeDgeSummaries.nf'
include { MERGE_DGE} from '../../modules/local/mergeDge.nf'
include { PLOT_STANDARD_ANALYSIS } from '../../modules/local/plotStandardAnalysis.nf'
include { CALL_SEX_FROM_METACELLS } from '../../modules/local/callSexFromMetacells.nf'
include { WRITE_PROPERTIES } from '../../modules/local/writeProperties.nf'

workflow standard_analysis_workflow {
    take:
    selectedCells
    dgeMatrix
    dgeSummary
    bams
    chimericTranscripts
    cbrbCellFeatures
    readsPerCell

    main    :
    metagene_infix = ".metagene"
    gmg_infix      = ".gmg"
    functionalStrategy = params.metaGeneDgeFunctionalStrategy ?: params.dgeFunctionalStrategy
    FILTER_DGE(selectedCells.map{m, f -> tuple(m + [id: m.id + ".selected"], f)}, noMetaChannelHelper(dgeMatrix), noMetaChannelHelper(dgeSummary))
    referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    MAKE_TRIPLET_DGE(FILTER_DGE.out.filteredDge, referenceMetadataLocator.reducedGtf)
    noChannelSelectedCells = noMetaChannelHelper(selectedCells).collect()
    GATHER_UMI_READ_INTERVALS(bams, noChannelSelectedCells, params.locusFunction, params.strandStrategy, functionalStrategy)
    meta = metaOnlyChannelHelper(selectedCells)
    MERGE_UMI_READ_INTERVALS(meta, collectInOrder(GATHER_UMI_READ_INTERVALS.out.umiReadIntervals))
    CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE(selectedCells, noMetaChannelHelper(chimericTranscripts).collect())
    DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES(selectedCells, noMetaChannelHelper(CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE.out.molBc).collect())
    PLOT_STANDARD_ANALYSIS(
        params.library,
        noMetaChannelHelper(DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES.out.umiSaturationHistogram).collect(),
        noMetaChannelHelper(CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE.out.molBc).collect(),
        noMetaChannelHelper(FILTER_DGE.out.filteredDgeSummary).collect()
    )
    standardAnalysisPdf = combineIntoTupleChannel(meta, PLOT_STANDARD_ANALYSIS.out.pdf)
    umiSaturationMetrics = combineIntoTupleChannel(meta, PLOT_STANDARD_ANALYSIS.out.umi_saturation_metrics)
    DISCOVER_META_GENES(
        bams, 
        noChannelSelectedCells,
        params.locusFunction, 
        functionalStrategy
    )
    MERGE_META_GENE_REPORTS(params.library, collectInOrder(DISCOVER_META_GENES.out.metaGeneReport))
    CREATE_META_GENE_BAM(
        bams, 
        noChannelSelectedCells, 
        MERGE_META_GENE_REPORTS.out.metaGeneReport.collect(), 
        params.locusFunction, 
        functionalStrategy
    )
    // Run DigitalExpression on all the metagene BAMs, but append ".metagene" to meta.id
    DIGITAL_EXPRESSION(
        CREATE_META_GENE_BAM.out.bam.map{m, f -> tuple(m + [id: m.id + metagene_infix], f)}.combine(noMetaChannelHelper(selectedCells)), 
        params.locusFunction, 
        params.library,
        params.strandStrategy, 
        0,
        functionalStrategy,
        params.cellBarcodeTag,
        params.molecularBarcodeTag,
        true // doMetaGenes
    )
    MERGE_SPLIT_DGES(params.library + metagene_infix, collectInOrder(DIGITAL_EXPRESSION.out.dge)) 
    MERGE_DGE_SUMMARIES(params.library + metagene_infix, collectInOrder(DIGITAL_EXPRESSION.out.dge_summary), "")
    metageneReport = combineIntoTupleChannel(meta, MERGE_META_GENE_REPORTS.out.metaGeneReport)
    metageneDge = combineIntoTupleChannel(meta, MERGE_SPLIT_DGES.out.dge)
    metageneDgeSummary = combineIntoTupleChannel(meta, MERGE_DGE_SUMMARIES.out)

    // GMG (gene + metagene) DGE: merge the selected-cells DGE with the metagene DGE into a single matrix.
    // Both inputs are single-item channels; combine() pairs them and map() packages them as a list
    // because MERGE_DGE / MERGE_GMG_DGE_SUMMARIES expect a list of files for their second argument.
    MERGE_DGE(params.library + gmg_infix,
        noMetaChannelHelper(FILTER_DGE.out.filteredDge)
            .combine(MERGE_SPLIT_DGES.out.dge)      // pair: [selectedCells_dge, metagene_dge]
            .map { f1, f2 -> [f1, f2] })

    MERGE_GMG_DGE_SUMMARIES(params.library + gmg_infix,
        noMetaChannelHelper(FILTER_DGE.out.filteredDgeSummary)
            .combine(MERGE_DGE_SUMMARIES.out)       // pair: [selectedCells_summary, metagene_summary]
            .map { f1, f2 -> [f1, f2] },
        "--ACCUMULATE_CELL_BARCODE_METRICS true")
    gmgDge = combineIntoTupleChannel(meta, MERGE_DGE.out.dge)
    gmgDgeSummary = combineIntoTupleChannel(meta, MERGE_GMG_DGE_SUMMARIES.out)

    workflowProperties = [
        metaGeneDgeFunctionalStrategy: functionalStrategy
    ]
    if (params.vcf) {
        workflowProperties.vcf = params.vcf.toString()
        workflowProperties.donorFile = params.donorFile.toString()
        bcf = params.cloudVcf ?: params.vcf
        nonAutosomes = loadNonAutosomes(referenceMetadataLocator.contigGroups)
        GATHER_DIGITAL_ALLELE_COUNTS(bams, noChannelSelectedCells, 
        params.donorFile, params.vcf, params.locusFunction, params.strandStrategy, nonAutosomes)
        MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES(params.library, collectInOrder(GATHER_DIGITAL_ALLELE_COUNTS.out.digitalAlleleFrequencies))
        digitalAlleleFrequencies = combineIntoTupleChannel(meta, MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES.out.digitalAlleleFrequencies)
        ASSIGN_CELLS_TO_SAMPLES(
            bams, 
            bcf, 
            withExtension(bcf, 'idx'),
            noChannelSelectedCells, 
            noMetaChannelHelper(cbrbCellFeatures).collect(), 
            MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES.out.digitalAlleleFrequencies.collect(),
            params.strandStrategy, functionalStrategy, params.cellBarcodeTag, params.molecularBarcodeTag, params.locusFunction, nonAutosomes
        )
        dd_channel = bams.join(ASSIGN_CELLS_TO_SAMPLES.out.vcf).join(ASSIGN_CELLS_TO_SAMPLES.out.vcfIndex).join(ASSIGN_CELLS_TO_SAMPLES.out.donorAssignments)
        DETECT_DOUBLETS(
            dd_channel, 
            noChannelSelectedCells, 
            params.donorFile, 
            noMetaChannelHelper(cbrbCellFeatures).collect(), 
            MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES.out.digitalAlleleFrequencies.collect(),
            params.strandStrategy, params.locusFunction, nonAutosomes
        )
        MERGE_CELL_TO_SAMPLE_ASSIGNMENTS(params.library, collectInOrder(ASSIGN_CELLS_TO_SAMPLES.out.donorAssignments))
        donorAssignments = combineIntoTupleChannel(meta, MERGE_CELL_TO_SAMPLE_ASSIGNMENTS.out.donorAssignments)
        MERGE_DOUBLET_ASSIGNMENTS(params.library, collectInOrder(DETECT_DOUBLETS.out.doublets))
        doubletAssignments = combineIntoTupleChannel(meta, MERGE_DOUBLET_ASSIGNMENTS.out.doublets)
        DONOR_ASSIGNMENT_QC(
            params.library, 
            MERGE_CELL_TO_SAMPLE_ASSIGNMENTS.out.donorAssignments.collect(),
            MERGE_DOUBLET_ASSIGNMENTS.out.doublets.collect(),
            noMetaChannelHelper(FILTER_DGE.out.filteredDgeSummary).collect(), 
            noMetaChannelHelper(dgeSummary).collect(), 
            noMetaChannelHelper(FILTER_DGE.out.filteredDge).collect(), 
            readsPerCell.collect(),
            params.donorFile)
        donorList = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.donorList)
        donorCellMap = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.donorCellMap)
        donorAssignmentSummaryStats = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.summaryStats)
        donorAssignmentTearSheet = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.tearSheetPdf)
        donorCellBarcodes = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.cellBarcodes) 
        donorAssignmentPdf = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.pdf) 
        FILTER_DONOR_DGE(donorCellBarcodes.map{m, f -> tuple(m + [id: m.id + ".donors"], f)}, 
        noMetaChannelHelper(FILTER_DGE.out.filteredDge).collect(), noMetaChannelHelper(FILTER_DGE.out.filteredDgeSummary).collect())
        CREATE_METACELLS(donorAssignments.map{m, f -> tuple(m + [id: m.id + ".donors"], f, [])}, 
                noMetaChannelHelper(FILTER_DONOR_DGE.out.filteredDge).collect())
        metacells = combineIntoTupleChannel(meta, CREATE_METACELLS.out.metacells)
        metacellMetrics = combineIntoTupleChannel(meta, CREATE_METACELLS.out.metacellMetrics)

        donorDge = FILTER_DONOR_DGE.out.filteredDge
        donorDgeSummary = FILTER_DONOR_DGE.out.filteredDgeSummary
    } else {
        digitalAlleleFrequencies = channel.empty()
        donorAssignments = channel.empty()
        doubletAssignments = channel.empty()
        donorList = channel.empty()
        donorCellMap = channel.empty()
        donorAssignmentSummaryStats = channel.empty()
        donorAssignmentTearSheet = channel.empty()
        donorCellBarcodes = channel.empty()
        donorAssignmentPdf = channel.empty()
        donorDge = channel.empty()
        donorDgeSummary = channel.empty()
        if (params.donor) {
           CREATE_METACELLS(meta.map { m -> tuple(m, [], params.donor) }, 
                noMetaChannelHelper(FILTER_DGE.out.filteredDge).collect())
            metacells = combineIntoTupleChannel(meta, CREATE_METACELLS.out.metacells)
            metacellMetrics = combineIntoTupleChannel(meta, CREATE_METACELLS.out.metacellMetrics)
            workflowProperties.donor = params.donor
        } else {
            metacells = channel.empty()
            metacellMetrics = channel.empty()
        }
    }
    if ((params.vcf || params.donor) && referenceMetadataLocator.xipherConfig.exists()) {
        CALL_SEX_FROM_METACELLS(params.library, referenceMetadataLocator.xipherConfig, 
        CREATE_METACELLS.out.metacells.collect(), CREATE_METACELLS.out.metacellMetrics.collect())
        sexCalls = combineIntoTupleChannel(meta, CALL_SEX_FROM_METACELLS.out.sexCalls)
        sexPdf = combineIntoTupleChannel(meta, CALL_SEX_FROM_METACELLS.out.pdf)
    } else {
        sexCalls = channel.empty()
        sexPdf = channel.empty()
    }
    WRITE_PROPERTIES(workflowProperties)
    standardAnalysisProperties = combineIntoTupleChannel(meta, WRITE_PROPERTIES.out)

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
    donorAssignments = donorAssignments
    doubletAssignments = doubletAssignments
    donorList = donorList
    donorCellMap = donorCellMap
    donorAssignmentSummaryStats = donorAssignmentSummaryStats
    donorAssignmentTearSheet = donorAssignmentTearSheet
    donorCellBarcodes = donorCellBarcodes
    donorAssignmentPdf = donorAssignmentPdf
    donorDge = donorDge
    donorDgeSummary = donorDgeSummary
    metacells = metacells
    metacellMetrics = metacellMetrics
    standardAnalysisProperties = standardAnalysisProperties
    metageneReport = metageneReport
    metageneDge = metageneDge
    metageneDgeSummary = metageneDgeSummary
    gmgDge = gmgDge
    gmgDgeSummary = gmgDgeSummary
    properties = standardAnalysisProperties
    standardAnalysisPdf = standardAnalysisPdf
    sexCalls = sexCalls
    sexPdf = sexPdf
    umiSaturationMetrics = umiSaturationMetrics
}