include {FASTQ_TO_SAM} from '../../modules/local/fastqToSam.nf'
include {COUNT_BARCODE_SEQUENCES} from '../../modules/local/countBarcodeSequences.nf'
include {CORRECT_SCRNA_READ_PAIRS} from '../../modules/local/correctScrnaReadPairs.nf'

workflow tag_and_split_bam_workflow {
    take:
        manifest
        allowedBarcodes

    main:
    if (manifest.containsKey('fastq')) {
        fastqLists = manifest['fastq']
        if (fastqLists['read1'] instanceof String) {
            fastqLists['read1'] = [fastqLists['read1']]
        }
        if (fastqLists['read2'] instanceof String) {
            fastqLists['read2'] = [fastqLists['read2']]
        }
        print ("Read1 files: ${fastqLists['read1']}")
        print ("Read2 files: ${fastqLists['read2']}")
        // Check that read1 and read2 lists have the same length
        if (fastqLists['read1'].size() != fastqLists['read2'].size()) {
            error "The number of read1 and read2 files must be the same: " +
                    "found ${fastqLists['read1'].size()} read1 files and ${fastqLists['read2'].size()} read2 files."
        }
        fastqTuples = fastqLists['read1'].withIndex().collect { read1, idx ->
            def read2 = fastqLists['read2'][idx]
            return [idx, read1, read2]
        }
        print ("Fastq tuples: ${fastqTuples}")
        fastqChannel = channel.fromList(fastqTuples)
        fastqChannel.view()
        FASTQ_TO_SAM(
                fastqChannel,
                manifest['library'])
        rawBam = FASTQ_TO_SAM.out.rawBam
    } else if (manifest.containsKey('rawBam')) {
        rawBam = channel.fromPath(manifest['rawBam'])
    } else {
        error "Manifest must contain either 'fastq' or 'rawBam' key."
    }
    COUNT_BARCODE_SEQUENCES(
            manifest['baseRange'],
            manifest['barcodedRead'],
            manifest['library'],
            rawBam.collect(),
            allowedBarcodes)
    CORRECT_SCRNA_READ_PAIRS(
            rawBam,
            manifest['baseRange'],
            manifest['barcodedRead'],
            manifest['library'],
            COUNT_BARCODE_SEQUENCES.out.barcodeCounts,
            [], // Default output BAM naming strategy
            true // Tag both reads
    )
    // TODO: corrected_barcode_metrics output from CORRECT_SCRNA_READ_PAIRS should be merged across BAMs,
    // but no one really cares about that output.
    emit:
    rawBam = FASTQ_TO_SAM.out.rawBam
    barcodeCounts = COUNT_BARCODE_SEQUENCES.out.barcodeCounts
    cbcCorrectedBam = CORRECT_SCRNA_READ_PAIRS.out.correctedBam
}