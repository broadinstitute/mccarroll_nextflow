include { noMetaChannelHelper; collectInOrder; metaOnlyChannelHelper; combineIntoTupleChannel; getUserName } from '../../modules/local/workflowUtil.nf'
include { buildReferenceMetadataLocator; loadNonAutosomes } from '../../modules/local/ReferenceMetadataLocator.nf'
include { withExtension } from '../../modules/local/FileUtil.nf'
include { makeDropulationlabel } from '../../modules/local/workflowUtil.nf'

include { GATHER_DIGITAL_ALLELE_COUNTS } from '../../modules/local/gatherDigitalAlleleCounts.nf'
include { MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES } from '../../modules/local/mergeGatherDigitalAlleleFrequencies.nf'
include { ASSIGN_CELLS_TO_SAMPLES } from '../../modules/local/assignCellsToSamples.nf'
include { DETECT_DOUBLETS } from '../../modules/local/detectDoublets.nf'
include { MERGE_CELL_TO_SAMPLE_ASSIGNMENTS } from '../../modules/local/mergeCellToSampleAssignments.nf'
include { MERGE_DOUBLET_ASSIGNMENTS } from '../../modules/local/mergeDoubletAssignments.nf'
include { DONOR_ASSIGNMENT_QC } from '../../modules/local/donorAssignmentQC.nf'
include {FILTER_DGE} from '../../modules/local/filterDge.nf'
include { CREATE_METACELLS } from '../../modules/local/createMetacells.nf'
include { FILTER_CELL_METADATA } from '../../modules/local/filterCellMetadata.nf'
include { JOIN_CELL_METADATA } from '../../modules/local/joinCellMetadata.nf'
include { WRITE_PROPERTIES } from '../../modules/local/writeProperties.nf'
include { CALL_SEX_FROM_METACELLS } from '../../modules/local/callSexFromMetacells.nf'
include { SEND_EMAIL } from '../../modules/local/sendEmail.nf'
include { subpath } from '../../modules/local/FileUtil.nf'
include { dropulationDir } from '../../modules/local/DirectoryUtil.nf'
workflow dropulation_workflow {
    take:
        selectedCells
        bams
        cbrbCellFeatures
        dge
        dgeSummary
        dgeSummaryRaw
        readsPerCell
        doubletCalls

    main:
     workflowProperties = [
        submitter: getUserName(),
        vcf: params.vcf.toUriString(),
        donorFile: params.donorFile.toUriString(),
        dropulation_label: makeDropulationlabel(file(params.vcf), file(params.donorFile))
    ]
    referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    bcf = params.cloudVcf ?: params.vcf
    nonAutosomes = loadNonAutosomes(referenceMetadataLocator.contigGroups)
    noChannelSelectedCells = noMetaChannelHelper(selectedCells).collect()
    meta = metaOnlyChannelHelper(selectedCells).map { m -> m + [dropulation_label: workflowProperties.dropulation_label] }
    functionalStrategy = params.metaGeneDgeFunctionalStrategy ?: params.dgeFunctionalStrategy

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
        noMetaChannelHelper(dgeSummary).collect(), 
        noMetaChannelHelper(dgeSummaryRaw).collect(), 
        noMetaChannelHelper(dge).collect(),
        readsPerCell.collect(),
        params.donorFile)

    donorList = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.donorList)
    donorCellMap = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.donorCellMap)
    donorAssignmentSummaryStats = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.summaryStats)
    donorAssignmentTearSheet = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.tearSheetPdf)
    donorCellBarcodes = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.cellBarcodes) 
    donorAssignmentPdf = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.pdf) 
    FILTER_DGE(donorCellBarcodes.map{m, f -> tuple(m + [id: m.id + ".donors"], f)}, 
    noMetaChannelHelper(dge).collect(), noMetaChannelHelper(dgeSummary).collect())
    CREATE_METACELLS(donorAssignments.map{m, f -> tuple(m + [id: m.id + ".donors"], f, [])}, 
            noMetaChannelHelper(FILTER_DGE.out.filteredDge).collect())
    metacells = combineIntoTupleChannel(meta, CREATE_METACELLS.out.metacells)
    metacellMetrics = combineIntoTupleChannel(meta, CREATE_METACELLS.out.metacellMetrics)
    FILTER_CELL_METADATA(params.library, noMetaChannelHelper(cbrbCellFeatures), noMetaChannelHelper(donorCellBarcodes).collect())
    JOIN_CELL_METADATA(params.library, FILTER_CELL_METADATA.out,
        noMetaChannelHelper(donorCellMap).collect(), '',
        noMetaChannelHelper(FILTER_DGE.out.filteredDgeSummary).collect(),
        noMetaChannelHelper(doubletCalls).collect())
    cellMetadata = combineIntoTupleChannel(meta, JOIN_CELL_METADATA.out)
    if (referenceMetadataLocator.xipherConfig.exists()) {
        CALL_SEX_FROM_METACELLS(params.library, referenceMetadataLocator.xipherConfig, 
        CREATE_METACELLS.out.metacells.collect(), CREATE_METACELLS.out.metacellMetrics.collect())
        sexCalls = combineIntoTupleChannel(meta, CALL_SEX_FROM_METACELLS.out.sexCalls)
        sexPdf = combineIntoTupleChannel(meta, CALL_SEX_FROM_METACELLS.out.pdf)
    } else {
        sexCalls = channel.empty()
        sexPdf = channel.empty()
    }

    donorDge = FILTER_DGE.out.filteredDge
    donorDgeSummary = FILTER_DGE.out.filteredDgeSummary
    WRITE_PROPERTIES(workflowProperties)
    dropulationProperties = combineIntoTupleChannel(meta, WRITE_PROPERTIES.out)

    fullDropulationDir = meta.map { m -> subpath(params.outdir, dropulationDir(tuple(m, []))) }
    SEND_EMAIL(
        "Dropulation summary for ${params.library}",
        fullDropulationDir.map{ it -> "Dropulation summary for ${params.library} in ${it}"},
        params.email,
        noMetaChannelHelper(donorAssignmentTearSheet)
    )
    emit:
    digitalAlleleFrequencies
    donorAssignments
    doubletAssignments
    donorList
    donorCellMap
    donorAssignmentSummaryStats
    donorAssignmentTearSheet
    donorCellBarcodes
    donorAssignmentPdf
    metacells
    metacellMetrics
    donorDge
    donorDgeSummary
    cellMetadata
    donorSexCalls = sexCalls
    donorSexPdf = sexPdf
    dropulationProperties
}