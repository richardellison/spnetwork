#' @import methods sp igraph
#' @importFrom stats weights

#  @exportClass igraph
setClass("igraph") # S4

#' The SpatialNetwork class and constructor function
#'
#' SpatialNetwork: a Class for Spatial Networks (lines and edges)
#'
#' A class to store spatial networks, such as a road network.
#'
#'@section Slots: 
#'  \describe{
#'    \item{\code{bbox}}{matrix, holding bounding box}
#'    \item{\code{proj4string}}{object of class \link[sp]{CRS-class}}
#'    \item{\code{lines}}{list}
#'    \item{\code{data}}{data.frame, holding attributes associated with lines}
#'    \item{\code{g}}{object of a subclass of \link[igraph]{igraph}}
#'    \item{\code{weightfield}}{character; describing the weight field used}
#'  }
#'
#' @usage SpatialNetwork(sl, g, weights, weightfield)
#' @param sl object of one of (a sublasses of) \link{SpatialLines}
#' @param g object of class \link{igraph} 
#' @param weights weight for edges (defaults to length of linestring)
#' @param weightfield character; name of the attribute field of \code{sl} that will be used as weights
#' @return object of class \link{SpatialNetwork-class}

#' @name SpatialNetwork-class
#' @rdname SpatialNetwork-class
#' @aliases SpatialNetwork SpatialNetwork-class [[,SpatialNetwork,ANY,missing-method [[<-,SpatialNetwork,ANY,missing-method $,SpatialNetwork-method
#' @exportClass SpatialNetwork
#' @author Edzer Pebesma
#' @note note
#'
#' @examples
#' library(sp) # Lines, SpatialLines
#' l0 = cbind(c(1, 2), c(0, 0))
#' l1 = cbind(c(0, 0, 0), c(0, 1, 2))
#' l2 = cbind(c(0, 0, 0), c(2, 3, 4))
#' l3 = cbind(c(0, 1, 2), c(2, 2, 3))
#' l4 = cbind(c(0, 1, 2), c(4, 4, 3))
#' l5 = cbind(c(2, 2), c(0, 3))
#' l6 = cbind(c(2, 3), c(3, 4))
#' LL = function(l, ID) Lines(list(Line(l)), ID)
#' l = list(LL(l0, "e"), LL(l1, "a"), LL(l2, "b"), LL(l3, "c"), LL(l4, "d"), LL(l5, "f"), LL(l6, "g"))
#' sl = SpatialLines(l)
#' sln = SpatialNetwork(sl)
#' plot(sln)
#' points(sln)
#' library(igraph) # E
#' text(V(sln@g)$x, V(sln@g)$y, E(sln@g), pos = 4)
#' plot(sln@g)
setClass("SpatialNetwork",
	contains = "SpatialLinesDataFrame", 
	slots = c(g = "igraph", weightfield = "character"),
    validity = function(object) {
		# print("Entering validation: SpatialNetwork")
		if (any(sapply(object@lines, function(x) length(x@Lines)) != 1))
			stop("all Lines objects need to have a single Line") 
    	if (length(object@lines) != length(E(object@g)))
			stop("edges do not match number line segments") 
		return(TRUE)
	}
)

#' @export
SpatialNetwork = function(sl, g, weights, weightfield) {
    stopifnot(is(sl, "SpatialLines"))
    if (!is(sl, "SpatialLinesDataFrame")) 
        sl = new("SpatialLinesDataFrame", sl, data = data.frame(id = 1:length(sl)))
    if (!all(sapply(sl@lines, function(x) length(x@Lines)) == 1)) 
        stop("SpatialLines is not simple: each Lines element should have only a single Line")
	if (missing(g)) { # sort out from sl
    	startEndPoints = function(x) {
        	firstLast = function(L) {
            	cc = coordinates(L)[[1]]
            	rbind(cc[1, ], cc[nrow(cc), ])
        	}
        	do.call(rbind, lapply(x@lines, firstLast))
    	}
    	s = startEndPoints(sl)
    	zd = zerodist(SpatialPoints(s))
    	pts = 1:nrow(s)
	
    	# the following can't be done vector-wise, there is a progressive effect:
    	if (nrow(zd) > 0) {
        	for (i in 1:nrow(zd)) 
				pts[zd[i, 2]] = pts[zd[i, 1]]
    	}
    	stopifnot(identical(s, s[pts, ]))
	
    	# map to 1:length(unique(pts))
    	pts0 = match(pts, unique(pts))
    	node = rep(1:length(sl), each = 2)
    	g = graph(pts0, directed = FALSE)  # edges
    	# nb = lapply(1:length(unique(pts)), function(x) node[which(pts0 == x)])
		# nb = lapply(as.list(incident_edges(g, V(g))), as.numeric) # dropped as slot
    	nodes = s[unique(pts), ]
    	V(g)$x = nodes[, 1]  # x-coordinate vertex
    	V(g)$y = nodes[, 2]  # y-coordinate vertex
    	V(g)$n = as.vector(table(pts0))  # nr of edges
    	# line lengths:
    	sl$length = SpatialLinesLengths(sl) # takes care of projected
    	if (!missing(weights)) {
    	    if (missing(weightfield)) {
    	        weightfield = 'weight'
    	    }
	        sl@data[, weightfield] <- weights
    	} else
    	    weightfield = 'length'
        E(g)$weight = sl@data[, weightfield]
        
    	# create list with vertices, starting/stopping for each edge?  add for
    	# each SpatialLines, the start and stop vertex
    	pts2 = matrix(pts0, ncol = 2, byrow = TRUE)
    	sl$start = pts2[, 1]
    	sl$end = pts2[, 2]
	}
	if (!missing(weights)) {
	    if (missing(weightfield))
	        weightfield = 'weight'
        sl@data[, weightfield] <- weights
    	E(g)$weight = weights
	}
    new("SpatialNetwork", sl, g = g, weightfield = weightfield)
}
