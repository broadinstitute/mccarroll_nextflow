process FASTQ_TO_SAM {
    label 'process_single'
    label 'conversion'

    container 'docker.io/broadinstitute/picard:latest'

    input:
        tuple val(index), path(fastq_r1), path(fastq_r2)
        val libraryName

    output:
    path "${output_file}", emit: rawBam

    script:
    // By not using 'def', the output_file variable will be available in both the script and the output declaration.
    output_file = libraryName + "." + index + ".unmapped.bam"
    """
    java -jar /usr/picard/picard.jar FastqToSam --F1 '${fastq_r1}' \
        --F2 '${fastq_r2}' --SAMPLE_NAME '${libraryName}' \
        --OUTPUT '${output_file}'
    """
}

