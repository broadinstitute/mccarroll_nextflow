process VALIDATE_ALIGNED_SAM {
    label 'process_single'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(alignedBam)

    output:
    val meta, emit: meta
    tuple val("${task.process}"), val('ValidateAlignedSam'), eval("ValidateAlignedSam --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_ValidateAlignedSam

    script:
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    """
     ValidateAlignedSam  \
        -m ${javaMemMb}m \
        --INPUT_BAM ${alignedBam}
    """
}
