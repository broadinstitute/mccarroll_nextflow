include { parseCbrbYamlArgs ; addSvmEstimatedParameters ; loadSvmEstimatedParameters ; makeCbrbLabel } from '../../modules/local/CbrbArgParser.nf'
include { noMetaChannelHelper ; combineIntoTupleChannel ; getUserName } from '../../modules/local/workflowUtil.nf'
include { SVM_ESTIMATE_CBRB_PARAMETERS } from '../../modules/local/svmEstimateCbrbParameters.nf'
include { CELLBENDER_REMOVEBACKGROUND  } from '../../modules/nf-core/cellbender/removebackground'
include { HDF5_10X_TO_TEXT             } from '../../modules/local/hdf5_10X_to_text.nf'
include { JOIN_CBRB_CELL_FEATURES      } from '../../modules/local/joinCbrbCellFeatures.nf'
include { WRITE_PROPERTIES             } from '../../modules/local/writeProperties.nf'
include { DUMP_ELBO_TABLE              } from '../../modules/local/dumpElboTable.nf'
include { PLOT_CBRB_TEAR_SHEET         } from '../../modules/local/plotCbrbTearSheet.nf'
include { SEND_EMAIL                   } from '../../modules/local/sendEmail.nf'
include { cbrbDir                      } from '../../modules/local/DirectoryUtil.nf'
include { subpath                      } from '../../modules/local/FileUtil.nf'
include { JOIN_AND_FILTER_TSV as DGE_SUMMARY_TO_BARCODES ; JOIN_AND_FILTER_TSV as DGE_SUMMARY_TO_NUM_TRANSCRIPTS } from '../../modules/local/joinAndFilterTsv.nf'

