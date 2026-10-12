clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig1_year_apdx_$sample.log", replace

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
* Load datasets once and create master frames
use "$indir/figure1_analysis_data.dta", clear
gen year = year(dofC(starttime))
gen time_period = (year <= 2017)
label define time_period 0 "2018-2022" 1 "2012-2017"
label values time_period time_period
frames copy default figure1ab_main

use "$indir/figure1cd_analysis_data.dta", clear
gen year = year(dofC(starttime))
gen time_period = (year <= 2017)
frames copy default figure1cd_main

******* FIGURE 1A COMPARISON *******
** Figure: Overlapping histogram of duration of milk production per day - First vs Second Half
frames copy figure1ab_main figure1a_sample
frames change figure1a_sample

qui summarize age_day
di "Age range: " `r(min)' " to " `r(max)'

gcollapse (sum) duration (max) milk_producing, by(childid startdate activity time_period)
gen dur_milk = duration if milk_producing == 1
keep if milk_producing == 1

gcollapse (sum) dur_*, by(startdate childid time_period)

* Create separate variables for each time period
gen dur_milk_first = dur_milk if time_period == 1
gen dur_milk_second = dur_milk if time_period == 0

* Dynamically compute max bin percent across both periods
preserve
	quietly {
		keep if dur_milk <= 540
		gen long _bin = floor(dur_milk / 15)
		count if time_period == 1
		local N1 = r(N)
		count if time_period == 0
		local N0 = r(N)
		collapse (count) _cnt = dur_milk, by(_bin time_period)
		replace _cnt = _cnt / `N1' * 100 if time_period == 1
		replace _cnt = _cnt / `N0' * 100 if time_period == 0
		sum _cnt
	}
	local max_1a = r(max)
