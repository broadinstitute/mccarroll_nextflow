process SVM_ESTIMATE_CBRB_PARAMETERS {
    label 'process_low'

     container 'quay.io/broadinstitute/dropsift:current'

    input:
    val library
    path sparseDgeMatrix
    path sparseDgeFeatures
    path sparseDgeBarcodes
    path cellFeatures
    val forceTwoClusterSolution

    output:
    path "${output_file}", emit: cbrbParameters
    path "${output_pdf}", emit: cbrbParameterEstimationPdf

    script:
    output_file = "${library}.cbrb_parameters.txt"
    output_pdf = "${library}.svm_cbrb_parameter_estimation.pdf"

    """
    Rscript -e 'message(date(), " Start ", "runIntronicSVM")' \
        -e 'suppressPackageStartupMessages(library(DropSift))' \
        -e 'runIntronicSVM(datasetName="${library}",dgeMatrixFile=".",useCBRBFeatures=FALSE,forceTwoClusterSolution=${forceTwoClusterSolution.toString().toUpperCase()},outPDF="${output_pdf}",outCellBenderInitialParameters="${output_file}",cellFeaturesFile="${cellFeatures}", random.seed=1)' \
        -e 'message(date(), " Done ", "runIntronicSVM")' 
    """
}