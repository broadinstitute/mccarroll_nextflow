process TAG_READ_WITH_GENE_FUNCTION {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(inputBam)
        path gtf
    output:
    tuple val(meta), path("${output_file}"), emit: taggedBam

    script:
    output_file = meta.id + ".mapped_tagged.bam"
    """
    TagReadWithGeneFunction \
          --I ${inputBam} \
          --O ${output_file} \
          --ANNOTATIONS_FILE ${gtf} \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT
    """
}