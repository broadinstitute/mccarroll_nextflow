process VALIDATE_SAM_FILE {
    tag "${meta.id}"
    label 'process_single'

    container 'docker.io/broadinstitute/picard:latest'

    input:
    tuple val(meta), path(inputBam)
    path reference

    output:
    path "${output_file}", emit: validate_report
    tuple val("${task.process}"), val('validateSamFile'), eval("java -jar /usr/picard/picard.jar FastqToSam --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_validateSamFile

    script:
    // By not using 'def', the output_file variable will be available in both the script and the output declaration.
    output_file = meta.id + ".validate_sam"
    """
    java -jar /usr/picard/picard.jar ValidateSamFile --INPUT '${inputBam}' \
        --OUTPUT '${output_file}' --REFERENCE_SEQUENCE '${reference}'
    """
}
