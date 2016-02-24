maskOut <- function(x, ranges){

    if(class(ranges) != "GRanges"){
        stop("ranges must be of class GRanges")
    }

    fo <- findOverlaps(ranges, windows(x))

    mask <- logical(length(x))
    mask[subjectHits(fo)] <- TRUE

    maskEmpBayes(x) <- mask
    return(x)
}
