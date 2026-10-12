// Ported from Zamboni scala

include { hasExtension ; withoutExtension ; withExtension ; subpath } from './FileUtil.nf'

def buildReferenceMetadataLocator(referenceFasta, overrides, starIndexVersionMap) {
    if (referenceFasta instanceof String) {
        referenceFasta = file(referenceFasta)
    }

    // -----------------------------
    // Constants
    // -----------------------------
    def FASTA_EXTENSIONS = ["fasta", "fa"]


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
    // Get the STAR version used by STAR_ALIGN process from environment.yml.
    def STAR_ALIGN_VERSION = getStarAlignVersion()
    // Try to find a STAR index directory that will work with the STAR version used by STAR_ALIGN
    def STAR_INDEX_SUBDIR = "STAR_indices/${STAR_ALIGN_VERSION}"
    def starIndexDirectory = subpath(dir, STAR_INDEX_SUBDIR)
    if (!starIndexDirectory.exists() && starIndexVersionMap.containsKey(STAR_ALIGN_VERSION)) {
        def compatibleVersions = starIndexVersionMap[STAR_ALIGN_VERSION]
        def altStarIndexDirectory = compatibleVersions
            .collect { version -> subpath(dir, "STAR_indices/${version}") }
            .find { altDir -> altDir.exists() }
        if (altStarIndexDirectory != null) {
            starIndexDirectory = altStarIndexDirectory
        }
    }
    // If none of the compatible STAR index versions exist, the original starIndexDirectory will be used (even if it doesn't exist)
    // Maybe the user will override the STAR index location manually if none of the compatible versions exist.
    // Non-existence will be checked after overrides are applied.

    // -----------------------------
    // Build map
    // -----------------------------
    def meta = [

        // core
        referenceFasta: referenceFasta,
        referenceName: fastaBase.name,

        // directories
        starIndexDirectory: starIndexDirectory,
        
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
    // Fail fast if the version-specific STAR index is missing, rather than letting
    // STAR_ALIGN fail later with a cryptic error.
    if (meta.starIndexDirectory != null && !meta.starIndexDirectory.exists()) {
        throw new IllegalStateException(
            "STAR index directory not found: ${meta.starIndexDirectory}. " +
            "It must match the STAR version (${getStarAlignVersion()}) specified in " +
            "modules/nf-core/star/align/environment.yml. Build the index, update params.starIndexVersionMap, or override " +
            "the 'starIndexDirectory' slot via params.referenceOverride."
        )
    }
    return meta
}

// Parse the STAR version pinned in the nf-core STAR_ALIGN module's environment.yml,
// e.g. the "bioconda::star=2.7.11b" dependency -> "2.7.11b".  This keeps the STAR
// genome index directory in sync with the actual aligner version.
// This is not good nf-core style, but running the docker image merely to get the STAR version would be expensive.
def getStarAlignVersion() {
    def envYml = file("${projectDir}/modules/nf-core/star/align/environment.yml")
    def doc = new org.yaml.snakeyaml.Yaml().load(envYml.text)
    def deps = (doc.dependencies ?: []) as List
    def starDep = deps.find { d -> (d as String) =~ /(?:^|::)star=/ }
    if (!starDep) {
        throw new IllegalStateException("No 'star=' dependency found in ${envYml}")
    }
    return (starDep as String).replaceAll(/.*star=/, '').trim()
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