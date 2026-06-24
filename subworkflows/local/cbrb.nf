include { parseCbrbYamlArgs; addSvmEstimatedParameters; loadSvmEstimatedParameters } from '../../modules/local/CbrbArgParser.nf'
include {noMetaChannelHelper; combineIntoTupleChannel} from '../../modules/local/workflowUtil.nf'
include { makeCbrbLabel } from '../../modules/local/WorkflowPathUtil.nf'
include { SVM_ESTIMATE_CBRB_PARAMETERS } from '../../modules/local/svmEstimateCbrbParameters.nf'
include { CELLBENDER_REMOVEBACKGROUND } from '../../modules/nf-core/cellbender/removebackground/main.nf'
include { HDF5_10X_TO_TEXT } from '../../modules/local/hdf5_10X_to_text.nf'
include { JOIN_CBRB_CELL_FEATURES } from '../../modules/local/joinCbrbCellFeatures.nf'
include { WRITE_PROPERTIES } from '../../modules/local/writeProperties.nf'
include { DUMP_ELBO_TABLE } from '../../modules/local/dumpElboTable.nf'
include { PLOT_CBRB_TEAR_SHEET } from '../../modules/local/plotCbrbTearSheet.nf'

workflow cbrb_workflow {
    take:
    sparseDgeMatrix
    sparseDgeFeatures
    sparseDgeBarcodes
    cellFeatures
    denseDgeMatrix
    readQualityMetrics

    main:
    sparseDgeMatrixNoMeta = noMetaChannelHelper(sparseDgeMatrix)
    sparseDgeFeaturesNoMeta = noMetaChannelHelper(sparseDgeFeatures)
    sparseDgeBarcodesNoMeta = noMetaChannelHelper(sparseDgeBarcodes)
    cellFeaturesNoMeta = noMetaChannelHelper(cellFeatures)
    cbrb_label = makeCbrbLabel(params)
    meta = sparseDgeMatrix.map { meta, _file -> meta + [cbrb_label: cbrb_label] } // all inputs share the same meta; any can be used
    parsedCbrbArgs = parseCbrbYamlArgs(params.cbrbArgs)
    useSvmParameterEstimation = params.useSvmParameterEstimation && 
        (!parsedCbrbArgs.expectedCells || !parsedCbrbArgs.totalDropletsIncluded)
    if (useSvmParameterEstimation) {
        SVM_ESTIMATE_CBRB_PARAMETERS(
            params.library,
            sparseDgeMatrixNoMeta,
            sparseDgeFeaturesNoMeta,
            sparseDgeBarcodesNoMeta,
            cellFeaturesNoMeta,
            params.forceTwoClusterSolution
        )
        parsedCbrbArgsChannel = SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameters.map{f -> addSvmEstimatedParameters(parsedCbrbArgs,loadSvmEstimatedParameters(f))}
        svmCbrbParameters = combineIntoTupleChannel(meta, SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameters)
        svmCbrbParameterEstimationPdf = combineIntoTupleChannel(meta, SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameterEstimationPdf)
    } else {
        parsedCbrbArgsChannel = channel.value(parsedCbrbArgs)
        svmCbrbParameters = []
        svmCbrbParameterEstimationPdf = []
    }
    // TODO: does it have to be this hard?
    cbrbArgsMeta = parsedCbrbArgsChannel.map { p -> [cbrb_args: p.argList]}
    metaWithArgs = meta.combine(cbrbArgsMeta).map { m, a -> m + a }
    cbrbChannel = metaWithArgs.combine(sparseDgeMatrixNoMeta).map { 
        m, mat -> tuple(m, [mat.parent]) 
        }
    CELLBENDER_REMOVEBACKGROUND(cbrbChannel)
    HDF5_10X_TO_TEXT(CELLBENDER_REMOVEBACKGROUND.out.h5, noMetaChannelHelper(denseDgeMatrix), noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.log))
    JOIN_CBRB_CELL_FEATURES(
        cellFeatures.map {m, file -> tuple(m + [cbrb_label: cbrb_label], file)},
        noMetaChannelHelper(HDF5_10X_TO_TEXT.out.numTranscripts),
    )
    DUMP_ELBO_TABLE(
        params.library,
        noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.h5)
    )
    PLOT_CBRB_TEAR_SHEET(
        params.library,
        cbrb_label,
        DUMP_ELBO_TABLE.out.collect(),
        noMetaChannelHelper(HDF5_10X_TO_TEXT.out.numTranscripts).collect(),
        noMetaChannelHelper(readQualityMetrics).collect(),
        noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.pdf).collect(),
        noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.metrics).collect(),
        noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.barcodes).collect(),
        noMetaChannelHelper(cellFeatures).collect()
    )
    workflowProperties = [
        useSvmParameterEstimation: params.useSvmParameterEstimation,
        forceTwoClusterSolution: params.forceTwoClusterSolution,
        cbrbArgs: params.cbrbArgs
    ]
    WRITE_PROPERTIES(workflowProperties)
    cbrbProperties = combineIntoTupleChannel(metaWithArgs, WRITE_PROPERTIES.out)
    cbrbTearSheet = combineIntoTupleChannel(metaWithArgs, PLOT_CBRB_TEAR_SHEET.out)
    
    emit:
    svmCbrbParameters = svmCbrbParameters
    svmCbrbParameterEstimationPdf = svmCbrbParameterEstimationPdf
    h5 = CELLBENDER_REMOVEBACKGROUND.out.h5
    barcodes = CELLBENDER_REMOVEBACKGROUND.out.barcodes
    metrics = CELLBENDER_REMOVEBACKGROUND.out.metrics
    report = CELLBENDER_REMOVEBACKGROUND.out.report
    pdf = CELLBENDER_REMOVEBACKGROUND.out.pdf
    cbrbLog = CELLBENDER_REMOVEBACKGROUND.out.log
    checkpoint = CELLBENDER_REMOVEBACKGROUND.out.checkpoint
    dge = HDF5_10X_TO_TEXT.out.dge
    numTranscripts = HDF5_10X_TO_TEXT.out.numTranscripts
    cellFeatures = JOIN_CBRB_CELL_FEATURES.out.cbrbCellFeatures
    properties = cbrbProperties
    cbrbTearSheet = cbrbTearSheet

}