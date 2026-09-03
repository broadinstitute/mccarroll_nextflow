process TAG_READ_WITH_GENE_FUNCTION {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(inputBam)
        path gtf
    output:
    tuple val(meta), path("${output_file}"), emit: taggedBam
    //tuple val("${task.process}"), val('TagReadWithGeneFunction'), eval("TagReadWithGeneFunction --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_TagReadWithGeneFunction
    
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