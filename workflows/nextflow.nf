include { MapMyCells_fromSpecifiedMarkers_workflow } from '../subworkflows/local/MapMyCells_fromSpecifiedMarkers.nf'
include { tag_and_split_bam_workflow } from '../subworkflows/local/tag_and_split_bam.nf'
include { align_locus_function_workflow } from '../subworkflows/local/align_locus_function.nf'


// Main workflow
workflow NEXTFLOW {
    main:
    tag_and_split_bam_workflow(
        params.fastq_read1,
        params.fastq_read2,
        params.rawBam,
        params.library,
        params.beadStructure,
        params.allowedBarcodes
    )
    align_locus_function_workflow(
            tag_and_split_bam_workflow.out.splitBams,
            params.beadStructure
    )

    
    emit:
    unmappedBam = tag_and_split_bam_workflow.out.splitBams
    alignedBam = align_locus_function_workflow.out.alignedBam
    alignedBai = align_locus_function_workflow.out.alignedBai
}

