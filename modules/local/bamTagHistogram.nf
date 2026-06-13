process BAM_TAG_HISTOGRAM {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(inputBam)
        val tag
        val readQuality
        val extension
    output:
    tuple val(meta), path("${output_file}"), emit: histogram

    script:
    output_file = "${meta.id}.${extension}"
    """
    BamTagHistogram \
          --I ${inputBam} \
          --OUTPUT ${output_file} \
          --TAG ${tag} \
          --FILTER_PCR_DUPLICATES false \
          --VALIDATION_STRINGENCY SILENT \
          --READ_MQ ${readQuality}
    """
}