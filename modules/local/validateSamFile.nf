// TODO: nf-core/picard/fastqtosam should be used instead of our own process definition, but I need to figure out
// how to name the output file. Mattias De Smet says I can use a closure based on values in meta map.
// https://nextflow.io/docs/latest/workflow.html#outputs

process VALIDATE_SAM_FILE {
    label 'process_single'

    container 'docker.io/broadinstitute/picard:latest'

    input:
        tuple val(meta), path(inputBam)

    output:
    path "${output_file}"

    script:
    // By not using 'def', the output_file variable will be available in both the script and the output declaration.
    output_file = meta.id + ".validate_sam"
    """
    java -jar /usr/picard/picard.jar ValidateSamFile --INPUT '${inputBam}' \
        --OUTPUT '${output_file}'
    """
}

