include { MAPMYCELLS_FROMSPECIFIEDMARKERS } from '../../modules/local/MapMyCells_fromSpecifiedMarkers.nf'
include { MTX_TO_H5AD                     } from '../../modules/local/mtx_to_h5ad.nf'
include {buildMapMyCellsModelLocator} from '../../modules/local/MapMyCellsModelLocator.nf'
include { noMetaChannelHelper; metaOnlyChannelHelper; combineIntoTupleChannel } from '../../modules/local/workflowUtil.nf'

workflow MapMyCells_fromSpecifiedMarkers_workflow  {
    take:
        matrix_mtx
        features_tsv
        barcodes_tsv

    main:
    
    MTX_TO_H5AD(params.library,noMetaChannelHelper(matrix_mtx),noMetaChannelHelper(features_tsv),noMetaChannelHelper(barcodes_tsv))
    modelLocator = buildMapMyCellsModelLocator(params.mapMyCellsQueryMarkers)
    
    MAPMYCELLS_FROMSPECIFIEDMARKERS(
        params.library,
        modelLocator.queryMarkers,
        modelLocator.precomputedStats,
        MTX_TO_H5AD.out,
        params.mapMyCellsArgs)
    outMeta = metaOnlyChannelHelper(matrix_mtx).map { m -> m + [mmcModel: modelLocator.modelName] }
    json_report = combineIntoTupleChannel(outMeta, MAPMYCELLS_FROMSPECIFIEDMARKERS.out.json_report)
    csv_report = combineIntoTupleChannel(outMeta, MAPMYCELLS_FROMSPECIFIEDMARKERS.out.csv_report)
    emit:
    json_report = json_report
    csv_report = csv_report
}

