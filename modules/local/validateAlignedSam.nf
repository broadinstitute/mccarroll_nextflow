process VALIDATE_ALIGNED_SAM {
    label 'process_single'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(alignedBam)

    output:
        val meta


    script:
    """
     ValidateAlignedSam  --INPUT_BAM ${alignedBam}
    """
}