% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/contour_interpolator.R
\name{edge_source_interpolator}
\alias{edge_source_interpolator}
\title{Interpolate inside a region defined by 2 downdip lines}
\usage{
edge_source_interpolator(xy, edge1, edge2)
}
\arguments{
\item{xy}{matrix of xy coordinates ('n' rows, 2 columns)}

\item{edge1}{matrix of x,y,z coordinates.}

\item{edge2}{matrix of x,y,z coordinates.}
}
\value{
xyz coordinates interpolated at xy. Note that x,y should be the same
as the input x,y (we return them anyway for debugging/testing purposes)
}
\description{
Interpolate inside a region defined by 2 downdip lines (x,y,z coordinates)
based on a given set of xy coordinates
}
