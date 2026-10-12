clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig1_nursing_only_$sample.log", replace

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

use "$indir/figure1_analysis_nurse_only_data.dta", clear

* Nursing-only sample
quietly count
local nurse_only_obs = r(N)

quietly gdistinct childid
local nurse_only_childid = r(ndistinct)

* Full Figure 1 sample for comparison
preserve
    use "$indir/figure1_analysis_data.dta", clear

    quietly count
    local full_obs = r(N)

    quietly gdistinct childid
    local full_childid = r(ndistinct)
restore

* Report sample sizes and fractions
di as text _newline "===== NURSING-ONLY SAMPLE SUMMARY ====="
di as text "Nursing-only observations: " as result %12.0fc `nurse_only_obs'
di as text "Nursing-only children:    " as result %12.0fc `nurse_only_childid'
di as text "Share of full observations (%): " ///
    as result %6.1f (100 * `nurse_only_obs' / `full_obs')
di as text "Share of full children (%):     " ///
    as result %6.1f (100 * `nurse_only_childid' / `full_childid')

frames copy default figure1_sample
frames change figure1_sample

******* FIGURE 1A MAIN *******
** Figure: Histogram of duration of milk production per day.

frames copy figure1_sample figure1a_sample
frames change figure1a_sample

gcollapse (sum) duration (max) milk_producing, by(childid startdate activity)
gen dur_milk = duration if milk_producing == 1
keep if milk_producing == 1

gcollapse (sum) dur_*, by(startdate childid)
/* winsor2 dur*, cuts(0 99) */

qui count
local N_1a_nurse_only = r(N)

preserve
	quietly {
		keep if dur_milk <= 540
		gen long _bin = floor(dur_milk / 15)
		collapse (count) _cnt = dur_milk, by(_bin)
		sum _cnt
	}
	local max_1a_nurse_only = r(max)
restore

local ymx_1a_nurse_only = ceil(`max_1a_nurse_only' / `N_1a_nurse_only' * 100 / 5) * 5

gen_stats dur_milk
axis_lab_pct 5 `ymx_1a_nurse_only' 5 ypctlabs1a_nurse_only
axis_lab_count 5 `ymx_1a_nurse_only' 5 ylabs1a_nurse_only
	
local y1a_tick_pct_unit_nurse_only 5
local y1a_start_nurse_only = `N_1a_nurse_only' * (`y1a_tick_pct_unit_nurse_only' / 2) / 100
local y1a_unit_nurse_only = `N_1a_nurse_only' * `y1a_tick_pct_unit_nurse_only' / 100
local y1a_end_nurse_only = `N_1a_nurse_only' * `ymx_1a_nurse_only' / 100 - `y1a_start_nurse_only'
local yticks1al_nurse_only `y1a_start_nurse_only'(`y1a_unit_nurse_only')`y1a_end_nurse_only'

histogram_stats dur_milk if dur_milk <= 540, discrete yaxis(1 2) width(15) start(0) ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1) yoffset(4) xoffset(6)) ///
	xtitle("Minutes") ytitle("Child-Days", placement(n) orient(horizontal) axis(2) yoffset(4) xoffset(-21)) ///
	ylabel(${ylabs1a_nurse_only}, nogrid angle(horizontal) axis(2)) ///
	ylabel(${ypctlabs1a_nurse_only}, nogrid angle(horizontal) axis(1)) xlabel(0(90)540, nogrid) ///
	ymtick(`yticks1al_nurse_only', axis(1)) ///
	graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

graph export "$outdir/1a_milk_dur_hist_nurse_only.pdf", replace

gen sup_3_hr = 100*(dur_milk > 3 * 60)
summarize sup_3_hr, detail

******* FIGURE 1B *******
** Figure: Histogram of number of milk production events per day.
frames copy figure1_sample figure1b_sample
frames change figure1b_sample

gcollapse (sum) obs_milk = milk_producing (firstnm) age_day, by(childid startdate)

sum obs_milk if age_day == 70, detail

qui count
local N_1b_nurse_only = r(N)

preserve
	quietly {
		keep if obs_milk <= 24
		gen long _bin = obs_milk
		collapse (count) _cnt = obs_milk, by(_bin)
		sum _cnt
	}
	local max_1b_nurse_only = r(max)
restore

local ymx_1b_nurse_only = ceil(`max_1b_nurse_only' / `N_1b_nurse_only' * 100 / 4) * 4

gen_stats obs_milk
axis_lab_pct 4 `ymx_1b_nurse_only' 4 ypctlabs1b_nurse_only
axis_lab_count 4 `ymx_1b_nurse_only' 4 ylabs1b_nurse_only

local y1b_tick_pct_unit_nurse_only 2
local y1b_start_nurse_only = `N_1b_nurse_only' * `y1b_tick_pct_unit_nurse_only' / 100
local y1b_unit_nurse_only = `N_1b_nurse_only' * `y1b_tick_pct_unit_nurse_only' / 100
local y1b_end_nurse_only = `N_1b_nurse_only' * `ymx_1b_nurse_only' / 100 - `y1b_start_nurse_only'
local yticks1bl_nurse_only `y1b_start_nurse_only'(`y1b_unit_nurse_only')`y1b_end_nurse_only'

histogram_stats obs_milk if obs_milk <= 24, ///
	discrete yaxis(1 2) width(1) start(0) ///
	ylabel(${ylabs1b_nurse_only}, nogrid angle(horizontal) axis(2)) ///
	ymtick(`yticks1bl_nurse_only', axis(1)) ///
	ylabel(${ypctlabs1b_nurse_only}, nogrid angle(horizontal) axis(1)) ///
	xlabel(0(4)24, nogrid) ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	xtitle("Events") ytitle("Child-Days", placement(n) orient(horizontal) axis(2)) ///
	graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

gr_edit yaxis1.title.DragBy 4 7
gr_edit yaxis2.title.DragBy 4 -23
graph export "$outdir/1b_milk_obs_hist_nurse_only.pdf", replace

clear frames
frame change default

******* FIGURE 1C *******
frames copy default figure1cd_sample
frames change figure1cd_sample

use "$indir/figure1cd_analysis_nurse_only_data.dta", clear
gen date = dofC(starttime)
format date %td

frames copy figure1cd_sample figure1c_sample
frames change figure1c_sample

keep if daytime == 1
gen hour_diff = cond(activity == "Nothing":activity, Clockdiff_frac(starttime, endtime, "hour"), 0)
drop if hour_diff < 0

foreach h of numlist 1/4{
	gen hour_hr`h' = floor(hour_diff/`h')
}

