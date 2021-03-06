% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rupture_scaling.R
\name{Mw_2_rupture_size}
\alias{Mw_2_rupture_size}
\title{Compute earthquake rupture area, width and length from Mw based on an
empirical scaling relation}
\usage{
Mw_2_rupture_size(Mw, relation = "Strasser", detailed = FALSE,
  CI_sd = 1)
}
\arguments{
\item{Mw}{Moment Magnitude (must have length(Mw) == 1)}

\item{relation}{Name for the scaling relation. 'Strasser' (default) uses the subduction
interface event relation for Strasser et al 2010; 'Strasser-intraslab' uses the
subduction intraslab relations of Strasser et al 2010 [for this case, 
Strasser et al 2010 suggest the width sigma might be too small, but we make
no effort to correct that]; 'AllenHayes' uses the interface relations of
Allen and Hayes (2017, Table 2), with sigma for prediction based on the sigma value
for the log10(L / or W / or A) of the orthogonal regression. Note this case 
has Area and Width being multi-segment linear, and we slightly modify the mw thresholds
in the paper to exactly agree with the line segment intersections; 'AllenHayes-inslab' gives the 
inslab relations of Allen and Hayes (2017, Table 5); 'AllenHayes-outer-rise' gives the outer-rise
relations of Allen and Hayes (2017, Table 5); 'Blaser-normal' gives the normal relations of Blaser
et al (2010). Note these authors didn't give area relations, so herein the area coefficients are
derived assuming area = length x width, and zero correlation of the length and width residuals.; 
'Thingbaijam-subduction' gives the subduction relations of Thingbaijam et al. (2017); 'Thingbaijam-normal'
gives the normal fault scaling relations from Thingbaijam et al. (2017);}

\item{detailed}{logical. If False return a vector with area/width/length,
otherwise provide a list with the latter as well as information on
log10-standard-deviations}

\item{CI_sd}{Logical. If detailed = TRUE, the output includes a positive
and negative confidence interval threshold, both of which are CI_sd
standard deviations away from the mean (in log space where the regression is
computed)}
}
\value{
A numeric vector with the area/width/length (if detailed = FALSE), otherwise
a list with the rupture size statistics as well as upper and lower bounds
for a confidence interval, and information on the log10 standard deviation
of each variable (which can be used to compute any other confidence interval).
}
\description{
Output units are km and km^2
}
\examples{
# Using the Strasser et al subduction scaling relation by default
rupture_statistics1 = Mw_2_rupture_size(9.0)
rupture_statistics2 = Mw_2_rupture_size(9.0, detailed=TRUE)
# Try Allen and Hayes relation
rupture_statistics3 = Mw_2_rupture_size(9.0, relation='AllenHayes', 
    detailed=TRUE, CI_sd=2)
}
