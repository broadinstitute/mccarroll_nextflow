process VALIDATE_SAM_FILE {
    label 'process_single'

    container 'docker.io/broadinstitute/picard:latest'

    input:
        tuple val(meta), path(inputBam)
        path reference

    output:
    path "${output_file}"

    script:
    // By not using 'def', the output_file variable will be available in both the script and the output declaration.
    output_file = meta.id + ".validate_sam"
    """
    java -jar /usr/picard/picard.jar ValidateSamFile --INPUT '${inputBam}' \
        --OUTPUT '${output_file}' --REFERENCE_SEQUENCE '${reference}'
    """
}

