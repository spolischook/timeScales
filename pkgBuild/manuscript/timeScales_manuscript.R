#' ---
#' title: "The time scale of resilience loss: the effect of sampling frequency on an early warning statistic"
#' author: "Ryan Batt"
#' date: "2017-10-17"
#' abstract: |
#'        Many complex systems show abrupt shifts, even when changes drivers change smoothly. Such changes are often referred to as regime shifts, and can be caused by critical transitions. These regime shifts can be very difficult to predict using mechanistic models. However, prior to a critical transition, complex systems may exhibit critical slowing down, a dynamical phenomenon characteristic of a system losing resilience prior to a critical transition. Statistical indicators for detecting the loss of resilience are being developed as a possible tool for predicting regime shifts involving critical transitions. However, these indicators can be sensitive to the observation frequency of the system. Researchers have often relied on expert judgement and intuition for selecting reasonable sampling frequencies for data analysis. However, the issue has not been systematically evaluated for all indicators, especially those based on autocorrelation. Furthermore, modern sensor technologies provide numerous options for sampling frequencies. The potential influence on sampling frequency on statistical indicators, coupled with the availability of high frequency data, presents a problem for the study and application of statistical indicators of resilience loss for researchers and managers alike. Here we analyze the sensitivity of autocorrelation, a statistical indicator of resilience, in a lake undergoing a critical transition. We evaluate how sampling frequency affects the value of this statistic, its use as an early warning indicator, and propose a general method for selecting an appropriate sampling frequency in other systems.
#' output:
#'   html_document:
#'     toc: true
#'     toc_depth: 4
#'     fig_caption: true
#'     theme: "readable"
#'     template: default
#'   pdf_document:
#'     toc: true
#'     toc_depth: 4
#'     template: latex-ryan.template
#'     fig_caption: yes
#' geometry: margin=1.0in
#' lineno: true
#' lineSpacing: false
#' titlesec: true
#' documentclass: article
#' placeins: true
#' ---


#+ setup, include=FALSE, echo=FALSE
# =================
# = Load Packages =
# =================
library("data.table")
library("zoo")
library("forecast")
library("timeScales")

# Report
library(knitr)
library(rmarkdown)


# ================
# = Report Setup =
# ================
doc_type <- c("html", "pdf")[1]
table_type <- c("html"="html", "pdf"="latex")[doc_type]
options("digits"=3) # rounding output to 4 in kable() (non-regression tables)
o_f <- paste(doc_type, "document", sep="_")

# problem with pdflatex in El Capitan? It might be directories. Check http://pages.uoregon.edu/koch/FixLink.pkg

# render!
# rmarkdown::render(
# 	"~/Documents/School&Work/epaPost/timeScales/pkgBuild/manuscript/timeScales_manuscript.R",
# 	output_format=o_f,
# 	output_dir='~/Documents/School&Work/epaPost/timeScales/pkgBuild/manuscript',
# 	clean = TRUE
# )

Sys.setenv(PATH=paste0("/Library/TeX/texbin:",Sys.getenv("PATH")))
opts_chunk$set(
	fig.path = 'timeScales_manuscript/', 
	cache.path='timeScales_manuscript/',
	echo=TRUE, 
	include=TRUE, 
	cache=F,
	autodep=TRUE,
	results='asis',
	warning=FALSE,
	fig.show="hold",
	fig.lp = if(o_f=="html_document"){"**Figure.**"}else{NULL}
)


#' #Options
#+ options
win_days <- 28 # window size in days covered
agg_steps <- c(1, 12, 288, 288*2) # step sizes for aggregation
lakes <- c("Peter","Paul") # can be vector; lakes to analyze (Paul, Peter)
vars <- "chla" #"bga" # can be vector; variables to analyze (wtr, bga, chla)


steps_per_day <- 60*24/(5 * agg_steps) # obs per day = (60 min / 1 hr) * (24 hrs / 1 day) * (1 obs / 5*n min)
steps_per_window <- steps_per_day*win_days # steps per window = (n steps / 1 day) * (n days / 1 window)
acf_lag.max <- steps_per_window[1]/14 # 2 days is /14
window_by <- pmax(1, steps_per_day/(4)) # the denominator is number of window starts per day; if trying to increment window by less than the resolution of the time series, just increment by 1 #c(48, 4, 2, 1)


#'   
#' \FloatBarrier  
#'   
#' ***  
#'   


