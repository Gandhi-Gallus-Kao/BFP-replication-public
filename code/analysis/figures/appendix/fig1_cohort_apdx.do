clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig1_cohort_apdx_$sample.log", replace

if $sample == 1{
	global outdir "${BFPrep_outdir}/Subfigures/sample/appendix/first_year"
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
	global outdir "${BFPrep_outdir}/Subfigures/full/appendix/first_year"
	global indir "${anadatadir}/BabyConnect/full"
}

do "$anadir/misc/label_functions.do"
do "$anadir/misc/plot_functions.do"
include "$anadir/misc/fig1_cohort_labels.do"

************************* Same sample restriction as Figure 1 ********************************

use "$indir/figure1_cohort_analysis_data.dta", clear
keep if milk_producing
qui summarize age_day
di "Age range: " `r(min)' " to " `r(max)'

recode age_day (0/90 = 1 "<90 days") (91/180 = 2 "91 - 180 days") (181/365 = 3 "181 - 365 days") (else = 9), gen(age_cohort)
frames copy default fig1_cohort_sample
frames change fig1_cohort_sample

********************************** Loop through age groups ***********************************
******* FIGURE 1COH A *******
frames copy fig1_cohort_sample fig1a_cohort_sample
frames change fig1a_cohort_sample
	
foreach age of num 1/3{
	preserve
	keep if age_cohort == `age'
	gcollapse (sum) duration (max) milk_producing, by(childid startdate activity)

	** Histogram: 
	gen dur_milk = duration if milk_producing == 1
	keep if milk_producing == 1

	gcollapse (sum) dur_*, by(startdate childid)
	display as text _newline "===== FIGURE 1A | AGE COHORT `age' ====="

	count if dur_milk <= 540
	display "Child-days plotted: " %12.0fc r(N)
	summarize dur_milk, detail
	gen_stats dur_milk

	if `age' == 1{
		axis_lab_pct 2 10 2 ypctlabs1coha
		axis_lab_count 2 10 2 ylabs1coha`age'
	}
	if `age' == 2{
		axis_lab_pct 2 12 2 ypctlabs1coha
		axis_lab_count 2 12 2 ylabs1coha`age'
	}
	if `age' == 3{
		axis_lab_pct 4 16 4 ypctlabs1coha
		axis_lab_count 4 16 4 ylabs1coha`age'
	}

	histogram_stats dur_milk if dur_milk <= 540, discrete yaxis(1 2) width(15) start(0) ///
		ytitle("Percent", placement(n) orient(horizontal) axis(1) size(large)) ///
		ylabel(${ylabs1coha`age'}, nogrid angle(horizontal) axis(2) labsize(large)) ///
		ylabel(${ypctlabs1coha}, nogrid angle(horizontal) axis(1) labsize(large)) xlabel(0(90)540, nogrid labsize(large)) ///
		xtitle("Minutes",  size(large)) ytitle("Child-Days", placement(n) ///
		orient(horizontal) axis(2) size(large)) ///
		graphregion(margin(l+2 r+2 h+8)) aspect(0.75)
	
	gr_edit yaxis1.title.DragBy 5 13
	
	if `age' != 3{
		gr_edit yaxis2.title.DragBy 5 -28
	}

	if `age' == 3{
		gr_edit yaxis2.title.DragBy 5 -31
	}

	graph export "$outdir/1a_milk_dur_hist_cohort_`age'.pdf", replace
	restore
} 

******* FIGURE 1COH B *******
// Figure: Histogram of number of milk production events per day.
frames copy fig1_cohort_sample fig1b_cohort_sample
frames change fig1b_cohort_sample

