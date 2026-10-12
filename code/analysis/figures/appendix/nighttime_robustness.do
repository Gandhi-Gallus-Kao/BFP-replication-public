
clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/nighttime_robustness_$sample.log", replace

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
use "$indir/figure1cd_analysis_data.dta", clear
gen date = dofC(starttime)
format date %td
gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
keep if nighttime


preserve

* Indicator for having at least one late-night milk-producing record
* Late-night defined as 1 AM to 5 AM
gen late_night_milk = milk_producing & inrange(hhC(starttime), 1, 5)

gcollapse ///
    (sum) milk_obs_count = milk_producing ///
    (max) has_late_night_milk = late_night_milk, ///
    by(childid adjust_startdate)

* Restrict to child-days with evidence of late-night recording
keep if has_late_night_milk == 1
count
display "Nighttime robustness Figure 1D sample (child-days): " r(N)

gen_stats milk_obs_count
axis_lab_pct 8 40 8 ypctlabs1d
axis_lab_count 8 40 8 ylabs1d

local y1d_tick_pct_unit 8
local y1d_start = `r(N)' * (`y1d_tick_pct_unit' / 2) / 100
local y1d_unit = `r(N)' * `y1d_tick_pct_unit' / 100
local y1d_end = (`r(N)' * 40 / 100) - `y1d_start'
local yticks1dl `y1d_start'(`y1d_unit')`y1d_end'

local xlabs1d 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6+"
gen milk_obs_count_plot = cond(milk_obs_count > 6, 6, milk_obs_count)

histogram_stats milk_obs_count_plot, discrete yaxis(1 2) width(1) start(0) ///
    ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
    ylabel(${ylabs1d}, nogrid angle(horizontal) axis(2)) ///
    ylabel(${ypctlabs1d}, nogrid angle(horizontal) axis(1)) ///
    xlabel(`xlabs1d', nogrid) ///
    xtitle("Sessions") ///
    ytitle("Child-Days", placement(n) orient(horizontal) axis(2)) ///
    ymtick(`yticks1dl', axis(1)) ///
    graphregion(margin(l+2 r+2 h+8)) aspect(0.65)

gr_edit yaxis1.title.DragBy 4 7
gr_edit yaxis2.title.DragBy 4 -20

graph export "$outdir/1d_milk_prod_night_count_late_loggers.pdf", replace

summarize milk_obs_count
restore

// Descriptive check: distribution of recorded feeds by hour of night
use "$indir/figure1_analysis_data.dta", clear

gen date = dofC(starttime)
format date %td
gen night_hour = hhC(starttime)

keep if milk_producing
keep if inrange(night_hour, 22, 23) | inrange(night_hour, 0, 6)

count
display "Nighttime robustness milk-production events: " r(N)

gen night_hour_plot = night_hour
replace night_hour_plot = night_hour + 24 if night_hour <= 6

local ypctlabs_night 0 "0%" 5 "5%" 10 "10%" 15 "15%"

histogram night_hour_plot, discrete percent ///
    xlabel(22 "10 PM" 24 "12 AM" 26 "2 AM" 28 "4 AM" 30 "6 AM", nogrid) ///
    ylabel(`ypctlabs_night', nogrid angle(horizontal)) ///
	bgcolor(white) plotregion(style(none)) ///
	color(navy%70) ytitle("Percent", placement(n) orient(horizontal) margin(r+10 b+2)) ///
    xtitle("Hour of Night") ///
    graphregion(margin(l+2 r+2 h+8))
gr_edit yaxis1.title.DragBy 4 28
graph export "$outdir/night_hour_logging_dist.pdf", replace
log close