#' #Data Prep
#' ##Subset, Restructure, Define as ts Object
#+ data-prep-basic
#      drop tuesday lake ----
sos <- sos_data[Lake!="Tuesday"]

#      shorter names ----
setnames(sos, 
	old=c("Year", "Lake", "DoY", "DateTime", "Temp_HYLB", "Chla_Conc_HYLB", "BGA_Conc_HYLB"),
	new=c("year","lake","doy","datetime","wtr","chla","bga")
)

#      ensure numeric, re-structure data set ----
sos[,bga:=as.numeric(bga)]
sosm <- melt(sos, id.vars=c("year","lake","doy","datetime"))[variable%in%vars & lake%in%lakes]

#      make measured values of class "ts" with frequency = 288 samples per day ----
set_ts <- function(y, x, freq=288){
	ts(y, freq=freq, start=x)
}
sosm[, value:=set_ts(y=log(value), x=doy[1]), by=c("year","lake","variable")]

#      grab range limits (primarily for plotting) ----
doy_range <- sos[,range(doy, na.rm=TRUE)]
chla_range <- sos[,range(chla, na.rm=TRUE)]

#' ##Aggregate Data for Typical Rolling Window Calculation
#+ data-prep-aggregation
agg_sos <- function(aggsteps){
	out <- sosm[,j={agg_ts(y=value, x=doy, width=aggsteps)},by=c("lake","variable")]
	out
}
sos_agg <- lapply(agg_steps, agg_sos)
names(sos_agg) <- paste0("agg", agg_steps)
#'   
#' \FloatBarrier  
#'   
#' ***  
#'   


#'  #Chlorophyll Time Series for each Lake
#' Paul Lake is an unmanipulated, reference lake. Peter was being fertilized with nitrogen and phosphorphus every day. The goal was to create a critical transition in Peter Lake (Hopf birfurcation).  
#'   
#' Around day 180, Peter Lake has a blue-green algal bloom. Maximum BGA in Peter is ~4x's higher than maximum BGA in Paul Lake.  
#'   
#' ##Figure: Time Series
#+ chla-timeSeries-figure, fig.width=3, fig.height=5, fig.cap="**Figure.** High frequency chlorophyll (chla, micrograms per liter) time series in Peter (red) and Paul (blue) lakes in 2015.", results='hide'
par(mfcol=c(2,1), mar=c(2, 2.0, 1, 0.25), mgp=c(1, 0.25, 0), tcl=-0.15, ps=8, cex=1)
sosm[lake=="Paul" & variable==vars, plot(doy, exp(value), xlim=doy_range, col="black", type='l', xlab="", ylab=c("chla"="Chlorophyll", "bga"="Phycocyanin")[vars])]
mtext("Paul Lake (Reference)", side=3, line=-0.1, adj=0.05, font=2)
sosm[lake=="Peter" & variable==vars, plot(doy, exp(value), xlim=doy_range, col="black", type='l', xlab="Day of year", ylab=c("chla"="Chlorophyll", "bga"="Phycocyanin")[vars])]
mtext("Peter Lake (Manipulated)", side=3, line=-0.1, adj=0.05, font=2)
#'   
#'   
#' \FloatBarrier  
#'   
#' ***  
#'   


#' #ACF Plots for Chla in each Lake
#+ functions-plotting
plot_acf <- function(ln=c("Paul","Peter"), v=c("chla", "bga"), na.action=na.exclude, lag.max=288*12, ...){
	ln <- match.arg(ln)
	v <- match.arg(v)
	dots <- list(...)
	if(is.null(dots$main)){main <- paste(ln, v, 'acf')}else{main <- dots$main}
	d <- sos[lake==ln, get(v)]
	acf2 <- function(..., main=main){acf(...)}
	o <- acf2(d, lag.max=lag.max, na.action=na.action, ...)
	mtext(main, side=3, line=0.1, font=2)
	invisible(NULL)
}
#+ chlorophyll-acf-figure, fig.width=3, fig.height=5, fig.cap="**Figure.** Autocorrelation function (ACF) of chlorophyll a (indicator of algal biomass) from Peter Lake (manipulated) and Paul Lake (reference).", results='hide'
par(mfrow=c(2,1), mar=c(2, 2.0, 0.25, 0.25), mgp=c(1, 0.25, 0), tcl=-0.15, ps=8, cex=1)
plot_acf(v=vars, ylab=paste0("Paul Lake", c("chla"="Chlorophyll", "bga"=" Phycocyanin")[vars], " ACF"), main="")
plot_acf(ln='Peter', v=vars, ylab=paste0("Peter Lake", c("chla"="Chlorophyll", "bga"=" Phycocyanin")[vars], " ACF"), main="")
#' Autocorrelation is time scale dependent in both the manipulated and the reference lake.  
#'   

