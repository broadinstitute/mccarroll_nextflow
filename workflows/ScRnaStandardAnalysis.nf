workflow ScRnaStandardAnalysis {
    take:
    alignedBams: Path
    rawDge: Path
    cbrbDge: Path
    library: String
    selectedCells: Path
    locusFunction: String
    cbrbSelectedCellsReport: Path
    discoverMetaGenes: Boolean
    markChimericReads: Boolean
    ambientCells: Path
    donor: String
    metageneDgeFunctionalStrategy: String


}