collapse (sum) hour_hr*, by(date childid)
drop if hour_hr1 > 15 | hour_hr2 > 7 | hour_hr3 > 5 | hour_hr4 > 3

axis_lab_pct 5 25 5 ypctlabs1c1
axis_lab_count 5 25 5 ylabs1c1_nurse_only

axis_lab_pct 10 30 10 ypctlabs1c2
axis_lab_count 10 30 10 ylabs1c2_nurse_only

axis_lab_pct 10 30 10 ypctlabs1c3
axis_lab_count 10 30 10 ylabs1c3_nurse_only

axis_lab_pct 25 75 25 ypctlabs1c4
axis_lab_count 25 75 25 ylabs1c4_nurse_only

foreach hour_level of num 1/4 {
	gen_stats hour_hr`hour_level'

	histogram_stats hour_hr`hour_level', yaxis(1 2) ///
		start(0) discrete ///
		ytitle("Percent", placement(n) orient(horizontal) ///
			axis(1) size(vlarge)) ///
		ylabel(${ylabs1c`hour_level'_nurse_only}, ///
			nogrid angle(horizontal) axis(2) labsize(vlarge)) ///
		ylabel(${ypctlabs1c`hour_level'}, ///
			nogrid angle(horizontal) axis(1) labsize(vlarge)) ///
		xlabel(${xlabs1c`hour_level'_nurse_only}, ///
			nogrid labsize(vlarge)) ///
		xtitle("Periods", size(vlarge)) ///
		ytitle("Child-Days", placement(n) orient(horizontal) ///
			axis(2) size(vlarge)) ///
		graphregion(margin(l+2 r+2 h+16)) ///
		aspect(0.55)

	gr_edit yaxis1.title.DragBy 6 16
	gr_edit yaxis2.title.DragBy 6 -26

	drop p* zero mean_hour
	graph export "$outdir/1c_uninterrupted_day_nurse_only_`hour_level'.pdf", replace
}
******* FIGURE 1D *******
// Figure: Histograms of number of milk producing events.
frames copy figure1cd_sample figure1d_sample
frames change figure1d_sample

gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
keep if nighttime

gcollapse (sum) milk_obs_count = milk_producing, by(childid adjust_startdate)

gen_stats milk_obs_count
axis_lab_pct 8 40 8 ypctlabs1d
axis_lab_count 8 40 8 ylabs1d_nurse_only

local y1d_tick_pct_unit 8
local y1d_start = `r(N)' * (`y1d_tick_pct_unit' / 2) / 100
local y1d_unit = `r(N)' * `y1d_tick_pct_unit' / 100
local y1d_end = (`r(N)' * 40 / 100) - `y1d_start'
local yticks1dl `y1d_start'(`y1d_unit')`y1d_end'

local xlabs1d 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6+"
gen milk_obs_count_plot = cond(milk_obs_count > 6, 6, milk_obs_count)
histogram_stats milk_obs_count_plot, discrete yaxis(1 2) width(1) start(0) ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	ylabel(${ylabs1d_nurse_only}, nogrid angle(horizontal) axis(2)) ///
	ylabel(${ypctlabs1d}, nogrid angle(horizontal) axis(1)) xlabel(`xlabs1d', nogrid) ///
	xtitle("Sessions") ytitle("Child-Days", placement(n) ///
	orient(horizontal) axis(2)) ///
	ymtick(`yticks1dl', axis(1)) ///
	graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

gr_edit yaxis1.title.DragBy 4 7
gr_edit yaxis2.title.DragBy 4 -20

graph export "$outdir/1d_milk_prod_night_count_nurse_only.pdf", replace
log close
