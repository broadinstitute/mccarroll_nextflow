// Centralize output subdirectory naming.
def alignmentDir(tuple) {
    def (meta, _file) = tuple
    return meta.referenceName + "/"
}

def cbrbDir(tuple) {
    def (meta, _file) = tuple
    return alignmentDir(tuple) + "cbrb/" + meta.cbrb_label + "/"
}

def cellSelectionDir(tuple) {
    def (meta, _file) = tuple
    return cbrbDir(tuple) + "cell_selection/" + meta.cell_selection_label + "/"
}

def standardAnalysisDir(tuple) {
    // Since there should be no user choices for standard analysis, outputs could just go into cell_selection
    // directory, but put them in a subdir to reduce clutter.
    return cellSelectionDir(tuple) + "standard_analysis/"
}

def dropulationDir(tuple) {
    def (meta, _file) = tuple
    if (!meta.containsKey('dropulation_label')) {
        error "dropulationDir() called with meta that does not contain dropulation_label: ${meta}"
    }
    return standardAnalysisDir(tuple) + "village/" + meta.dropulation_label + "/"
}

def mapMyCellsDir(tuple) {
    def (meta, _file) = tuple
    return standardAnalysisDir(tuple) + "map_my_cells/" + meta.mmcModel + "/"
}