#' #Rolling Window Autocorrelation for Select Time Scales
#+ rollingWindowAC-calculation, cache=FALSE
AC_list <- roll_ac.sos(sos_agg, window_elapsed=steps_per_window, vars=vars, lakes=lakes, DETREND=TRUE, by=window_by)

#+ rollingWindowAC-PaulPeterDifference, fig.width=6, fig.height=6, fig.cap="**Figure.** Rolling windows of first-order autocorrelation from detrended chlorophyll time series. Blue lines are from Paul Lake (reference), red lines are Peter Lake (manipulated). In the second column, the black lines represent the difference (Peter - Paul) between the lines in the first column (positive values indicate that autocorrelation was higher in Peter than in Paul). Each row of the figure has a different sampling frequency."
plotac <- function(X, ...){
	X <- copy(X)
	ylim <- X[,range(y, na.rm=TRUE)]
	
	ydiff <- X[lake=="Peter", y] - X[lake=="Paul", y]
	zdiff <- data.table(lake="zdiff", variable=X[,variable[1]], x=X[lake==lake[1], x], y=ydiff)
	X <- rbind(X, zdiff)
	
	ul <- X[,unique(lake)]
	for(l in 1:length(ul)){
		dud <- X[lake==ul[l],j={
			tcol <- c("Paul"="blue","Peter"="red", "zdiff"="black")[lake[1]]
			if(lake[1]=="Paul"){
				plot(x,y, type='l', col=tcol, ylim=ylim, ...)
			}else if(lake[1]=="Peter"){
				lines(x, y, col=tcol)
			} else if(lake[1]=="zdiff"){
				p2 <- function(..., ylab, ylab2="") plot(..., ylab=ylab2)
				p2(x,y, type='l', col=tcol, ...)
			}
		
			NULL
		}]
	}
	
	invisible()
}

ylabs <- paste0(c("chla"="Chl-a", "bga"="Phyco")[vars], " AR(1) (", sapply(agg_steps, interval_name), ")")

xlabs <- rep("", length(agg_steps))
xlabs[length(agg_steps)] <- "Day of Year"

par(mfrow=c(length(agg_steps),2), mar=c(2,2,0.5,0.5), cex=1, tcl=-0.15, mgp=c(1,0.2,0), ps=8)
invisible(mapply(plotac, X=AC_list, ylab=ylabs, xlab=xlabs))

#' #ACF Heat Map
#' ##Functions
#+ acf-map-functions
acf_map <- function(out, ...){
	obs_lab <- attr(out, "xlab")
	lag_lab <- attr(out, "ylab")
	rwbCols <- colorRampPalette(c("blue","white","red"))(256) 
	image(x=obs_lab, y=lag_lab[-1], z=out[,2:ncol(out)], col=rwbCols, ...)
	invisible(NULL)
}

add_legend <- function(out, legend.mar=2, col, axis.args){
	if(missing(col)){
		col <- colorRampPalette(c("blue","white","red"))(256)
	}
	if(missing(axis.args)){
		axis.args <- list(mgp=c(0.5, 0.15, 0), tcl=-0.1)
	}
	fields::image.plot(out, legend.only=TRUE, col=col, legend.mar=legend.mar, axis.args=axis.args)
}

add_axis <- function(out){
	map_colors <- colorRampPalette(c("blue","white","red"))(256)
	ylab_pretty <- pretty(attr(out, "ylab")/288)
	ylab_pretty[1] <- 1/288 #attr(out_L_sub, "ylab")[3]/288
	ylab_names <- sapply(ylab_pretty, interval_name, minPerSample=1440) #interval_name(attr(out_L_sub, "ylab"))
	axis(side=2, at=ylab_pretty*288, labels=ylab_names)
	invisible()
}

sub_out <- function(out, ind=list(1,1), type=c("sub", "thin")){
	type <- match.arg(type)
	xlab <- attr(out, "xlab")
	ylab <- attr(out, "ylab")
	nr <- nrow(out)
	nc <- ncol(out)
	if(type=="thin"){
		rVec <- ((1:nr)%%ind[[1]])==0
		cVec <- ((1:nc)%%ind[[2]])==0
	}
	if(type=="sub"){
		rVec <- ind[[1]]
		cVec <- ind[[2]]
	}
	out2 <- out[rVec, cVec]
	attr(out2, "xlab") <- xlab[rVec]
	attr(out2, "ylab") <- ylab[cVec]
	return(out2)
}

