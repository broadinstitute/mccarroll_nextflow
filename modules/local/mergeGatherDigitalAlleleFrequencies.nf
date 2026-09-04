process MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES {
    label 'process_low'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_java:current'

    input:
    val library
    path digitalAlleleCounts
    output:
    path "${output_file}", emit: digitalAlleleFrequencies
    tuple val("${task.process}"), val('MergeGatherDigitalAlleleFrequencies'), eval("MergeGatherDigitalAlleleFrequencies --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeGatherDigitalAlleleFrequencies
    
    script:
    output_file = "${library}.allele_freq.txt"
    """
    MergeGatherDigitalAlleleFrequencies \
          --INPUT ${digitalAlleleCounts.join(' --INPUT ')} \
          --OUTPUT ${output_file}
    """
}