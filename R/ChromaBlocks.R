
setGeneric("ChromaBlocks", function(rs.ip, rs.input, ...){standardGeneric("ChromaBlocks")})

# attribution: following function is used from the old Ringo package
# https://www.bioconductor.org/packages/release/bioc/src/contrib/Ringo_1.66.0.tar.gz
.sliding.meansd <- function(positions, scores, half.width) {
  stopifnot(!is.unsorted(positions), length(positions) == length(scores), half.width >= 0)
  res <- .Call(.ringoMovingMeanSd, as.integer(positions), as.numeric(scores), as.integer(half.width))
  colnames(res) <- c("mean","sd","count")
  rownames(res) <- positions
  return(res)
}#sliding.meansd

setMethod("ChromaBlocks", c("GRangesList", "GRangesList"), function(rs.ip, rs.input, organism, chrs, ipWidth=100, inputWidth=500, preset=NULL, blockWidth=NULL, minBlocks=NULL, extend=NULL, cutoff=NULL, FDR=0.01, nPermutations=5, nCutoffs=20, cutoffQuantile=0.98, verbose=TRUE, seq.len=NULL) {

    .mergeOverlaps <- function (query, subject) {
        ov <- as.matrix(findOverlaps(query, subject, select="all"))
        query.ov <- unique(ov[,1])
        subjectStarts <- tapply(ov[,2], ov[,1], function(x) min(start(subject[x])))
        subjectEnds <- tapply(ov[,2], ov[,1], function(x) max(end(subject[x])))
        start(query)[query.ov] <- ifelse(start(query[query.ov])>subjectStarts, subjectStarts, start(query[query.ov]))
        end(query)[query.ov] <- ifelse(end(query[query.ov])<subjectEnds, subjectEnds, end(query[query.ov]))
        query
    }
    
    .callRegions <- function(bins, RPKM=NULL, cutoffs, blockWidth, ipWidth, minBlocks) {
        callCutoff <- function(dat, cutoff) {
            dat$cutoff <- .sliding.meansd(dat$position, as.integer(dat$RPKM>=cutoff), ipWidth*blockWidth/2)[,"mean"]>=minBlocks/blockWidth
            temp <- dat$mean>cutoff&dat$cutoff
            #clean the ends of the chromosomes
            temp[c(1:(blockWidth/2), (length(temp)-(blockWidth/2)):length(temp))] <- FALSE
            #Expand the regions out to the ends
            toExtend <- which(temp)
            for (i in -(blockWidth/2):(blockWidth/2)) temp[toExtend+i] <- TRUE
            tempRle <- Rle(temp)
            tempStarts <- start(tempRle)[runValue(tempRle)==TRUE]
            tempEnds <- end(tempRle)[runValue(tempRle)==TRUE]
            if (!is.null(extend)){
                extendRle <- Rle(dat$extend)
                extendRanges <- IRanges(dat$position[start(extendRle)[runValue(extendRle)==TRUE]], dat$position[end(extendRle)[runValue(extendRle)==TRUE]])
                .mergeOverlaps(IRanges(dat$position[tempStarts], dat$position[tempEnds]), extendRanges)
            } else IRanges(dat$position[tempStarts], dat$position[tempEnds])
        }
        
        callChr <- function(dat) {
            if (verbose) cat(".")
            dat$mean <- .sliding.meansd(dat$position, dat$RPKM, ipWidth*blockWidth/2)[,"mean"]
            if (!is.null(extend)) dat$extend <- dat$mean<extend 
            if (length(cutoffs)>1) sapply(cutoffs, function(x) callCutoff(dat, x)) else callCutoff(dat, cutoffs)
        }
        
        RPKM.split <- split(data.frame(position=(start(bins)+end(bins))/2, RPKM=if (is.null(RPKM)) values(bins)$RPKM else RPKM), as.character(seqnames(bins)))
        regions <- lapply(RPKM.split, callChr)
        if (verbose) cat("\n")
        if (length(cutoffs)>1) rowSums(sapply(regions, function(x) sapply(x,length))) else as(regions, "IRangesList")
    }

    
    if (is.null(preset)) {
        stopifnot(!is.null(blockWidth), !is.null(minBlocks))
    } else if (preset=="small") {
        blockWidth=10
        minBlocks=5
    } else if (preset=="large") {
        blockWidth=50
        minBlocks=25
        extend=0.1
    } 
    if (verbose) message("Creating bins")
    IPbins <- genomeBlocks(organism, chrs, ipWidth)
    InputBins <- genomeBlocks(organism, chrs, inputWidth, ipWidth)
    if (verbose) message("Counting IP lanes")
    force(rs.ip)
    force(rs.input)
    ipCounts <- annotationBlocksCounts(rs.ip, IPbins, seq.len=seq.len, verbose=verbose)
    #pool & normalise IP lanes & turn into RPKM - reads per kb (ipWidth/1000) per million (/lanecounts*1000000)
    ipCounts <- rowSums(ipCounts)/sum(elementNROWS(rs.ip))*1000000/(ipWidth/1000)
    
    if (verbose) message("Counting Input lanes")
    inputCounts <- annotationBlocksCounts(rs.input, InputBins, seq.len=seq.len, verbose=verbose)
    #pool & normalise Input lanes
    inputCounts <- rowSums(inputCounts)/sum(elementNROWS(rs.input))*1000000/(inputWidth/1000)
    
    values(IPbins)$RPKM <- ipCounts-inputCounts
    rm(ipCounts, inputCounts)
    #scale RPMK to have mean==0
    values(IPbins)$RPKM <- values(IPbins)$RPKM-mean(values(IPbins)$RPKM)
    #okay find regions
    if (is.null(cutoff)) {
        cutoffs <- seq(0.1, quantile(values(IPbins)$RPKM, cutoffQuantile), length.out=nCutoffs)
        negRegions <- sapply(1:nPermutations, function(u) {
            if (verbose) cat("Permutation",u)
            .callRegions(IPbins, values(IPbins)$RPKM[sample(length(IPbins))], cutoffs=cutoffs, blockWidth = blockWidth, ipWidth = ipWidth, minBlocks = minBlocks)
        })
        if (verbose) cat("Testing positive regions")
        posRegions <- .callRegions(IPbins, cutoffs=cutoffs, blockWidth = blockWidth, ipWidth = ipWidth, minBlocks = minBlocks)
        FDRTable <- cbind(cutoffs=cutoffs, pos=posRegions, negRegions, FDR=rowMeans(negRegions)/posRegions)
        cutoff <- cutoffs[match(TRUE, FDRTable[,"FDR"]<FDR)]
        if (is.na(cutoff)) {
            warning("No cutoff below FDR", FDR, "found! Analysis halted! Try increasing cutoffQuantile or FDR")
            return(list(data=IPbins, FDRTable=FDRTable))
        }
        if (verbose) cat("Using cutoff of",cutoff,"for a FDR of",FDR,"\n")
    } else {
        if (verbose) cat("Using supplied cutoff of",cutoff,"\n")
        FDRTable <- NULL
    }
    new("ChromaResults", blocks=IPbins, regions=.callRegions(IPbins, cutoffs=cutoff, blockWidth = blockWidth, ipWidth = ipWidth, minBlocks = minBlocks), FDRTable=FDRTable, cutoff=cutoff)
})