workflow cbrb_workflow {
    take:
    sparseDgeMatrix
    sparseDgeFeatures
    sparseDgeBarcodes
    cellFeatures
    denseDgeMatrix
    readQualityMetrics
    denseDgeSummary

    main:
    workflowProperties = [
        submitter: getUserName(),
        skipCbrb: params.skipCbrb,
        stage: 'cbrb'
    ]
    cbrb_label = makeCbrbLabel(params)
    meta = sparseDgeMatrix.map { meta, _file -> meta + [cbrb_label: cbrb_label] }

    if (params.skipCbrb) {
        denseDgeSummaryNewMeta = denseDgeSummary.combine(meta).map { _oldmeta, file, newmeta -> tuple(newmeta, file) }
        DGE_SUMMARY_TO_BARCODES(denseDgeSummaryNewMeta, 
        "${params.library}_cell_barcodes.csv", 
        ["NUM_GENIC_READS", "NUM_TRANSCRIPTS", "NUM_GENES"], // drop columns
        tuple([],[],[]), // join
        tuple([],[]), // set
        tuple([],[]), // min
        tuple([],[]), // max
        tuple([],[]), // include files
        tuple([],[]), // exclude files
        tuple([],[]), // include
        tuple([],[]), // exclude
        tuple([],[]), // rename columns],
        true // noHeader
        )
        barcodes = DGE_SUMMARY_TO_BARCODES.out.joinedAndFiltered
        dge = denseDgeMatrix.combine(meta).map { _oldmeta, file, newmeta -> tuple(newmeta, file) }
        DGE_SUMMARY_TO_NUM_TRANSCRIPTS(denseDgeSummaryNewMeta, 
        "${params.library}.cbrb.num_transcripts.txt", 
        ["NUM_GENIC_READS", "NUM_GENES"], // drop columns
        tuple([],[],[]), // join
        tuple([],[]), // set
        tuple([],[]), // min
        tuple([],[]), // max
        tuple([],[]), // include files
        tuple([],[]), // exclude files
        tuple([],[]), // include
        tuple([],[]), // exclude
        tuple(["CELL_BARCODE", "NUM_TRANSCRIPTS"], ["cell_barcode", "num_transcripts"]), // rename columns],
        false // noHeader
        )
        
        numTranscripts = DGE_SUMMARY_TO_NUM_TRANSCRIPTS.out.joinedAndFiltered
        metaWithArgs = meta

        // not generated when skipping CBRB
        h5 = channel.empty()
        metrics = channel.empty()
        report = channel.empty()
        pdf = channel.empty()
        cbrbLog = channel.empty()
        checkpoint = channel.empty()
        svmCbrbParameters = channel.empty()
        svmCbrbParameterEstimationPdf = channel.empty()
        cbrbTearSheet = channel.empty()
    } else {
        sparseDgeMatrixNoMeta = noMetaChannelHelper(sparseDgeMatrix)
        sparseDgeFeaturesNoMeta = noMetaChannelHelper(sparseDgeFeatures)
        sparseDgeBarcodesNoMeta = noMetaChannelHelper(sparseDgeBarcodes)
        cellFeaturesNoMeta = noMetaChannelHelper(cellFeatures)
        // all inputs share the same meta; any can be used
        parsedCbrbArgs = parseCbrbYamlArgs(params.cbrbArgs)
        useSvmParameterEstimation = params.useSvmParameterEstimation && (!parsedCbrbArgs.expectedCells || !parsedCbrbArgs.totalDropletsIncluded)
        if (useSvmParameterEstimation) {
            SVM_ESTIMATE_CBRB_PARAMETERS(
                params.library,
                sparseDgeMatrixNoMeta,
                sparseDgeFeaturesNoMeta,
                sparseDgeBarcodesNoMeta,
                cellFeaturesNoMeta,
                params.forceTwoClusterSolution,
            )
            parsedCbrbArgsChannel = SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameters.map { f -> addSvmEstimatedParameters(parsedCbrbArgs, loadSvmEstimatedParameters(f)) }
            svmCbrbParameters = combineIntoTupleChannel(meta, SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameters)
            svmCbrbParameterEstimationPdf = combineIntoTupleChannel(meta, SVM_ESTIMATE_CBRB_PARAMETERS.out.cbrbParameterEstimationPdf)
        }
        else {
            parsedCbrbArgsChannel = channel.value(parsedCbrbArgs)
            svmCbrbParameters = channel.empty()
            svmCbrbParameterEstimationPdf = channel.empty()
        }
        // TODO: does it have to be this hard?
        cbrbArgsMeta = parsedCbrbArgsChannel.map { p -> [cbrb_args: p.argList] }
        metaWithArgs = meta.combine(cbrbArgsMeta).map { m, a -> m + a }
        // Note that the directory containing sparse DGE file triplet is passed as the input to CBRB.  When running with fuse this shouldn't
        // matter because only the relevant files will need to be read, but when running on my computer,
        // the entire directory contents is pushed into the cloud to be available for CBRB.
        cbrbChannel = metaWithArgs
            .combine(sparseDgeMatrixNoMeta)
            .map { m, mat ->
                tuple(m, [mat.parent])
            }
        CELLBENDER_REMOVEBACKGROUND(cbrbChannel)
        HDF5_10X_TO_TEXT(CELLBENDER_REMOVEBACKGROUND.out.h5, noMetaChannelHelper(denseDgeMatrix), noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.log))
        DUMP_ELBO_TABLE(
            params.library,
            noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.h5),
        )
        PLOT_CBRB_TEAR_SHEET(
            params.library,
            cbrb_label,
            DUMP_ELBO_TABLE.out.collect(),
            noMetaChannelHelper(HDF5_10X_TO_TEXT.out.numTranscripts).collect(),
            noMetaChannelHelper(readQualityMetrics).collect(),
            noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.pdf).collect(),
            noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.metrics).collect(),
            noMetaChannelHelper(CELLBENDER_REMOVEBACKGROUND.out.barcodes).collect(),
            noMetaChannelHelper(cellFeatures).collect(),
        )
        workflowProperties += [
            useSvmParameterEstimation: params.useSvmParameterEstimation,
            forceTwoClusterSolution: params.forceTwoClusterSolution,
            cbrbArgs: params.cbrbArgs
        ]
        cbrbTearSheet = combineIntoTupleChannel(metaWithArgs, PLOT_CBRB_TEAR_SHEET.out)
        // TODO: Is there an easier way?
        fullCbrbDir = meta.map { m -> subpath(params.outdir, cbrbDir(tuple(m, []))) }
        SEND_EMAIL(
            "CBRB summary for ${params.library}",
            fullCbrbDir.map { it -> "CBRB summary for ${params.library} in ${it}" },
            params.email,
            PLOT_CBRB_TEAR_SHEET.out,
        )
        h5                            = CELLBENDER_REMOVEBACKGROUND.out.h5
        barcodes                      = CELLBENDER_REMOVEBACKGROUND.out.barcodes
        metrics                       = CELLBENDER_REMOVEBACKGROUND.out.metrics
        report                        = CELLBENDER_REMOVEBACKGROUND.out.report
        pdf                           = CELLBENDER_REMOVEBACKGROUND.out.pdf
        cbrbLog                       = CELLBENDER_REMOVEBACKGROUND.out.log
        checkpoint                    = CELLBENDER_REMOVEBACKGROUND.out.checkpoint
        dge                           = HDF5_10X_TO_TEXT.out.dge
        numTranscripts                = HDF5_10X_TO_TEXT.out.numTranscripts
    }
    WRITE_PROPERTIES(workflowProperties)
    cbrbProperties = combineIntoTupleChannel(metaWithArgs, WRITE_PROPERTIES.out)
    JOIN_CBRB_CELL_FEATURES(
        cellFeatures.map { m, file -> tuple(m + [cbrb_label: cbrb_label], file) },
        noMetaChannelHelper(numTranscripts),
    )
    cbrbCellFeatures               = JOIN_CBRB_CELL_FEATURES.out.cbrbCellFeatures

    emit:
    svmCbrbParameters             = svmCbrbParameters
    svmCbrbParameterEstimationPdf = svmCbrbParameterEstimationPdf
    h5                            = h5
    barcodes                      = barcodes
    metrics                       = metrics
    report                        = report
    pdf                           = pdf
    cbrbLog                       = cbrbLog
    checkpoint                    = checkpoint
    dge                           = dge
    numTranscripts                = numTranscripts
    cellFeatures                  = cbrbCellFeatures
    properties                    = cbrbProperties
    cbrbTearSheet                 = cbrbTearSheet
}
