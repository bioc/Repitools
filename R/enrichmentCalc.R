setGeneric("enrichmentCalc", function(x, ...) standardGeneric("enrichmentCalc"))

setMethod("enrichmentCalc", "GRangesList",
    function(x, verbose = TRUE, ...)
{
    samp.names <- if(is.null(names(x))) 1:length(x) else names(x)
    ans <- lapply(1:length(x), function(i)
        {
            if(verbose)
                message("Calculating enrichment in ", samp.names[i], '.')
            enrichmentCalc(x[[i]], verbose, ...)
        })
    ans
})

setMethod("enrichmentCalc", "GRanges",
    function(x, seq.len = NULL, verbose = TRUE)
{
    if(any(is.na(seqlengths(x))))
        stop("Some chromosome lengths missing in Seqinfo of reads.")
    if(!is.null(seq.len))
    {
        if(verbose) message("Resizing sample reads to fragment length.")
        x <- suppressWarnings(resize(x, seq.len))
    }
    if(verbose) message("Getting coverage.")
    cv <- coverage(x)
    mx <- max(max(cv))
    tbs <- lapply(cv, table)
    ct <- data.frame(coverage=0:mx, bases=0)
    if(verbose) message("Tabulating coverage.")
    for(i in 1:length(tbs)) {
          m <- match(names(tbs[[i]]), ct$coverage)
          ct$bases[m] <- ct$bases[m]+tbs[[i]]
    }
    ct <- ct[ct$bases>0,]
    ct
})
