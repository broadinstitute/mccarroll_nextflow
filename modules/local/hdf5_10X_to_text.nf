process HDF5_10X_TO_TEXT {
    label 'process_medium'

    container 'quay.io/broadinstitute/drop-seq_python:current'
    memory '8 GB'

    input:
        tuple val(meta), path(inputH5)
        path header // Optional.  Typically a DGE from which header lines are to be copied.
        path cbrb_log // Optional.  CBRB command is extracted from this. 
    output:
        tuple val(meta), path("${output_file}"), emit: dge
        tuple val(meta), path("${output_sizes}"), emit: numTranscripts

    script:
    output_file = "${meta.id}.cbrb.digital_expression.txt.gz"
    output_sizes = "${meta.id}.cbrb.num_transcripts.txt"
    if (header) {
        headerArgs = "--header ${header}"
    } else {
        headerArgs = ""
    }
    if (cbrb_log) {
        cbrbArgs = "--cbrb-log ${cbrb_log}"
    } else {
        cbrbArgs = ""
    }
    """
    hdf5_10X_to_text \
        --input ${inputH5} \
        --output ${output_file} \
        --output-sizes ${output_sizes} \
        ${headerArgs} \
        ${cbrbArgs}
    """
}