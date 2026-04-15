// Ported from Zamboni scala

include { hasExtension; withoutExtension; withExtension; subpath } from './FileUtil.nf'

def buildReferenceMetadataLocator(referenceFasta) {
    if (referenceFasta instanceof String) {
        referenceFasta = file(referenceFasta)
    }

    // -----------------------------
    // Constants
    // -----------------------------
    def FASTA_EXTENSIONS = ["fasta", "fa"]

    def STAR_SUBDIR = "STAR"
    def STAR_INDICES_SUBDIR = "STAR_indices"
    def BASE_REFS = "baseRefs"

    def CONSENSUS_INTRONS = "consensus_introns.intervals"
    def SEQ_DICT = "dict"
    def EXON_INTERVALS = "exons.intervals"
    def GENE_INTERVALS = "genes.intervals"
    def MT_INTERVALS = "mt.intervals"
    def GTF = "gtf"
    def INTERGENIC_INTERVALS = "intergenic.intervals"
    def STAR_MEM = "memory_requirement_mb.txt"
    def RRNA_INTERVALS = "rRNA.intervals"
    def REDUCED_GTF = "reduced.gtf"
    def REFFLAT = "refFlat"
    def ORGANISMS = "organisms"
    def FAI = "fai"
    def GZI = "gzi"
    def DBSNP = "dbsnp.vcf"
    def DBSNP_INDEX = "dbsnp.vcf.idx"
    def DBSNP_INTERVALS = "dbsnp.intervals"
    def CONTIG_GROUPS = "contig_groups.yaml"
    def XIPHER_CONFIG = "xipher.yaml"
    def XIPHER_KNOWN = "xipher.variants_table.txt.gz"

    def STAR_FILES = [
            "Genome", "SA", "SAindex", "chrLength.txt", "chrName.txt",
            "chrNameLength.txt", "chrStart.txt", "exonInfo.tab",
            "genomeParameters.txt", "sjdbInfo.txt",
            "sjdbList.fromGTF.out.tab", "sjdbList.out.tab",
            "transcriptInfo.tab"
    ]

    def BWA_EXTENSIONS = [
            "64.amb", "64.ann", "64.bwt", "64.pac", "64.sa"
    ]

    // -----------------------------
    // Normalize FASTA base
    // -----------------------------
    def fastaNoGz = hasExtension(referenceFasta, "gz") ?
            withoutExtension(referenceFasta, "gz") :
            referenceFasta

    def matchedExt = FASTA_EXTENSIONS.find { hasExtension(fastaNoGz, it) }

    if (!matchedExt) {
        throw new RuntimeException("${referenceFasta.absolutePath} does not have a standard fasta extension")
    }

    def fastaBase = withoutExtension(fastaNoGz, matchedExt)
    def dir = referenceFasta.getParent()

    // -----------------------------
    // Build map
    // -----------------------------
    def meta = [

        // core
        referenceFasta: referenceFasta,
        directory: dir,
        fastaBase: fastaBase,
        referenceName: fastaBase.name,

        // directories
        starDirectory: subpath(dir, STAR_SUBDIR),
        baseRefsDirectory: subpath(dir, BASE_REFS),

        // interval + annotation files
        consensusIntronIntervals: withExtension(fastaBase, CONSENSUS_INTRONS),
        sequenceDictionary: withExtension(fastaBase, SEQ_DICT),
        exonIntervals: withExtension(fastaBase, EXON_INTERVALS),
        geneIntervals: withExtension(fastaBase, GENE_INTERVALS),
        gtf: withExtension(fastaBase, GTF),
        intergenicIntervals: withExtension(fastaBase, INTERGENIC_INTERVALS),
        starMemoryRequirementMB: withExtension(fastaBase, STAR_MEM),
        ribosomalIntervals: withExtension(fastaBase, RRNA_INTERVALS),
        reducedGtf: withExtension(fastaBase, REDUCED_GTF),
        refFlat: withExtension(fastaBase, REFFLAT),
        organisms: withExtension(fastaBase, ORGANISMS),
        mtIntervals: withExtension(fastaBase, MT_INTERVALS),

        // index + variant files
        fai: withExtension(referenceFasta, FAI),
        gzi: withExtension(referenceFasta, GZI),
        dbSnp: withExtension(fastaBase, DBSNP),
        dbSnpIndex: withExtension(fastaBase, DBSNP_INDEX),
        dbSnpIntervals: withExtension(fastaBase, DBSNP_INTERVALS),
        contigGroups: withExtension(fastaBase, CONTIG_GROUPS),

        // xipher
        xipherConfig: withExtension(fastaBase, XIPHER_CONFIG),
        xipherKnownVariants: withExtension(fastaBase, XIPHER_KNOWN),

        // collections
        bwaFiles: BWA_EXTENSIONS.collect { withExtension(referenceFasta, it) },
        starFiles: STAR_FILES.collect { subpath(subpath(dir, STAR_SUBDIR), it) }
    ]

    // -----------------------------
    // Methods (as closures)
    // -----------------------------
    meta.starDirectoryForVersion = { String version ->
        def versionDir = subpath(subpath(dir, STAR_INDICES_SUBDIR),version)
        versionDir.exists() ? versionDir : meta.starDirectory
    }

    return meta
}