#' ##Calculate ACF Map
#+ acf-map-calculate, cache=FALSE
out_L <- acf_roll(x=sosm[lake=="Paul" & variable==vars, value], width=steps_per_window[1], by=window_by[1], lag.max=acf_lag.max, DETREND=TRUE)
out_R <- acf_roll(x=sosm[lake=="Peter" & variable==vars, value], width=steps_per_window[1], by=window_by[1], lag.max=acf_lag.max, DETREND=TRUE)

#' ##Figure: Full ACF Heat Map
#+ acf-map-full-figure, fig.width=3, fig.height=6, fig.cap="**Figure** Autocorrelation at a across many time scales, using the ACF function. Each window is detrended first.", fig.show='hide', include=FALSE
# #      Thin-out for Fast/ Lighter Plotting ----
# out_L_sub <- sub_out(out_L, ind=list(r=8, c=4), type='thin')
# out_R_sub <- sub_out(out_R, ind=list(r=8, c=4), type='thin')
# out_Diff_sub <- out_R_sub - out_L_sub
#
# #      Begin Plotting ----
# xlimL <- c(min(attr(out_L_sub, "xlab")), 240)
# xlimR <- c(min(attr(out_R_sub, "xlab")), 240)
#
# par(mfrow=c(3,1))
# par(mar=c(2,2,1,3), mgp=c(1,0.2,0), tcl=-0.15, ps=8, cex=1)
# acf_map(out_L_sub, xlab="", ylab="Time scale", main="Paul Lake (reference)", xlim=xlimL, yaxt='n')
# add_axis(out_L_sub)
# add_legend(out_L_sub)
#
# par(cex=1)
# acf_map(out_R_sub, xlab="", ylab="Time scale", main="Peter Lake (manipulated)", xlim=xlimR, yaxt='n')
# add_axis(out_R_sub)
# add_legend(out_R_sub)
#
# par(cex=1)
# acf_map(out_Diff_sub, xlab="Day of year", ylab="Time scale", main="Difference", xlim=xlimR, yaxt='n')
# add_axis(out_Diff_sub)
# add_legend(out_Diff_sub)
#'   
#' \FloatBarrier  
#'   
#' ***  
#'   

#' ##Figure: Subset ACF Heat Map
#+ acf-map-subset-figure, fig.width=3, fig.height=6, fig.cap="**Figure** Autocorrelation at a across many time scales, using the ACF function. Each window is detrended first. Subset of full data set (zoom on high frequencies and early part of the time series)."
#      Subset to Zoom in on Relevant Bits ----
rInd <- attr(out_L, "xlab") <= 190
cInd <- attr(out_L, "ylab") <= 144
out_L_sub2 <- sub_out(out_L, ind=list(r=rInd, c=cInd), type='sub')
out_R_sub2 <- sub_out(out_R, ind=list(r=rInd, c=cInd), type='sub')
out_Diff_sub2 <- out_R_sub2 - out_L_sub2

#      Begin Plotting ----
par(mfrow=c(3,1))
par(mar=c(2,2,1,3), mgp=c(1,0.2,0), tcl=-0.15, ps=8, cex=1)
acf_map(out_L_sub2, xlab="", ylab="Time scale", main="Paul Lake (reference)", yaxt='n', zlim=range(out_L_sub2))
add_axis(out_L_sub2)
add_legend(out_L_sub2)

par(cex=1)
acf_map(out_R_sub2, xlab="", ylab="Time scale", main="Peter Lake (manipulated)", yaxt='n', zlim=range(out_R_sub2))
add_axis(out_R_sub2)
add_legend(out_R_sub2)

par(cex=1)
acf_map(out_Diff_sub2, xlab="Day of year", ylab="Time scale", main="Difference", yaxt='n', zlim=range(out_Diff_sub2))
add_axis(out_Diff_sub2)
add_legend(out_Diff_sub2)
#'   
#' \FloatBarrier  
#'   
#' ***  
#'   

