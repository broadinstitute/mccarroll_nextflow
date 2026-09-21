include { MMC_FROMSPECIFIEDMARKERS } from '../../modules/local/MMC_fromSpecifiedMarkers.nf'
include { MTX_TO_H5AD                     } from '../../modules/local/mtx_to_h5ad.nf'
include { buildMmcModelLocator     } from '../../modules/local/MmcModelLocator.nf'
include { noMetaChannelHelper ; metaOnlyChannelHelper ; combineIntoTupleChannel ; getUserName } from '../../modules/local/workflowUtil.nf'
include { WRITE_PROPERTIES                } from '../../modules/local/writeProperties.nf'
include { COUNT_MMC_CELL_TYPES } from '../../modules/local/countMmcCellTypes.nf'

workflow MMC_fromSpecifiedMarkers_workflow {
    take:
    matrix_mtx
    features_tsv
    barcodes_tsv

    main:

    MTX_TO_H5AD(params.library, noMetaChannelHelper(matrix_mtx), noMetaChannelHelper(features_tsv), noMetaChannelHelper(barcodes_tsv))
    modelLocator = buildMmcModelLocator(params.mmcQueryMarkers)

    MMC_FROMSPECIFIEDMARKERS(
        params.library,
        modelLocator.queryMarkers,
        modelLocator.precomputedStats,
        MTX_TO_H5AD.out,
        params.mmcArgs)
    COUNT_MMC_CELL_TYPES(params.library, MMC_FROMSPECIFIEDMARKERS.out.csv_report)
    workflowProperties = [
        submitter: getUserName(),
        queryMarkers: params.mmcQueryMarkers.toUriString(),
        mmcModel: modelLocator.modelName,
        mmcArgs: params.mmcArgs,
        stage: 'mmc'
    ]
    WRITE_PROPERTIES(workflowProperties)
    outMeta = metaOnlyChannelHelper(matrix_mtx).map { m -> m + [mmcModel: modelLocator.modelName] }
    json_report = combineIntoTupleChannel(outMeta, MMC_FROMSPECIFIEDMARKERS.out.json_report)
    csv_report = combineIntoTupleChannel(outMeta, MMC_FROMSPECIFIEDMARKERS.out.csv_report)
    mmcProperties = combineIntoTupleChannel(outMeta, WRITE_PROPERTIES.out)
    cellTypeCounts = combineIntoTupleChannel(outMeta, COUNT_MMC_CELL_TYPES.out.cellTypeCounts)

    emit:
    json_report = json_report
    csv_report  = csv_report
    properties  = mmcProperties
    cellTypeCounts = cellTypeCounts
}
