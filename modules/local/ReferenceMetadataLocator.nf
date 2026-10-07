// Ported from Zamboni scala

include { hasExtension ; withoutExtension ; withExtension ; subpath } from './FileUtil.nf'

def buildReferenceMetadataLocator(referenceFasta, overrides) {
    if (referenceFasta instanceof String) {
        referenceFasta = file(referenceFasta)
    }

    // -----------------------------
    // Constants
    // -----------------------------
    def FASTA_EXTENSIONS = ["fasta", "fa"]

    // TODO: the STAR index should be found based on the version of STAR
    def STAR_INDEX_SUBDIR = "STAR_indices/2.7.11a"

    def CONSENSUS_INTRONS = "consensus_introns.intervals"
    def SEQ_DICT = "dict"
    def EXON_INTERVALS = "exons.intervals"
    def GENE_INTERVALS = "genes.intervals"
    def MT_INTERVALS = "mt.intervals"
    def GTF = "gtf"
    def INTERGENIC_INTERVALS = "intergenic.intervals"
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


    // -----------------------------
    // Normalize FASTA base
    // -----------------------------
    def fastaNoGz = hasExtension(referenceFasta, "gz")
        ? withoutExtension(referenceFasta, "gz")
        : referenceFasta

    def matchedExt = FASTA_EXTENSIONS.find { ext -> hasExtension(fastaNoGz, ext) }

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
        referenceName: fastaBase.name,

        // directories
        starIndexDirectory: subpath(dir, STAR_INDEX_SUBDIR),
        
        // interval + annotation files
        // some of these are not used yet but there doesn't seem to be any harm in including them
        consensusIntronIntervals: withExtension(fastaBase, CONSENSUS_INTRONS),
        sequenceDictionary: withExtension(fastaBase, SEQ_DICT),
        exonIntervals: withExtension(fastaBase, EXON_INTERVALS),
        geneIntervals: withExtension(fastaBase, GENE_INTERVALS),
        gtf: withExtension(fastaBase, GTF),
        intergenicIntervals: withExtension(fastaBase, INTERGENIC_INTERVALS),
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

    ]
    // overrides is a list of strings in the format "<slot>:<path>" to override the reference bundle.
    // split each string, validate that the slot exists, and override the corresponding entry in the meta map.
    overrides.each { override ->
        def (slot, path) = override.split(':', 2)
        if (!meta.containsKey(slot)) {
            throw new IllegalArgumentException("Invalid reference override slot: " + slot)
        }
        // if path is the string "null", treat it as a request to remove the entry from the meta map.
        meta[slot] = (path == "null") ? null : file(path)
    }
    return meta
}

def getContigsWithLabel(contigGroupsFile, label) {
    if (!contigGroupsFile.exists()) {
        return []
    }
    def yaml = new org.yaml.snakeyaml.Yaml()
    def contigGroups = yaml.load(contigGroupsFile.text)
    def keys = contigGroups.findAll { _k, v ->
        v == label || (v instanceof Collection && v.contains(label))
    }.keySet() as List
    return keys
}

def loadMtSequences(contigGroupsFile) {
    return getContigsWithLabel(contigGroupsFile, 'MT')
}

def loadNonAutosomes(contigGroupsFile) {
    return getContigsWithLabel(contigGroupsFile, 'non-autosome')
}

def findReferenceFasta(reference, referenceMap) {
    if (reference.toString().contains('/')) {
        return file(reference)
    } else if (referenceMap.containsKey(reference)) {
        def path = file(referenceMap[reference])
        return path
    } else {
        throw new IllegalArgumentException("Reference fasta not found for: " + reference)
    }
}

def resolveReference(reference, referenceParents) {
    // if the reference contains a slash, assume it's a path and return it.
    // Otherwise, look up the reference in the children of referenceParents
    if (reference.toString().contains('/')) {
        return file(reference)
    }
        // reference lookup table, populated by scanning referenceParents for
    // <referenceParent>/<referenceName>/*.fasta.gz
    def referenceMap = referenceParents.collectEntries { parent ->
        files("${parent}/*/*.fasta.gz").collectEntries { f ->
            [(f.parent.name): f.toUriString()]
        }
    }

    return findReferenceFasta(reference, referenceMap)
}