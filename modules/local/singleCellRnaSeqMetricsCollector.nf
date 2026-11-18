process SINGLE_CELL_RNA_SEQ_METRICS_COLLECTOR {
    tag "${meta.id}"
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(inputBam), path(selectedCells)
    path referenceFasta
    path gtf
    path ribosomalIntervals
    val mtSequences
    val cellBarcodeTag

    output:
    tuple val(meta), path("${output_file}"), emit: metrics
    tuple val("${task.process}"), val('SingleCellRnaSeqMetricsCollector'), eval("SingleCellRnaSeqMetricsCollector --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_SingleCellRnaSeqMetricsCollector

    script:
    output_file = "${meta.id}.fracIntronicExonicPerCell.txt.gz"
    mtSequencesArgs = mtSequences.collect { seq -> "--MT_SEQUENCE ${seq}" }
    //  There is much sloppiness in GTF.  --VALIDATION_STRINGENCY SILENT causes problematic genes to be skipped.
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    // READER_THREADS and WORKER_THREADS are hidden options that replace NUM_THREADS.  The per-cell accumulation is the
    // bottleneck, so (per Drop-seq PR #611) use one reader and give every CPU to the workers.
    """
    SingleCellRnaSeqMetricsCollector \
        -m ${javaMemMb}m \
        --INPUT ${inputBam} \
        --ANNOTATIONS_FILE ${gtf} \
        --OUTPUT ${output_file} \
        --RIBOSOMAL_INTERVALS ${ribosomalIntervals} \
        --CELL_BARCODE_TAG ${cellBarcodeTag} \
        --CELL_BC_FILE ${selectedCells} \
        ${mtSequencesArgs.join(' ')} \
        --VALIDATION_STRINGENCY SILENT \
        --READER_THREADS 1 \
        --WORKER_THREADS ${task.cpus} ${task.ext.libdeflateArgs ?: ''}
    """
}
