def hasManualThresholds(params) {
    return params.minUMIsPerCell != null ||
        params.maxUMIsPerCell != null ||
        params.minIntronicPerCell != null ||
        params.maxIntronicPerCell != null
}

/**
 * Create label for manual-threshold cell selection.
 */
def makeManualThresholdLabel(params) {
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
    return hasManualThresholds(params) ? makeManualThresholdLabel(params) : 'auto'
}

def makeCbrbLabel(params) {
    return params.useSvmParameterEstimation && params.cbrbArgs.isEmpty() ?
        'auto' :
        String.format('%04x', params.cbrbArgs.hashCode())
}

def buildRestartInputPaths(outdir, referenceName, library, cbrbLabel, cellSelectionLabel, doBQSR) {
    def root = outdir instanceof java.nio.file.Path ?
        outdir :
        java.nio.file.Paths.get(outdir.toString())

    def alignmentDir = root.resolve(referenceName)
    def cbrbDir = alignmentDir.resolve('cbrb').resolve(cbrbLabel)
    def cellSelectionDir = cbrbDir.resolve('cell_selection').resolve(cellSelectionLabel)
    def alignedBamPattern = doBQSR ? "${library}.*.bam" : "${library}.*.chimeric_marked.bam"

    return [
        alignmentDir: alignmentDir,
        cbrbDir: cbrbDir,
        cellSelectionDir: cellSelectionDir,
        sparseDgeMatrix: alignmentDir.resolve('matrix.mtx.gz'),
        sparseDgeFeatures: alignmentDir.resolve('features.tsv.gz'),
        sparseDgeBarcodes: alignmentDir.resolve('barcodes.tsv.gz'),
        cellFeatures: alignmentDir.resolve("${library}.cell_features.txt"),
        dgeSummary: alignmentDir.resolve("${library}.digital_expression_summary.txt"),
        chimericTranscripts: alignmentDir.resolve("${library}.chimeric_transcripts.txt.gz"),
        readsPerCell: alignmentDir.resolve("${library}.numReads_perCell.txt.gz"),
        alignedBamPattern: alignmentDir.resolve(alignedBamPattern),
        cbrbBarcodes: cbrbDir.resolve("${library}_cell_barcodes.csv"),
        cbrbNumTranscripts: cbrbDir.resolve("${library}.cbrb.num_transcripts.txt"),
        cbrbDge: cbrbDir.resolve("${library}.cbrb.digital_expression.txt.gz"),
        cbrbCellFeatures: cbrbDir.resolve("${library}.cbrb.cell_features.txt"),
        selectedCellBarcodes: cellSelectionDir.resolve("${library}.selectedCellBarcodes.txt")
    ]
}
