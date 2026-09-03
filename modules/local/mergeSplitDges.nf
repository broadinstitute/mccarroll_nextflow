process MERGE_SPLIT_DGES {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path dges

    output:
    path "${output_file}", emit: dge
    //tuple val("${task.process}"), val('MergeSplitDges'), eval("MergeSplitDges --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeSplitDges
  
    script:
    output_file = "${library}.digital_expression.txt.gz"
     // --HEADER_STRINGENCY NONE because rules that each #LIBRARY in header has a prefix, and a unique UEI, are violated.
    """
    MergeSplitDges \
        --INPUT ${dges.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
      --OUTPUT_HEADER true \
      --HEADER_STRINGENCY NONE
    """
}