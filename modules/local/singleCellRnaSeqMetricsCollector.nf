process SINGLE_CELL_RNA_SEQ_METRICS_COLLECTOR {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

input:
    tuple val(meta), path(inputBam), path(selectedCells)
    path referenceFasta
    path gtf
    path ribosomalIntervals
    val readQuality
    val mtSequences
    val cellBarcodeTag

output:
    tuple val(meta), path("${output_file}"), emit: metrics

script:
    output_file = "${meta.id}.fracIntronicExonicPerCell.txt.gz"
    mtSequencesArgs = mtSequences.collect{ seq -> "--MT_SEQUENCE ${seq}" }
    //  There is much sloppiness in GTF.  --VALIDATION_STRINGENCY SILENT causes problematic genes to be skipped.
    """
    SingleCellRnaSeqMetricsCollector \
        --INPUT ${inputBam} \
        --ANNOTATIONS_FILE ${gtf} \
        --OUTPUT ${output_file} \
        --RIBOSOMAL_INTERVALS ${ribosomalIntervals} \
        --CELL_BARCODE_TAG ${cellBarcodeTag} \
        --READ_MQ ${readQuality} \
        --CELL_BC_FILE ${selectedCells} \
        ${mtSequencesArgs.join(' ')} \
        --VALIDATION_STRINGENCY SILENT
    """

}
