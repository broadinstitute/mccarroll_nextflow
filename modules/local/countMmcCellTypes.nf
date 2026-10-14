process COUNT_MMC_CELL_TYPES {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_python:current'

    input:
    val library
    path cellTypeAnnotations

    output:
    path "$output_file", emit: cellTypeCounts
   tuple val("${task.process}"), val('countMmcCellTypes'), eval("cat /etc/dropseq-version"), topic: versions, emit: versions_countMmcCellTypes
 
    script:
    output_file = "${library}.cell_type_counts.tsv"
    """
    count_mmc_celltypes \
          --input ${cellTypeAnnotations} \
          --output ${output_file}
    """
}