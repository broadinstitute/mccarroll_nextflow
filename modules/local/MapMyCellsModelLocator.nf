include { withoutExtension; withExtension } from './FileUtil.nf'

def buildMapMyCellsModelLocator(queryMarkers) {
    if (queryMarkers instanceof String) {
        queryMarkers = file(queryMarkers)
    }
    def queryMarkersExtension = "query_markers.json"
    def precomputedStatsExtension = "precomputed_stats.h5"
    def meta = [
        modelName: withoutExtension(queryMarkers, queryMarkersExtension).name,
        queryMarkers: queryMarkers,
        precomputedStats: withExtension(withoutExtension(queryMarkers, queryMarkersExtension), precomputedStatsExtension)
    ]
    return meta
}