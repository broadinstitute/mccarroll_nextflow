include { parseCbrbYamlArgs; addSvmEstimatedParameters; loadSvmEstimatedParameters } from '../../modules/local/CbrbArgParser.nf'
include { SVM_ESTIMATE_CBRB_PARAMETERS } from '../../modules/local/svmEstimateCbrbParameters.nf'
include { CELLBENDER_REMOVEBACKGROUND } from '../../modules/nf-core/cellbender/removebackground/main.nf'

workflow cbrb_workflow {
    take:
    sparseDgeMatrix
    sparseDgeFeatures
    sparseDgeBarcodes
    cellFeatures

    main:
    sparseDgeMatrixNoMeta = sparseDgeMatrix.map { _meta, file -> file }
    sparseDgeFeaturesNoMeta = sparseDgeFeatures.map { _meta, file -> file }
    sparseDgeBarcodesNoMeta = sparseDgeBarcodes.map { _meta, file -> file }
    cellFeaturesNoMeta = cellFeatures.map { _meta, file -> file }
    meta = sparseDgeMatrix.map { meta, _file -> meta } // just take the meta from one of the inputs, they should all be the same
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
        svmCbrbParameters = meta.combine(SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameters).map { m, f -> tuple(m, f) }
        svmCbrbParameterEstimationPdf = meta.combine(SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameterEstimationPdf).map { m, f -> tuple(m, f) }
    } else {
        parsedCbrbArgsChannel = channel.value(parsedCbrbArgs)
        svmCbrbParameters = []
        svmCbrbParameterEstimationPdf = []
    }
    // TODO: does it have to be this hard?
    cbrbArgsMeta = parsedCbrbArgsChannel.map { p -> [cbrb_args: p.argList]}
    metaWithArgs = meta.combine(cbrbArgsMeta).map { m, a -> m + a }
    cbrbChannel = metaWithArgs.combine(sparseDgeMatrixNoMeta).combine(sparseDgeFeaturesNoMeta).combine(sparseDgeBarcodesNoMeta).map { 
        m, mat, feat, barc -> tuple(m, [mat, feat, barc]) 
        }
    CELLBENDER_REMOVEBACKGROUND(cbrbChannel)
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

}