foreach age of num 1/3{
	preserve
	keep if age_cohort == `age'
	gcollapse (sum) obs_milk = milk_producing, by(childid startdate)
	display as text _newline "===== FIGURE 1B | AGE COHORT `age' ====="

	count if obs_milk <= 24
	display "Child-days plotted: " %12.0fc r(N)
	summarize obs_milk, detail
	gen_stats obs_milk

	if `age' == 1{
		axis_lab_pct 4 16 4 ypctlabs1cohb
		axis_lab_count 4 16 4 ylabs1cohb`age'
	}
	if `age' == 2{
		axis_lab_pct 4 16 4 ypctlabs1cohb
		axis_lab_count 4 16 4 ylabs1cohb`age'
	}
	if `age' == 3{
		axis_lab_pct 4 16 4 ypctlabs1cohb
		axis_lab_count 4 16 4 ylabs1cohb`age'
	}

	histogram_stats obs_milk if obs_milk <= 24, discrete yaxis(1 2) width(1) start(0)  ///
		ytitle("Percent", placement(n) orient(horizontal) axis(1) size(large)) ///
		ylabel(${ylabs1cohb`age'}, nogrid angle(horizontal) axis(2) labsize(large)) ///
		ylabel(${ypctlabs1cohb}, nogrid angle(horizontal) axis(1) labsize(large)) xlabel(0(4)24, nogrid labsize(large)) ///
		xtitle("Events", size(large)) ytitle("Child-Days", placement(n) ///
		orient(horizontal) axis(2) size(large)) ///
		graphregion(margin(l+2 r+2 h+8)) aspect(0.75)

	gr_edit yaxis1.title.DragBy 5 13
	gr_edit yaxis2.title.DragBy 5 -31
	graph export "$outdir/1b_milk_obs_hist_cohort_`age'.pdf", replace
	restore
}

******* FIGURE 1COH C *******
// Sample: Restrict to daytimes (6am-10pm).
// Figure: Bins for hours of "uninterrupted" daytime periods of >=1, >=2, >=4 hours. 
// For example, if an individual had the following uninterrupted periods in a day: 
// 3.3 hours, 1.3 hours, 0.5 hours, 2 hours, they would have: 6.6 hours of 1+, 5.3 hours of 2+, and 0 hours of 4+. 
clear frames
frame change default

use "$indir/figure1cd_cohort_analysis_data.dta", clear
frames copy default fig1cd_cohort_sample
frames change fig1cd_cohort_sample

recode age_day (0/90 = 1 "<90 days") (91/180 = 2 "91 - 180 days") (181/365 = 3 "181 - 365 days") (else = 9), gen(age_cohort)

frames copy fig1cd_cohort_sample fig1c_cohort_sample
frames change fig1c_cohort_sample

foreach age of num 1/3{
	preserve
	keep if age_cohort == `age'
	keep if daytime == 1
	gen hour_diff = cond(activity == "Nothing":activity, Clockdiff_frac(starttime, endtime, "hour"), 0)
	drop if hour_diff < 0

	foreach h of numlist 1/4{
		gen hour_hr`h' = floor(hour_diff/`h')
	}

	collapse (sum) hour_hr*, by(date childid)
	drop if hour_hr1 > 15 | hour_hr2 > 7 | hour_hr3 > 5 | hour_hr4 > 3

	display as text _newline "===== FIGURE 1C | AGE COHORT `age' ====="

	count
	display "Child-days plotted (all four thresholds): " %12.0fc r(N)

	if `age' == 1{
		axis_lab_pct 5 20 5 ypctlabs1cohc1
		axis_lab_count 5 20 5 ylabs1cohc`age'1
		axis_lab_pct 10 30 10 ypctlabs1cohc2
		axis_lab_count 10 30 10 ylabs1cohc`age'2
		axis_lab_pct 10 40 10 ypctlabs1cohc3
		axis_lab_count 10 40 10 ylabs1cohc`age'3
		axis_lab_pct 25 75 25 ypctlabs1cohc4
		axis_lab_count 25 75 25 ylabs1cohc`age'4
	}
	if `age' == 2{
		axis_lab_pct 10 30 10 ypctlabs1cohc1
		axis_lab_count 10 30 10 ylabs1cohc`age'1
		axis_lab_pct 10 30 10 ypctlabs1cohc2
		axis_lab_count 10 30 10 ylabs1cohc`age'2
		axis_lab_pct 10 30 10 ypctlabs1cohc3
		axis_lab_count 10 30 10 ylabs1cohc`age'3
		axis_lab_pct 25 50 25 ypctlabs1cohc4
		axis_lab_count 25 50 25 ylabs1cohc`age'4
	}
	if `age' == 3{
		axis_lab_pct 10 30 10 ypctlabs1cohc1
		axis_lab_count 10 30 10 ylabs1cohc`age'1
		axis_lab_pct 10 30 10 ypctlabs1cohc2
		axis_lab_count 10 30 10 ylabs1cohc`age'2
		axis_lab_pct 10 30 10 ypctlabs1cohc3
		axis_lab_count 10 30 10 ylabs1cohc`age'3
		axis_lab_pct 10 30 10 ypctlabs1cohc4
		axis_lab_count 10 30 10 ylabs1cohc`age'4
	}
	
	foreach hour_level of num 1/4{
		summarize hour_hr`hour_level', detail
		gen_stats hour_hr`hour_level'
		histogram_stats hour_hr`hour_level', discrete width(1) yaxis(1 2) start(0) ///
			ytitle("Percent", placement(n) orient(horizontal) axis(1) size(huge)) ///
			ylabel(${ylabs1cohc`age'`hour_level'}, nogrid angle(horizontal) axis(2) labsize(huge)) ///
			ylabel(${ypctlabs1cohc`hour_level'}, nogrid angle(horizontal) axis(1) labsize(huge)) ///
			xlabel(${xlabs1cohc`hour_level'}, nogrid labsize(huge)) xtitle("Periods", size(huge)) ///
			ytitle("Child-Days", placement(n) orient(horizontal) axis(2) size(huge)) ///
			graphregion(margin(l+2 r+2 h+16)) ///
			aspect(0.55)

		gr_edit yaxis1.title.DragBy 7 21
		gr_edit yaxis2.title.DragBy 7 -33

		drop p* zero mean_hour
		graph export "$outdir/1c_uninterrupted_day_cohort_`age'_`hour_level'.pdf", replace
	}
	restore
}

******* FIGURE 1COH D *******
frames copy fig1cd_cohort_sample fig1d_cohort_sample
frames change fig1d_cohort_sample

foreach age of num 1/3{
	preserve
	keep if age_cohort == `age'

	gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
	keep if nighttime

	gcollapse (sum) milk_obs_count = milk_producing, by(childid adjust_startdate)
	display as text _newline "===== FIGURE 1D | AGE COHORT `age' ====="

	count
	display "Child-nights plotted: " %12.0fc r(N)

	quietly count if milk_obs_count == 0
	display "Nights with zero sessions (%): " %6.1f (100 * r(N) / _N)

	summarize milk_obs_count, detail
	gen_stats milk_obs_count
	axis_lab_pct 5 35 5 ypctlabs1cohd
	axis_lab_count 5 35 5 ylabs1cohd`age'

	local xlabs1cohd 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6+"
	gen milk_obs_count_plot = cond(milk_obs_count > 6, 6, milk_obs_count)
	histogram_stats milk_obs_count_plot, discrete yaxis(1 2) width(1) start(0) ///
		ytitle("Percent", placement(n) orient(horizontal) axis(1) size(large)) ///
		ytitle("Child-Days", placement(n) orient(horizontal) axis(2) size(large)) ///
		ylabel(${ypctlabs1cohd}, nogrid angle(horizontal) axis(1) labsize(large)) ///
		ylabel(${ylabs1cohd`age'}, nogrid angle(horizontal) axis(2) labsize(large)) ///
		xtitle("Sessions", size(large)) xlabel(`xlabs1cohd', nogrid labsize(large)) ///
		graphregion(margin(l+2 r+2 h+8)) aspect(0.75)

	gr_edit yaxis1.title.DragBy 5 11
	gr_edit yaxis2.title.DragBy 5 -24
	graph export "$outdir/1d_milk_prod_night_count_cohort_`age'.pdf", replace
	restore
}

log close