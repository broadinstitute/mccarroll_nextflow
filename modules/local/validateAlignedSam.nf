process VALIDATE_ALIGNED_SAM {
    label 'process_single'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(alignedBam)

    output:
        val meta
        //tuple val("${task.process}"), val('ValidateAlignedSam'), eval("ValidateAlignedSam --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_ValidateAlignedSam
    

    script:
    """
     ValidateAlignedSam  --INPUT_BAM ${alignedBam}
    """
}