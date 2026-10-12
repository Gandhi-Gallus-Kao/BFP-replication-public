clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig1_feed_apdx_$sample.log", replace

if $sample == 1{
    global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
    global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
	global indir "${anadatadir}/BabyConnect/full"
}

do "$anadir/misc/label_functions.do"
do "$anadir/misc/plot_functions.do"
include "$anadir/misc/fig1_labels_apdx.do"

use "$indir/figure1_analysis_feed_data.dta", clear
frames copy default figure1_apdx_sample_pt1
frames change figure1_apdx_sample_pt1

******* FIGURE 1A FEEDING-RELATED APPENDIX *******
// Do this for all feeding-related activities (nursing, expressing, bottle feeding, solid foods)
frames copy figure1_apdx_sample_pt1 figure1a_sample_apdx
frames change figure1a_sample_apdx

gcollapse (sum) duration (max) feeding_related, by(childid startdate activity)
gen dur_feed = duration if feeding_related == 1

gcollapse (sum) dur_*, by(startdate childid)
gen_stats dur_feed

axis_lab_pct 3 9 3 ypctlabs1a_feed
axis_lab_count 3 9 3 ylabs1a_feed

local y1a_tick_pct_unit 1.5
local y1a_start = `r(N)' * `y1a_tick_pct_unit' / 100
local y1a_unit = `r(N)' * `y1a_tick_pct_unit' / 100
local y1a_end = `r(N)' * 9 / 100 - (`y1a_start')
local yticks1al_feed `y1a_start'(`y1a_unit')`y1a_end'

histogram_stats dur_feed if dur_feed < 540, discrete yaxis(1 2) width(15) start(0) ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1) yoffset(4) xoffset(3)) ///
	xtitle("Minutes") ytitle("Child-Days", placement(n) orient(horizontal) axis(2) yoffset(4) xoffset(-21)) ///
	ylabel(${ylabs1a_feed}, nogrid angle(horizontal) axis(2)) ///
	ylabel(${ypctlabs1a_feed}, nogrid angle(horizontal) axis(1)) xlabel(0(60)540, nogrid) ///
	ymtick(`yticks1al_feed', axis(1)) ///
	graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

graph export "$outdir/1a_feed_dur_hist_apdx.pdf", replace

******* FIGURE 1B FEEDING-RELATED APPENDIX *******
// Figure: Histogram of number of feeding-related events per day.
frames copy figure1_apdx_sample_pt1 figure1b_sample_apdx
frames change figure1b_sample_apdx

** Histogram: 
gcollapse (sum) obs_feed = feeding_related, by(childid startdate)

gen_stats obs_feed
axis_lab_pct 5 15 5 ypctlabs1b_feed
axis_lab_count 5 15 5 ylabs1b_feed

local y1b_tick_pct_unit 2.5
local y1b_start = `r(N)' * `y1b_tick_pct_unit' / 100
local y1b_unit = `r(N)' * `y1b_tick_pct_unit' / 100
local y1b_end = `r(N)' * 15 / 100 - (`y1b_start')
local yticks1bl_feed `y1b_start'(`y1b_unit')`y1b_end'

histogram_stats obs_feed if obs_feed <= 24, ///
	discrete yaxis(1 2) width(1) start(0) ///
	ylabel(${ylabs1b_feed}, nogrid angle(horizontal) axis(2)) ///
	ymtick(`yticks1bl_feed', axis(1)) ///
	ylabel(${ypctlabs1b_feed}, nogrid angle(horizontal) axis(1)) xlabel(0(4)24, nogrid) ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	xtitle("Events") ytitle("Child-Days", placement(n) orient(horizontal) axis(2)) ///
	graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

gr_edit yaxis1.title.DragBy 4 7
gr_edit yaxis2.title.DragBy 4 -23
graph export "$outdir/1b_feed_obs_hist_apdx.pdf", replace

clear frames
frame change default

******* FIGURE 1C FEEDING-RELATED APPENDIX *******
frames copy default figure1cd_sample_apdx_pt1
frames change figure1cd_sample_apdx_pt1

use "$indir/figure1cd_analysis_feed_data.dta", clear
gen date = dofC(starttime)
format date %td

frames copy figure1cd_sample_apdx_pt1 figure1c_sample_apdx_pt1
frames change figure1c_sample_apdx_pt1

keep if daytime == 1
gen hour_diff = cond(activity == "Nothing":activity, Clockdiff_frac(starttime, endtime, "hour"), 0)
drop if hour_diff < 0

foreach h of numlist 1/4{
	gen hour_hr`h' = floor(hour_diff/`h')
}