restore
local ymx_1a = ceil(`max_1a' / 5) * 5

axis_lab_pct_simple 5 `ymx_1a' 5 ypctlabs1a
local yticks1al_year_comp 2.5(5)`=`ymx_1a' - 2.5'
twoway (histogram dur_milk_first if dur_milk_first <= 540, color(blue%30) discrete start(0) width(15) percent) ///
       (histogram dur_milk_second if dur_milk_second <= 540, color(red%30) discrete start(0) width(15) percent), ///
       legend(off) ///
	   ytitle("Percent", placement(n) orient(horizontal) yoffset(4) xoffset(17)) ///
	   xtitle("Minutes") ///
	   ymtick(`yticks1al_year_comp') ///
       xlabel(0(90)540, nogrid) ///
       bgcolor(white) plotregion(style(none)) ///
       ylabel(${ypctlabs1a}, nogrid angle(horizontal)) xlabel(, nogrid) ///
	   graphregion(color(white) margin(l+2 r+2 h+8)) aspect(0.65)

graph export "$outdir/1a_milk_dur_hist_comparison.pdf", replace

* Summary statistics for both periods
sum dur_milk if time_period == 1, detail
di "First half (2012-2017) - Mean: " `r(mean)' " Median: " `r(p50)'
sum dur_milk if time_period == 0, detail
di "Second half (2018-2022) - Mean: " `r(mean)' " Median: " `r(p50)'

******* FIGURE 1B COMPARISON *******
** Figure: Overlapping histogram of number of milk production events per day - First vs Second Half
frames copy figure1ab_main figure1b_sample
frames change figure1b_sample

gcollapse (sum) obs_milk = milk_producing (firstnm) age_day time_period, by(childid startdate)

* Create separate variables for each time period
gen obs_milk_first = obs_milk if time_period == 1
gen obs_milk_second = obs_milk if time_period == 0

* Dynamically compute max bin percent across both periods
preserve
	quietly {
		keep if obs_milk <= 24
		gen long _bin = obs_milk
		count if time_period == 1
		local N1 = r(N)
		count if time_period == 0
		local N0 = r(N)
		collapse (count) _cnt = obs_milk, by(_bin time_period)
		replace _cnt = _cnt / `N1' * 100 if time_period == 1
		replace _cnt = _cnt / `N0' * 100 if time_period == 0
		sum _cnt
	}
	local max_1b = r(max)
restore
local ymx_1b = ceil(`max_1b' / 4) * 4

axis_lab_pct_simple 4 `ymx_1b' 4 ypctlabs1b
local yticks1bl_year_comp 2(4)`=`ymx_1b' - 2'

twoway (histogram obs_milk_first if obs_milk_first <= 24, color(blue%30) discrete start(0) width(1) percent) ///
       (histogram obs_milk_second if obs_milk_second <= 24, color(red%30) discrete start(0) width(1) percent), ///
       legend(off) ///
	   ytitle("Percent", placement(n) orient(horizontal) yoffset(4) xoffset(17)) ///
	   xtitle("Events") ///
	   ymtick(`yticks1bl_year_comp') ///
       xlabel(0(4)24, nogrid) ///
       bgcolor(white) plotregion(style(none)) ///
       ylabel(${ypctlabs1b}, nogrid angle(horizontal)) xlabel(, nogrid) ///
	   graphregion(color(white) margin(l+2 r+2 h+8)) aspect(0.65)

graph export "$outdir/1b_milk_obs_hist_comparison.pdf", replace

* Summary statistics for both periods
sum obs_milk if time_period == 1, detail
di "First half (2012-2017) - Mean: " `r(mean)' " Median: " `r(p50)'
sum obs_milk if time_period == 0, detail
di "Second half (2018-2022) - Mean: " `r(mean)' " Median: " `r(p50)'

******* FIGURE 1C COMPARISON *******
** Figure: Overlapping histograms of uninterrupted time periods - First vs Second Half
frames copy figure1cd_main figure1c_sample
frames change figure1c_sample

gen date = dofC(starttime)
format date %td

keep if daytime == 1
gen hour_diff = cond(activity == "Nothing":activity, Clockdiff_frac(starttime, endtime, "hour"), 0)
drop if hour_diff < 0

foreach h of numlist 1/4{
	gen hour_hr`h' = floor(hour_diff/`h')
}

collapse (sum) hour_hr*, by(date childid time_period)
drop if hour_hr1 > 15 | hour_hr2 > 7 | hour_hr3 > 5 | hour_hr4 > 3

foreach hour_level of num 1/4{
	* Create separate variables for each time period
	gen hour_hr`hour_level'_first = hour_hr`hour_level' if time_period == 1
	gen hour_hr`hour_level'_second = hour_hr`hour_level' if time_period == 0
	
	local max_val = 15
    local increment = 1
    if `hour_level' == 1 local increment = 2
	if `hour_level' == 2 local max_val = 7
	if `hour_level' == 3 local max_val = 5
	if `hour_level' == 4 local max_val = 3
	
	* Set up y-axis labels based on hour_level
	if `hour_level' == 1 {
		axis_lab_pct_simple 5 25 5 ypctlabs1c`hour_level'
	}
	else if `hour_level' == 2 {
		axis_lab_pct_simple 10 30 10 ypctlabs1c`hour_level'
	}
	else if `hour_level' == 3 {
		axis_lab_pct_simple 10 40 10 ypctlabs1c`hour_level'
	}
	else if `hour_level' == 4 {
		axis_lab_pct_simple 20 80 20 ypctlabs1c`hour_level'
	}
	
	twoway (histogram hour_hr`hour_level'_first if hour_hr`hour_level'_first <= `max_val', color(blue%30) discrete start(0) width(1) percent) ///
	       (histogram hour_hr`hour_level'_second if hour_hr`hour_level'_second <= `max_val', color(red%30) discrete start(0) width(1) percent), ///
	       legend(off) ///
	       ytitle("Percent", placement(n) orient(horizontal) yoffset(5.5) xoffset(26) size(vlarge)) ///
		   xtitle("Periods", size(vlarge)) ///
	       xlabel(0(`increment')`max_val', nogrid labsize(vlarge)) ///
		   bgcolor(white) plotregion(style(none)) ///
		   graphregion(color(white) margin(l+2 r+2 h+16)) ///
	       ylabel(${ypctlabs1c`hour_level'}, nogrid angle(horizontal)  labsize(vlarge))

	
	graph export "$outdir/1c_uninterrupted_day_`hour_level'_comparison.pdf", replace
	
	* Summary statistics for both periods
	sum hour_hr`hour_level' if time_period == 1, detail
	di "`hour_level'-hour periods - First half (2012-2017) - Mean: " `r(mean)' " Median: " `r(p50)'
	sum hour_hr`hour_level' if time_period == 0, detail
	di "`hour_level'-hour periods - Second half (2018-2022) - Mean: " `r(mean)' " Median: " `r(p50)'
	
	drop hour_hr`hour_level'_first hour_hr`hour_level'_second
}

******* FIGURE 1D COMPARISON *******
** Figure: Overlapping histograms of nighttime milk production events - First vs Second Half
frames copy figure1cd_main figure1d_sample
frames change figure1d_sample

gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
keep if nighttime

gcollapse (sum) milk_obs_count = milk_producing, by(childid adjust_startdate time_period)

* Create separate variables for each time period
gen milk_obs_count_first = milk_obs_count if time_period == 1
gen milk_obs_count_second = milk_obs_count if time_period == 0

* Cap at 6 for visualization
replace milk_obs_count_first = 6 if milk_obs_count_first > 6 & !missing(milk_obs_count_first)
replace milk_obs_count_second = 6 if milk_obs_count_second > 6 & !missing(milk_obs_count_second)
local xlabs1d 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6+"

axis_lab_pct_simple 10 40 10 ypctlabs1d

twoway (histogram milk_obs_count_first, color(blue%30) discrete start(0) width(1) percent) ///
       (histogram milk_obs_count_second, color(red%30) discrete start(0) width(1) percent), ///
       legend(off) ///
       ytitle("Percent", placement(n) orient(horizontal) yoffset(4) xoffset(17)) xtitle("Sessions") ///
       bgcolor(white) plotregion(style(none)) ///
       ylabel(${ypctlabs1d}, nogrid angle(horizontal)) xlabel(`xlabs1d', nogrid) ///
	   graphregion(color(white) margin(l+2 r+2 h+8)) aspect(0.65)

graph export "$outdir/1d_milk_prod_night_count_comparison.pdf", replace

* Summary statistics for both periods
sum milk_obs_count if time_period == 1, detail
di "Night sessions - First half (2012-2017) - Mean: " `r(mean)' " Median: " `r(p50)'
sum milk_obs_count if time_period == 0, detail
di "Night sessions - Second half (2018-2022) - Mean: " `r(mean)' " Median: " `r(p50)'

log close
