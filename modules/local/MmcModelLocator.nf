include { withoutExtension ; withExtension } from './FileUtil.nf'

def buildMmcModelLocator(queryMarkers) {
    if (queryMarkers instanceof String) {
        queryMarkers = file(queryMarkers)
    }
    def queryMarkersExtension = "query_markers.json"
    def precomputedStatsExtension = "precomputed_stats.h5"
    def meta = [
        queryMarkers: queryMarkers,
        precomputedStats: withExtension(withoutExtension(queryMarkers, queryMarkersExtension), precomputedStatsExtension)
    ]
    return meta
}