#' ##Figure: Full ACF Heat Map w/ Time Series Insets
#+ acf-map-full-tsInsets-figure, fig.width=6, fig.height=6, fig.cap="**Figure** Autocorrelation at a across many time scales, using the ACF function. Each window is detrended first. Time series in the insets represent subsets of the full heat map at specific time scales."
#      Setup Layout Matrix ----
nMain <- 3 # the number of heat map panels
ts_choices <- c(1, 12*6, 12*24, 12*48)
nScales <- length(ts_choices)
widthFac <- 3 # how much wider the heat maps are relative to the time series
pExpand <- 6 # number of times (*) to expand each time series panel
bExpand <- 1 # number of buffer panels to add above and below each set of nScales time series panels
panelVec <- rep(rep((1:nMain),each=nScales*pExpand+2*bExpand),widthFac)
tsBase <- seq(4, by=nMain, length.out=nScales)+rep(0:2, each=nScales)
tsPos <- rep(tsBase, each=pExpand)
buffer_mat <- matrix(rep(0, nMain*bExpand),ncol=nMain)
ts_buffer_mat <- rbind(buffer_mat, matrix(tsPos, ncol=nMain), buffer_mat)
lay_mat <- matrix(c(c(ts_buffer_mat), panelVec), ncol=widthFac+1)

#      Add Legend -- Custom Function ----
add_legend2 <- function(inputDat){
	mapLegend(x=1.03, y=0.5, w=0.05, h=0.9, zlim=range(inputDat), cols=c("blue","white","red"), horiz=FALSE, axSide=4, lab.cex=1, lab.sig=2, offset=0.2, xpd=TRUE)
}
add_panel_lab_main <- function(let){mtext(let, side=3, line=-0.85, adj=0.01, font=2, cex=1.2)}

#      Plot Heat Maps ----
layout(lay_mat)
par(mar=c(1.5,2,1,3), oma=c(0.5,0,0,0), mgp=c(1,0.2,0), tcl=-0.15, ps=8, cex=1, las=0)
acf_map(out_L, xlab="", ylab="Time scale", main="Paul Lake (reference)", yaxt='n')
add_axis(out_L)
# add_legend(out_L)
zrange <- range(c(range(out_L), range(out_R), range(out_R-out_L)))
add_legend2(out_L)
add_panel_lab_main("A")


par(cex=1)
acf_map(out_R, xlab="", ylab="Time scale", main="Peter Lake (manipulated)", yaxt='n')
add_axis(out_R)
# add_legend(out_R)
add_legend2(out_R)
add_panel_lab_main(LETTERS[1+(nScales+1)])

par(cex=1)
out_Diff <- out_R - out_L
acf_map(out_Diff, xlab="", ylab="Time scale", main="Difference (manipulated - reference)", yaxt='n', xpd=TRUE)
mtext("Day of year", side=1, line=1, xpd=TRUE)
add_axis(out_Diff)
# add_legend(out_Diff)
add_legend2(out_R - out_L)
add_panel_lab_main(LETTERS[1+(nScales+1)*2])

#      Plot Time Series ----
suppressWarnings({par(mar=c(0.25,1.25,0.1,0.1), mgp=c(1,0.15,0), tcl=0.15, las=1, ps=8)})
xval <- attr(out_L, "xlab")
for(s in nScales:1){ # iterate through time scales more slowly than throw main plots (paul, peter, diff)
	ts_ind <- list(r=1:nrow(out_L), c=ts_choices[s]+1)
	for(i in 1:nMain){ # iterate through main plots more quickly, plotting same time scale for each of paul, peter, diff
		tout <- switch(i, out_L, out_R, (out_R-out_L))
		ts_temp <- c(sub_out(tout, ind=ts_ind, type="sub"))
		plot(xval, ts_temp, xlab="", ylab="", type='l', xaxt='n', yaxt='n')
		axis(side=2, labels=TRUE, at=pretty(ts_temp, n=3), xpd=F)
		suppressWarnings({axis(side=1, labels=(s==1), mgp=c(1,-0.2, 0))})
		mtext(interval_name(ts_choices[s]), side=3, adj=0.98, font=2, line=-0.75)
		revS <- (nScales:1)[s]
		panelLab <- LETTERS[(i-1)*nScales+revS+i] # I appologize to my future self if he needs to understand this. Remember that the plots are created in a very jumbled way due to 1) the layout(), and 2) I go nScales:1 not 1:nScales, and 3) the s loop is outside the i loop [this point interacts with #1, such that I think they cancel each other]. Also, I had to fiddle a bit so I'm not even sure I understand the pattern, so don't be confused by those two points, especially the first, it might not be relevant. The +i at the end is just b/c I want the heat maps to be labeled A, E, and I, such that all the Paul Lake panels can be summarized as A-D, all the Peter Lake panels as E-H, and all the 'difference' panels as I-L.
		mtext(panelLab, side=3, adj=0.04, font=2, line=if(panelLab=='B'){-0.75}else{-0.75}, cex=1)
		# mtext(paste(panelLab, interval_name(ts_choices[s]), sep=", "), side=3, adj=0.99, font=2, line=-0.67)
		# A
	}
}

