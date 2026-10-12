clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig1_cohort_intersect_apdx_$sample.log", replace

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
include "$anadir/misc/fig1_cohort_labels_apdx.do"

************************* Same sample restriction as Figure 1 ********************************

use "$indir/figure1_cohort_analysis_data_intrsct.dta", clear
frames copy default fig1_cohort_intrsct_sample
frames change fig1_cohort_intrsct_sample

********************************** Now, loop through age groups ***********************************
** Age cohort groups:
** 1: <90 days
** 2: 91 - 180 days
** 3: 181 - 365 days


******* FIGURE 1A — INTERSECT COHORT *******
frames copy fig1_cohort_intrsct_sample fig1a_cohort_intrsct_sample
frames change fig1a_cohort_intrsct_sample

foreach age of num 1/3{
	preserve
	keep if age_cohort == `age'
	gcollapse (sum) duration (max) milk_producing, by(childid startdate activity)

	** Histogram: 
	gen dur_milk = duration if milk_producing == 1
	keep if milk_producing == 1

	gcollapse (sum) dur_*, by(startdate childid)

	display as text _newline "===== FIGURE 1A | INTERSECTION COHORT `age' ====="

	count
	display "Full sample (child-days): " %12.0fc r(N)

	count if dur_milk < 540
	display "Plotted sample (child-days): " %12.0fc r(N)

	summarize dur_milk, detail
	gen_stats dur_milk

	if `age' == 1{
		axis_lab_pct 2 10 2 ypctlabs1coha_intrsct
		axis_lab_count 2 10 2 ylabs1coha`age'_intrsct
	}
	if `age' == 2{
		axis_lab_pct 2 12 2 ypctlabs1coha_intrsct
		axis_lab_count 2 12 2 ylabs1coha`age'_intrsct
	}
	if `age' == 3{
		axis_lab_pct 4 16 4 ypctlabs1coha_intrsct
		axis_lab_count 4 16 4 ylabs1coha`age'_intrsct
	}

	histogram_stats dur_milk if dur_milk < 540, discrete yaxis(1 2) width(15) start(0) ///
		ytitle("Percent", placement(n) orient(horizontal) axis(1) size(large)) ///
		ylabel(${ylabs1coha`age'_intrsct}, nogrid angle(horizontal) axis(2) labsize(large)) ///
		ylabel(${ypctlabs1coha_intrsct}, nogrid angle(horizontal) axis(1) labsize(large)) xlabel(0(90)540, nogrid labsize(large)) ///
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

	graph export "$outdir/1a_milk_dur_hist_cohort_intrsct_`age'.pdf", replace
	restore
} 

******* FIGURE 1B — INTERSECT COHORT *******
// Figure: Histogram of number of milk production events per day.
frames copy fig1_cohort_intrsct_sample fig1b_cohort_intrsct_sample
frames change fig1b_cohort_intrsct_sample

foreach age of num 1/3{
	preserve
	keep if age_cohort == `age'
	gcollapse (sum) obs_milk = milk_producing, by(childid startdate)

	display as text _newline "===== FIGURE 1B | INTERSECTION COHORT `age' ====="

	count
	display "Full sample (child-days): " %12.0fc r(N)

	count if obs_milk <= 24
	display "Plotted sample (child-days): " %12.0fc r(N)

	summarize obs_milk, detail
	gen_stats obs_milk

	if `age' == 1{
		axis_lab_pct 4 16 4 ypctlabs1cohb_intrsct
		axis_lab_count 4 16 4 ylabs1cohb`age'_intrsct
	}
	if `age' == 2{
		axis_lab_pct 4 16 4 ypctlabs1cohb_intrsct
		axis_lab_count 4 16 4 ylabs1cohb`age'_intrsct
	}
	if `age' == 3{
		axis_lab_pct 4 16 4 ypctlabs1cohb_intrsct
		axis_lab_count 4 16 4 ylabs1cohb`age'_intrsct
	}

	histogram_stats obs_milk if obs_milk <= 24, discrete yaxis(1 2) width(1) start(0)  ///
		ytitle("Percent", placement(n) orient(horizontal) axis(1) size(large)) ///
		ylabel(${ylabs1cohb`age'_intrsct}, nogrid angle(horizontal) axis(2) labsize(large)) ///
		ylabel(${ypctlabs1cohb_intrsct}, nogrid angle(horizontal) axis(1) labsize(large)) xlabel(0(4)24, nogrid labsize(large)) ///
		xtitle("Events", size(large)) ytitle("Child-Days", placement(n) ///
		orient(horizontal) axis(2) size(large)) ///
		graphregion(margin(l+2 r+2 h+8)) aspect(0.75)

	gr_edit yaxis1.title.DragBy 5 13
	gr_edit yaxis2.title.DragBy 5 -31
	graph export "$outdir/1b_milk_obs_hist_cohort_intrsct_`age'.pdf", replace
	restore
}

******* FIGURE 1C — INTERSECT COHORT *******
clear frames
frame change default

use "$indir/figure1cd_analysis_data_intrsct.dta", clear
frames copy default fig1cd_cohort_intrsct_sample
frames change fig1cd_cohort_intrsct_sample

recode age_day (0/90 = 1 "<90 days") (91/180 = 2 "91 - 180 days") (181/365 = 3 "181 - 365 days") (else = 9), gen(age_cohort)

frames copy fig1cd_cohort_intrsct_sample fig1c_cohort_intrsct_sample
frames change fig1c_cohort_intrsct_sample

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

	display as text _newline "===== FIGURE 1C | INTERSECTION COHORT `age' ====="

	count
	display "Child-days (all four thresholds): " %12.0fc r(N)
	if `age' == 1{
		axis_lab_pct 5 20 5 ypctlabs1cohc1_intrsct
		axis_lab_count 5 20 5 ylabs1cohc`age'1_intrsct
		axis_lab_pct 10 30 10 ypctlabs1cohc2_intrsct
		axis_lab_count 10 30 10 ylabs1cohc`age'2_intrsct
		axis_lab_pct 10 30 10 ypctlabs1cohc3_intrsct
		axis_lab_count 10 30 10 ylabs1cohc`age'3_intrsct
		axis_lab_pct 25 75 25 ypctlabs1cohc4_intrsct
		axis_lab_count 25 75 25 ylabs1cohc`age'4_intrsct
	}
	if `age' == 2{
		axis_lab_pct 10 30 10 ypctlabs1cohc1_intrsct
		axis_lab_count 10 30 10 ylabs1cohc`age'1_intrsct
		axis_lab_pct 10 20 10 ypctlabs1cohc2_intrsct
		axis_lab_count 10 20 10 ylabs1cohc`age'2_intrsct
		axis_lab_pct 10 20 10 ypctlabs1cohc3_intrsct
		axis_lab_count 10 20 10 ylabs1cohc`age'3_intrsct
		axis_lab_pct 25 50 25 ypctlabs1cohc4_intrsct
		axis_lab_count 25 50 25 ylabs1cohc`age'4_intrsct
	}
	if `age' == 3{
		axis_lab_pct 10 30 10 ypctlabs1cohc1_intrsct
		axis_lab_count 10 30 10 ylabs1cohc`age'1_intrsct
		axis_lab_pct 10 30 10 ypctlabs1cohc2_intrsct
		axis_lab_count 10 30 10 ylabs1cohc`age'2_intrsct
		axis_lab_pct 10 30 10 ypctlabs1cohc3_intrsct
		axis_lab_count 10 30 10 ylabs1cohc`age'3_intrsct
		axis_lab_pct 10 30 10 ypctlabs1cohc4_intrsct
		axis_lab_count 10 30 10 ylabs1cohc`age'4_intrsct
	}

	foreach hour_level of num 1/4{
		summarize hour_hr`hour_level', detail
		gen_stats hour_hr`hour_level'
		histogram_stats hour_hr`hour_level', discrete width(1) yaxis(1 2) start(0) ///
			ytitle("Percent", placement(n) orient(horizontal) axis(1) size(huge)) ///
			ylabel(${ylabs1cohc`age'`hour_level'_intrsct}, nogrid angle(horizontal) axis(2) labsize(huge)) ///
			ylabel(${ypctlabs1cohc`hour_level'_intrsct}, nogrid angle(horizontal) axis(1) labsize(huge)) ///
			xlabel(${xlabs1cohc`hour_level'_intrsct}, nogrid labsize(huge)) xtitle("Periods", size(huge)) ///
			ytitle("Child-Days", placement(n) orient(horizontal) axis(2) size(huge)) ///
			graphregion(margin(l+2 r+2 h+16)) ///
			aspect(0.55)

		gr_edit yaxis1.title.DragBy 7 21
		gr_edit yaxis2.title.DragBy 7 -33

		drop p* zero mean_hour
		graph export "$outdir/1c_uninterrupted_day_cohort_intrsct_`age'_`hour_level'.pdf", replace

	}
	restore
}

******* FIGURE 1D — INTERSECT COHORT *******
frames copy fig1cd_cohort_intrsct_sample fig1d_cohort_intrsct_sample
frames change fig1d_cohort_intrsct_sample

foreach age of num 1/3{
	preserve
	keep if age_cohort == `age'

 	gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
	keep if nighttime

	gcollapse (sum) milk_obs_count = milk_producing, by(childid adjust_startdate)

	display as text _newline "===== FIGURE 1D | INTERSECTION COHORT `age' ====="

	count
	display "Child-nights: " %12.0fc r(N)

	quietly count if milk_obs_count == 0
	display "Nights with zero sessions (%): " %6.1f (100 * r(N) / _N)

	summarize milk_obs_count, detail
	gen_stats milk_obs_count
	axis_lab_pct 5 35 5 ypctlabs1cohd_intrsct
	axis_lab_count 5 35 5 ylabs1cohd`age'_intrsct

	local xlabs1cohd 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6+"
	replace milk_obs_count = 6 if milk_obs_count > 6
	histogram_stats milk_obs_count, discrete yaxis(1 2) width(1) start(0) ///
		ytitle("Percent", placement(n) orient(horizontal) axis(1) size(large)) ///
		ytitle("Child-Days", placement(n) orient(horizontal) axis(2) size(large)) ///
		ylabel(${ypctlabs1cohd_intrsct}, nogrid angle(horizontal) axis(1) labsize(large)) ///
		ylabel(${ylabs1cohd`age'_intrsct}, nogrid angle(horizontal) axis(2) labsize(large)) ///
		xtitle("Sessions", size(large)) xlabel(`xlabs1cohd', nogrid labsize(large)) ///
		graphregion(margin(l+2 r+2 h+8)) aspect(0.75)

	gr_edit yaxis1.title.DragBy 5 11
	gr_edit yaxis2.title.DragBy 5 -24
	graph export "$outdir/1d_milk_prod_night_count_cohort_intrsct_`age'.pdf", replace

	restore
}

log close
