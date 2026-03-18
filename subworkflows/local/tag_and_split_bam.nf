include {FASTQ_TO_SAM} from '../../modules/local/fastqToSam.nf'

workflow tag_and_split_bam_workflow {
    take:
        manifest

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
    }

    emit:
    rawBam = FASTQ_TO_SAM.out.rawBam
}