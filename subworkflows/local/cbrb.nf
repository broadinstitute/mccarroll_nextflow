include { parseCbrbYamlArgs; addSvmEstimatedParameters; loadSvmEstimatedParameters } from '../../modules/local/CbrbArgParser.nf'
include { SVM_ESTIMATE_CBRB_PARAMETERS } from '../../modules/local/svmEstimateCbrbParameters.nf'

workflow cbrb_workflow {
    take:
    sparseDgeMatrix
    sparseDgeFeatures
    sparseDgeBarcodes
    cellFeatures

    main:
    parsedCbrbArgs = parseCbrbYamlArgs(params.cbrbArgs)
    useSvmParameterEstimation = params.useSvmParameterEstimation && 
        (!parsedCbrbArgs.expectedCells || !parsedCbrbArgs.totalDropletsIncluded)
    if (useSvmParameterEstimation) {
        SVM_ESTIMATE_CBRB_PARAMETERS(
            params.library,
            sparseDgeMatrix.map { _meta, file -> file },
            sparseDgeFeatures.map { _meta, file -> file },
            sparseDgeBarcodes.map { _meta, file -> file },
            cellFeatures.map { _meta, file -> file },
            params.forceTwoClusterSolution
        )
        parsedCbrbArgsChannel = SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameters.map{f -> addSvmEstimatedParameters(parsedCbrbArgs,loadSvmEstimatedParameters(f))}
    } else {
        parsedCbrbArgsChannel = channel.value(parsedCbrbArgs)
    }

}