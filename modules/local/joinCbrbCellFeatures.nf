process JOIN_CBRB_CELL_FEATURES {
    tag "${meta.id}"
    label 'process_low'

    container 'us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current'

    input:
    tuple val(meta), path(cellFeatures)
    path cbrbNumTranscripts

    output:
    tuple val(meta), path("${output_file}"), emit: cbrbCellFeatures
    tuple val("${task.process}"), val('joinCbrbCellFeatures'), eval("cat /etc/dropseq-version"), topic: versions, emit: versions_joinCbrbCellFeatures
    
    script:
    output_file = "${meta.id}.cbrb.cell_features.txt"

    """
    Rscript -e 'message(date(), " Start ", "joinCbrbCellFeatures")' \
    -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
    -e 'joinCbrbCellFeatures(cellFeaturesFile="${cellFeatures}",cbrbRetainedUMIsFile="${cbrbNumTranscripts}",outFile="${output_file}")' \
    -e 'message(date(), " Done ", "joinCbrbCellFeatures")' 
    """
}