collapse (sum) hour_hr*, by(date childid)
drop if hour_hr1 > 15 | hour_hr2 > 7 | hour_hr3 > 5 | hour_hr4 > 3

axis_lab_pct 5 25 5 ypctlabs1c1_feed
axis_lab_count 5 25 5 ylabs1c1_feed
axis_lab_pct 10 30 10 ypctlabs1c2_feed
axis_lab_count 10 30 10 ylabs1c2_feed
axis_lab_pct 10 40 10 ypctlabs1c3_feed
axis_lab_count 10 40 10 ylabs1c3_feed
axis_lab_pct 25 75 25 ypctlabs1c4_feed
axis_lab_count 25 75 25 ylabs1c4_feed

foreach hour_level of num 1/4{
	gen_stats hour_hr`hour_level'
	histogram_stats hour_hr`hour_level', yaxis(1 2) ///
		start(0) discrete ytitle("Percent", placement(n) orient(horizontal) ///
		axis(1) size(vlarge)) ///
		ylabel(${ylabs1c`hour_level'_feed}, nogrid angle(horizontal) axis(2) labsize(vlarge)) ///
		ylabel(${ypctlabs1c`hour_level'_feed}, nogrid angle(horizontal) axis(1) labsize(vlarge)) ///
		xlabel(${xlabs1c`hour_level'_feed}, nogrid labsize(vlarge)) ///
		xtitle("Periods", size(vlarge)) ytitle("Child-Days", ///
		placement(n) orient(horizontal) axis(2) size(vlarge)) ///
		graphregion(margin(l+2 r+2 h+16)) ///
		aspect(0.55)

	gr_edit yaxis1.title.DragBy 6 16
	gr_edit yaxis2.title.DragBy 6 -26

	drop p* zero mean_hour
	graph export "$outdir/1c_uninterrupted_day_feed_apdx_`hour_level'.pdf", replace
}

******* FIGURE 1D FEEDING-RELATED APPENDIX *******
frames copy figure1cd_sample_apdx_pt1 figure1d_sample_apdx_pt1
frames change figure1d_sample_apdx_pt1

gen feeding = inlist(activity, "Nursing":activity, "Expressed":activity, "Bottle":activity, "Solid Food":activity)
keep if nighttime

gcollapse (sum) feed_obs_count = feeding, by(childid adjust_startdate)

gen_stats feed_obs_count
axis_lab_pct 8 32 8 ypctlabs1d_feed
axis_lab_count 8 32 8 ylabs1d_feed

local y1d_tick_pct_unit 4
local y1d_start = `r(N)' * (`y1d_tick_pct_unit' ) / 100
local y1d_unit = `r(N)' * `y1d_tick_pct_unit' / 100
local y1d_end = (`r(N)' * 32 / 100) - `y1d_start'
local yticks1dl_feed `y1d_start'(`y1d_unit')`y1d_end'

local xlabs1d_feed 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8+"
replace feed_obs_count = 8 if feed_obs_count > 8

histogram_stats feed_obs_count, discrete yaxis(1 2) width(1) start(0) ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	ylabel(${ylabs1d_feed}, nogrid angle(horizontal) axis(2)) ///
	ylabel(${ypctlabs1d_feed}, nogrid angle(horizontal) axis(1)) xlabel(`xlabs1d_feed', nogrid) ///
	xtitle("Sessions") ytitle("Child-Days", placement(n) ///
	orient(horizontal) axis(2)) ///
	ymtick(`yticks1dl_feed', axis(1)) ///
	graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

gr_edit yaxis1.title.DragBy 4 7
gr_edit yaxis2.title.DragBy 4 -20

graph export "$outdir/1d_feed_night_count_apdx.pdf", replace

******* FIGURE 1C 8-8 APPENDIX *******
****** This appendix figure simply uses the different daytime/nighttime (i.e. 8-8)
clear frames
frame change default

use "$indir/figure1cd_analysis_data_8_8.dta", clear
frames copy default figure1_apdx_sample_pt2
frames change figure1_apdx_sample_pt2

frames copy figure1_apdx_sample_pt2 figure1c_apdx_sample_pt2
frames change figure1c_apdx_sample_pt2

gen date = dofC(starttime)
format date %td

keep if daytime == 1
gen hour_diff = cond(activity == "Nothing":activity, Clockdiff_frac(starttime, endtime, "hour"), 0)
drop if hour_diff < 0

foreach h of numlist 1/4{
	gen hour_hr`h' = floor(hour_diff/`h')
}

collapse (sum) hour_hr*, by(date childid)
drop if hour_hr1 > 11 | hour_hr2 > 5 | hour_hr3 > 3 | hour_hr4 > 2

axis_lab_pct 10 30 10 ypctlabs1c1_8_8
axis_lab_count 10 30 10 ylabs1c1_8_8
axis_lab_pct 10 30 10 ypctlabs1c2_8_8
axis_lab_count 10 30 10 ylabs1c2_8_8
axis_lab_pct 10 40 10 ypctlabs1c3_8_8
axis_lab_count 10 40 10 ylabs1c3_8_8
axis_lab_pct 25 75 25 ypctlabs1c4_8_8
axis_lab_count 25 75 25 ylabs1c4_8_8

foreach hour_level of num 1/4{
	gen_stats hour_hr`hour_level'
	histogram_stats hour_hr`hour_level', yaxis(1 2) ///
		start(0) discrete ytitle("Percent", placement(n) orient(horizontal) ///
		axis(1) size(vlarge)) ///
		ylabel(${ylabs1c`hour_level'_8_8}, nogrid angle(horizontal) axis(2) labsize(vlarge)) ///
		ylabel(${ypctlabs1c`hour_level'_8_8}, nogrid angle(horizontal) axis(1) labsize(vlarge)) ///
		xlabel(${xlabs1c`hour_level'_8_8}, nogrid labsize(vlarge)) ///
		xtitle("Periods", size(vlarge)) ytitle("Child-Days", ///
		placement(n) orient(horizontal) axis(2) size(vlarge)) ///
		graphregion(margin(l+2 r+2 h+16)) ///
		aspect(0.55)

	gr_edit yaxis1.title.DragBy 6 16
	gr_edit yaxis2.title.DragBy 6 -26

	drop p* zero mean_hour
	graph export "$outdir/1c_uninterrupted_day_8_8_apdx_`hour_level'.pdf", replace
}

******* FIGURE 1D 8-8 APPENDIX *******
frames copy figure1_apdx_sample_pt2 figure1d_sample_apdx_pt2
frames change figure1d_sample_apdx_pt2

gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
keep if nighttime

gcollapse (sum) milk_obs_count = milk_producing, by(childid adjust_startdate)

gen_stats milk_obs_count
axis_lab_pct 5 25 5 ypctlabs1d_8_8
axis_lab_count 5 25 5 ylabs1d_8_8

local xlabs1d_8_8 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8+"
replace milk_obs_count = 8 if milk_obs_count > 8
histogram_stats milk_obs_count, discrete yaxis(1 2) width(1) start(0) ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	ylabel(${ylabs1d_8_8}, nogrid angle(horizontal) axis(2)) ///
	ylabel(${ypctlabs1d_8_8}, nogrid angle(horizontal) axis(1)) xlabel(`xlabs1d_8_8', nogrid) ///
	xtitle("Sessions") ytitle("Child-Days", placement(n) ///
	orient(horizontal) axis(2)) ///
	graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

gr_edit yaxis1.title.DragBy 4 7
gr_edit yaxis2.title.DragBy 4 -20

graph export "$outdir/1d_milk_prod_night_count_8_8_apdx.pdf", replace

log close