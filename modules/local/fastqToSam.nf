// TODO: nf-core/picard/fastqtosam should be used instead of our own process definition, but I need to figure out
// how to name the output file. Mattias De Smet says I can use a closure based on values in meta map.
// https://nextflow.io/docs/latest/workflow.html#outputs

process FASTQ_TO_SAM {
    label 'process_single'

    container 'docker.io/broadinstitute/picard:latest'

    input:
        tuple val(index), path(fastq_r1), path(fastq_r2)
        val libraryName

    output:
    path "${output_file}", emit: rawBam

    script:
    // By not using 'def', the output_file variable will be available in both the script and the output declaration.
    output_file = libraryName + "." + index + ".raw.bam"
    """
    java -jar /usr/picard/picard.jar FastqToSam --F1 '${fastq_r1}' \
        --F2 '${fastq_r2}' --SAMPLE_NAME '${libraryName}' \
        --LIBRARY_NAME '${libraryName}' \
        --PLATFORM ILLUMINA \
        --OUTPUT '${output_file}'
    """
}

