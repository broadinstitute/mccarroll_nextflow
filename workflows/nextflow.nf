include { MapMyCells_fromSpecifiedMarkers_workflow } from '../subworkflows/local/MapMyCells_fromSpecifiedMarkers.nf'
include { tag_and_split_bam_workflow } from '../subworkflows/local/tag_and_split_bam.nf'


// Main workflow
workflow NEXTFLOW {
    main:
    tag_and_split_bam_workflow(
        params.fastq_read1,
        params.fastq_read2,
        params.rawBam,
        params.library,
        params.baseRange,
        params.barcodedRead,
        params.allowedBarcodes
    )
    
    emit:
    splitBams = tag_and_split_bam_workflow.out.splitBams
}

