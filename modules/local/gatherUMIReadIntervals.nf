include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process GATHER_UMI_READ_INTERVALS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(bam)
    path selectedCells
    val locusFunction
    val strandStrategy
    val functionalStrategy

    output:
    tuple val(meta), path("${output_file}"), emit: umiReadIntervals
    //tuple val("${task.process}"), val('GatherUMIReadIntervals'), eval("GatherUMIReadIntervals --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_GatherUMIReadIntervals
    
    script:
    output_file = meta.bamBase + ".umi_read_intervals.tsv.gz"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)

    """
    GatherUMIReadIntervals \
        --INPUT ${bam} \
        --OUTPUT ${output_file} \
        --CELL_BC_FILE ${selectedCells} \
        --FUNCTIONAL_STRATEGY ${functionalStrategy} \
        --STRAND_STRATEGY ${strandStrategy} \
        ${locusFunctionArgs}
    """
}