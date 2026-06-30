def hasManualCellSelectionThresholds(params) {
    return params.minUMIsPerCell != null ||
        params.maxUMIsPerCell != null ||
        params.minIntronicPerCell != null ||
        params.maxIntronicPerCell != null
}

/**
 * Create label for manual-threshold cell selection.
 */
def makeManualCellSelectionLabel(params) {
    def labelComponents = []

    if (params.minUMIsPerCell != null ||
        params.maxUMIsPerCell != null) {

        def minUmi = params.minUMIsPerCell ?: 1
        def maxUmi = params.maxUMIsPerCell != null ?
            params.maxUMIsPerCell.toString() :
            'Inf'

        labelComponents << "umi_${minUmi}-${maxUmi}"
    }

    if (params.minIntronicPerCell != null ||
        params.maxIntronicPerCell != null) {

        def minIntronic = params.minIntronicPerCell ?: 0.0
        def maxIntronic = params.maxIntronicPerCell ?: 1.0
        labelComponents << String.format(
            'intronic_%.3f-%.3f',
            minIntronic as Float,
            maxIntronic as Float
        )
    }

    return labelComponents.join('_')
}

def makeCellSelectionLabel(params) {
    return hasManualCellSelectionThresholds(params) ? makeManualCellSelectionLabel(params) : 'auto'
}

def makeCbrbLabel(params) {
    return params.useSvmParameterEstimation && params.cbrbArgs.isEmpty() ?
        'auto' :
        String.format('%04x', params.cbrbArgs.hashCode())
}

/**
 * Render outdir as a full path string, whether it arrives as a String or a java.nio Path,
 * for a local or cloud (e.g. gs://) location.
 *
 * The subtlety is the cloud case: a GCS Path's toString() returns only the in-bucket object
 * key (e.g. "/alecw/out"), dropping the "gs://bucket" prefix, whereas toUri() reproduces the
 * full "gs://bucket/alecw/out". For the default (local) filesystem, toString() is correct and
 * toUri() would wrongly prepend "file://", so we only use the URI for non-default filesystems.
 */
def outdirToString(outdir) {
    if (outdir instanceof java.nio.file.Path &&
        outdir.fileSystem != java.nio.file.FileSystems.default) {
        return outdir.toUri().toString()
    }
    return outdir.toString()
}

def buildRestartInputPaths(outdir, referenceName, library, cbrbLabel, cellSelectionLabel, doBQSR) {
    // Build paths via plain string concatenation so cloud URIs survive intact. Routing through
    // java.nio Paths/Path mangles them: Paths.get("gs://b/x") collapses the "//" into "gs:/b/x",
    // and a GCS Path's toString() drops the "gs://bucket" prefix entirely. Either way the
    // downstream channel.fromPath(pathPattern.toString()) calls break. channel.fromPath accepts
    // a "gs://..." string directly, so keeping these as strings is both correct and simplest.
    def root = outdirToString(outdir).replaceFirst('/+$', '')

    def alignmentDir = "${root}/${referenceName}"
    def cbrbDir = "${alignmentDir}/cbrb/${cbrbLabel}"
    def cellSelectionDir = "${cbrbDir}/cell_selection/${cellSelectionLabel}"
    def alignedBamPattern = doBQSR ? "${library}.*.bam" : "${library}.*.chimeric_marked.bam"

    return [
        alignmentDir: alignmentDir,
        cbrbDir: cbrbDir,
        cellSelectionDir: cellSelectionDir,
        sparseDgeMatrix: "${alignmentDir}/matrix.mtx.gz",
        sparseDgeFeatures: "${alignmentDir}/features.tsv.gz",
        sparseDgeBarcodes: "${alignmentDir}/barcodes.tsv.gz",
        cellFeatures: "${alignmentDir}/${library}.cell_features.txt",
        dgeSummary: "${alignmentDir}/${library}.digital_expression_summary.txt",
        chimericTranscripts: "${alignmentDir}/${library}.chimeric_transcripts.txt.gz",
        readsPerCell: "${alignmentDir}/${library}.numReads_perCell.txt.gz",
        alignedBamPattern: "${alignmentDir}/${alignedBamPattern}",
        cbrbBarcodes: "${cbrbDir}/${library}_cell_barcodes.csv",
        cbrbNumTranscripts: "${cbrbDir}/${library}.cbrb.num_transcripts.txt",
        cbrbDge: "${cbrbDir}/${library}.cbrb.digital_expression.txt.gz",
        cbrbCellFeatures: "${cbrbDir}/${library}.cbrb.cell_features.txt",
        selectedCellBarcodes: "${cellSelectionDir}/${library}.selectedCellBarcodes.txt"
    ]
}
