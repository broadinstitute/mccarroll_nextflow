include { PICARD_FASTQTOSAM } from '../../modules/nf-core/picard/fastqtosam/main' 
include {COUNT_BARCODE_SEQUENCES} from '../../modules/local/countBarcodeSequences.nf'
include {CORRECT_SCRNA_READ_PAIRS} from '../../modules/local/correctScrnaReadPairs.nf'
include {SPLIT_BAM_BY_CELL} from '../../modules/local/splitBamByCell.nf'
include {collectInOrder} from '../../modules/local/workflowUtil.nf'

workflow tag_and_split_bam_workflow {
    take:
        fastq_read1
        fastq_read2
        rawBam
        library
        beadStructure
        allowedBarcodes

    main:
    if (fastq_read1.size() > 0) {
        // Check that read1 and read2 lists have the same length
        if (fastq_read1.size() != fastq_read2.size()) {
            error "The number of read1 and read2 files must be the same: " +
                    "found ${fastq_read1.size()} read1 files and ${fastq_read2.size()} read2 files."
        }
        fastqTuples = fastq_read1.withIndex().collect { read1, idx ->
            def read2 = fastq_read2[idx]
            // funky BAM file naming convention, plus passing meta.library so closuer in modules.config can set RG values
            return [[id: library + "." + idx + ".raw", library: library, collectIndex: idx], [read1, read2]]
        }
        fastqChannel = channel.fromList(fastqTuples)
        PICARD_FASTQTOSAM(fastqChannel)
        localRawBam = PICARD_FASTQTOSAM.out.bam
    } else if (rawBam.size() > 0) {
        // TODO: This doesn't work.  COUNT_BARCODE_SEQUENCES create a command line without the directory,
        //  which causes the process to fail because it can't find the BAM file.
        localRawBam = rawBam
    } else {
        error "Manifest must contain either 'fastq' or 'rawBam' key."
    }
    // collect() because all the BAMs need to be processed together.
    collectedRawBams = collectInOrder(localRawBam)
    COUNT_BARCODE_SEQUENCES(
            beadStructure,
            library,
            collectedRawBams,
            allowedBarcodes)
    CORRECT_SCRNA_READ_PAIRS(
            localRawBam,
            params.beadStructure,
            params.cellBarcodeTag,
            library,
            COUNT_BARCODE_SEQUENCES.out.barcodeCounts,
            [], // Default output BAM naming strategy
            true // Tag both reads
    )
    SPLIT_BAM_BY_CELL(
            library,
            collectInOrder(CORRECT_SCRNA_READ_PAIRS.out.correctedBam),
            params.targetBamSizeMBytes
    )
    // TODO: corrected_barcode_metrics output from CORRECT_SCRNA_READ_PAIRS should be merged across BAMs,
    // but no one really cares about that output.

    // Because SPLIT_BAM_BY_CELL.out.splitBams is a glob, it produces a channel containing a single item which is a
    // list of all the split BAMs.  We want to flatten that so that the output channel contains one item per split BAM.
    splitBams = SPLIT_BAM_BY_CELL.out.splitBams.flatten()
    emit:
    rawBam = localRawBam
    barcodeCounts = COUNT_BARCODE_SEQUENCES.out.barcodeCounts
    cbcCorrectedBam = CORRECT_SCRNA_READ_PAIRS.out.correctedBam
    splitBams = splitBams
    splitBamReport = SPLIT_BAM_BY_CELL.out.splitBamReport
    splitBamManifest = SPLIT_BAM_BY_CELL.out.splitBamManifest
    bamList = SPLIT_BAM_BY_CELL.out.bamList
}