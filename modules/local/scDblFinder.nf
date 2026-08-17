include { replaceExtension } from './FileUtil.nf'

process SC_DBL_FINDER {
    label 'process_low'
    
    container 'us.gcr.io/mccarroll-mocha/sc_dbl_finder:20260326'

    input:
    path dge
    val random_seed

    output:
    path "$output_file", emit: doubletCalls

    script:
    output_file = replaceExtension(dge, "digital_expression.txt.gz", "scDblFinder.tsv")
    the_seed = (random_seed.size == 0? 1234: random_seed[0])

    """
    #!/usr/bin/env Rscript

    suppressPackageStartupMessages({
        library(Matrix)
        library(SingleCellExperiment)
        library(scDblFinder)
    })
    # I can't figure out how to get data.table::fread to skip comments, so doing it the old-fashioned way
    dge <- read.table("${dge}", header = TRUE, comment.char = '#', sep='\t')
    gene_names <- dge\$GENE
    dge = subset(dge, select=-GENE)

    dge <- as.matrix(dge)
    dge <- as(dge, "sparseMatrix")

    rownames(dge) <- gene_names

    set.seed(${the_seed})
    sce <- SingleCellExperiment(assays = list(counts = dge))

    message("Running scDblFinder...")

    sce <- scDblFinder(sce)
    df <- data.frame(
        cell_barcode = colnames(sce),
        doublet = sce\$scDblFinder.class,
        scDblFinder_score = sce\$scDblFinder.score,
        stringsAsFactors = FALSE
    )
    write.table(df, file="${output_file}", quote=FALSE, sep='\t', row.names=FALSE, col.names=TRUE)
    message("scDblFinder done")
    """
}