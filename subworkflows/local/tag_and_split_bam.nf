include {FASTQ_TO_SAM} from '../../modules/local/fastqToSam.nf'
include {COUNT_BARCODE_SEQUENCES} from '../../modules/local/countBarcodeSequences.nf'
include {CORRECT_SCRNA_READ_PAIRS} from '../../modules/local/correctScrnaReadPairs.nf'
include {SPLIT_BAM_BY_CELL} from '../../modules/local/splitBamByCell.nf'

workflow tag_and_split_bam_workflow {
    take:
        fastq_read1
        fastq_read2
        rawBam
        library
        baseRange
        barcodedRead
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
            return [idx, read1, read2]
        }
        fastqChannel = channel.fromList(fastqTuples)
        FASTQ_TO_SAM(
                fastqChannel,
                library)
        localRawBam = FASTQ_TO_SAM.out.rawBam
    } else if (rawBam.size() > 0) {
        // TODO: This doesn't work.  COUNT_BARCODE_SEQUENCES create a command line without the directory,
        //  which causes the process to fail because it can't find the BAM file.
        localRawBam = rawBam
    } else {
        error "Manifest must contain either 'fastq' or 'rawBam' key."
    }
    COUNT_BARCODE_SEQUENCES(
            baseRange,
            barcodedRead,
            library,
            localRawBam.collect(),
            allowedBarcodes)
    CORRECT_SCRNA_READ_PAIRS(
            localRawBam,
            baseRange,
            barcodedRead,
            library,
            COUNT_BARCODE_SEQUENCES.out.barcodeCounts,
            [], // Default output BAM naming strategy
            true // Tag both reads
    )
    SPLIT_BAM_BY_CELL(
            library,
            CORRECT_SCRNA_READ_PAIRS.out.correctedBam.collect()
    )
    // TODO: corrected_barcode_metrics output from CORRECT_SCRNA_READ_PAIRS should be merged across BAMs,
    // but no one really cares about that output.
    emit:
    rawBam = localRawBam
    barcodeCounts = COUNT_BARCODE_SEQUENCES.out.barcodeCounts
    cbcCorrectedBam = CORRECT_SCRNA_READ_PAIRS.out.correctedBam
    splitBams = SPLIT_BAM_BY_CELL.out.splitBams
    splitBamReport = SPLIT_BAM_BY_CELL.out.splitBamReport
    splitBamManifest = SPLIT_BAM_BY_CELL.out.splitBamManifest
    bamList = SPLIT_BAM_BY_CELL.out.bamList
}