#'   
#' \FloatBarrier  
#'   
#' ***  
#'   

#+ acf-map-full-tsInsets-figure, fig.width=6, fig.height=6, fig.cap="**Figure** Autocorrelation at a across many time scales, using the ACF function. Each window is detrended first. Time series in the insets represent subsets of the full heat map at specific time scales. Each time scale is standardized, with its mean removed and divded by its standard deviation."
#      Plot Heat Maps ----
layout(lay_mat)
par(mar=c(1.5,2,1,3), oma=c(0.5,0,0,0), mgp=c(1,0.2,0), tcl=-0.15, ps=8, cex=1, las=0)
acf_map(scale(out_L), xlab="", ylab="Time scale", main="Paul Lake (reference)", yaxt='n')
add_axis(scale(out_L))
# add_legend(out_L)
zrange <- range(c(range(scale(out_L)), range(scale(out_R)), range(scale(out_R-out_L))))
add_legend2(scale(out_L))
add_panel_lab_main("A")


par(cex=1)
acf_map(scale(out_R), xlab="", ylab="Time scale", main="Peter Lake (manipulated)", yaxt='n')
add_axis(scale(out_R))
# add_legend(out_R)
add_legend2(scale(out_R))
add_panel_lab_main(LETTERS[1+(nScales+1)])

par(cex=1)
out_Diff <- scale(out_R - out_L)
acf_map(out_Diff, xlab="", ylab="Time scale", main="Difference (manipulated - reference)", yaxt='n', xpd=TRUE)
mtext("Day of year", side=1, line=1, xpd=TRUE)
add_axis(out_Diff)
# add_legend(out_Diff)
add_legend2(scale(out_R - out_L))
add_panel_lab_main(LETTERS[1+(nScales+1)*2])

#      Plot Time Series ----
suppressWarnings({par(mar=c(0.25,1.25,0.1,0.1), mgp=c(1,0.15,0), tcl=0.15, las=1, ps=8)})
xval <- attr(out_L, "xlab")
for(s in nScales:1){ # iterate through time scales more slowly than throw main plots (paul, peter, diff)
	ts_ind <- list(r=1:nrow(out_L), c=ts_choices[s]+1)
	for(i in 1:nMain){ # iterate through main plots more quickly, plotting same time scale for each of paul, peter, diff
		tout <- switch(i, scale(out_L), scale(out_R), scale(out_R-out_L))
		ts_temp <- c(sub_out(tout, ind=ts_ind, type="sub"))
		plot(xval, ts_temp, xlab="", ylab="", type='l', xaxt='n', yaxt='n')
		axis(side=2, labels=TRUE, at=pretty(ts_temp, n=3), xpd=F)
		suppressWarnings({axis(side=1, labels=(s==1), mgp=c(1,-0.2, 0))})
		mtext(interval_name(ts_choices[s]), side=3, adj=0.98, font=2, line=-0.75)
		revS <- (nScales:1)[s]
		panelLab <- LETTERS[(i-1)*nScales+revS+i] # I appologize to my future self if he needs to understand this. Remember that the plots are created in a very jumbled way due to 1) the layout(), and 2) I go nScales:1 not 1:nScales, and 3) the s loop is outside the i loop [this point interacts with #1, such that I think they cancel each other]. Also, I had to fiddle a bit so I'm not even sure I understand the pattern, so don't be confused by those two points, especially the first, it might not be relevant. The +i at the end is just b/c I want the heat maps to be labeled A, E, and I, such that all the Paul Lake panels can be summarized as A-D, all the Peter Lake panels as E-H, and all the 'difference' panels as I-L.
		mtext(panelLab, side=3, adj=0.04, font=2, line=if(panelLab=='B'){-0.75}else{-0.75}, cex=1)
		# mtext(paste(panelLab, interval_name(ts_choices[s]), sep=", "), side=3, adj=0.99, font=2, line=-0.67)
		# A
	}
}
#'   
#' \FloatBarrier  
#'   
#' ***  
#'   
#' # Info
#+ Info, results='markup'
Sys.Date()
sessionInfo()






