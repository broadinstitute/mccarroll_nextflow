process JOIN_CBRB_CELL_FEATURES {
    label 'process_low'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'

    input:
    tuple val(meta), path(cellFeatures)
    path cbrbNumTranscripts

    output:
    tuple val(meta), path("${output_file}"), emit: cbrbCellFeatures

    script:
    output_file = "${meta.id}.cbrb.cell_features.txt"

    """
    Rscript -e 'message(date(), " Start ", "joinCbrbCellFeatures")' \
    -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
    -e 'joinCbrbCellFeatures(cellFeaturesFile="${cellFeatures}",cbrbRetainedUMIsFile="${cbrbNumTranscripts}",outFile="${output_file}")' \
    -e 'message(date(), " Done ", "joinCbrbCellFeatures")' 
    """
}