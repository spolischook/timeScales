% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/arEigs.R
\name{diagExtend}
\alias{diagExtend}
\title{Extend Diagonal}
\usage{
diagExtend(size, offset = -1)
}
\arguments{
\item{size}{scalar, size of matrix (nrow, nrow=ncol)}

\item{offset}{scalar, -1 puts 1's one row below diagonal, 1 puts 1's one row above diagonal, -2 two rows below, etc}
}
\value{
a matrix with 1's on the 'offset' of the diagonal, 0's everywhere else
}
\description{
Place 1's on diagonal, or on superdiagonal 'offset' rows above diagonal
}

