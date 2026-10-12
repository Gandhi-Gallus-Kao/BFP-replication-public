clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0

log using "$logdir/fig23_graphs_$sample.log", replace

if $sample == 1{
	global outdir "${BFPrep_outdir}/Subfigures/sample"
	global apdxoutdir "${BFPrep_outdir}/Subfigures/sample/appendix"
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
	global outdir "${BFPrep_outdir}/Subfigures/full"
    global apdxoutdir "${BFPrep_outdir}/Subfigures/full/appendix"
	global indir "${anadatadir}/BabyConnect/full"
}

***** DURATION
do "$anadir/misc/label_functions.do"
do "$anadir/misc/plot_functions.do"

// Load margins results for first graph
use "$indir/fig23_regression_results.dta", clear

******************************************************************************
* FIGURE 2: AGE-SPECIFIC MILK-PRODUCTION DURATION
******************************************************************************

display "=================================================="
display "FIGURE 2: DAILY MILK-PRODUCTION DURATION"
display "=================================================="

* Day 15 (hours)
quietly summarize pred_logdur if age == 15
local est = r(mean) / 60
quietly summarize low if age == 15
local lb = r(mean) / 60
quietly summarize hi if age == 15
local ub = r(mean) / 60

display "Day 15 (hours):"
display "  Estimate: " %8.0f `est'
display "  95% CI: [" %8.0f `lb' ", " %8.0f `ub' "]"

* Day 150 / Month 5 (hours)
quietly summarize pred_logdur if age == 150
local est = r(mean) / 60
quietly summarize low if age == 150
local lb = r(mean) / 60
quietly summarize hi if age == 150
local ub = r(mean) / 60

display "Month 5 (hours):"
display "  Estimate: " %8.2f `est'
display "  95% CI: [" %8.2f `lb' ", " %8.2f `ub' "]"

* Day 365 (minutes)
quietly summarize pred_logdur if age == 365
local est = r(mean)
quietly summarize low if age == 365
local lb = r(mean)
quietly summarize hi if age == 365
local ub = r(mean)

display "Day 365 (minutes):"
display "  Estimate: " %8.0f `est'
display "  95% CI: [" %8.0f `lb' ", " %8.0f `ub' "]"

* Annual fitted profile and delta-method SE
quietly summarize total_profile_mean
local profile_total_min = r(mean)

quietly summarize total_profile_se
local profile_total_se = r(mean)

display "Annual fitted-profile total (minutes): " `profile_total_min'
display "Annual fitted-profile SE (minutes): " `profile_total_se'

// First graph: margins plot
twoway rarea low hi age, color(navy%70) || ///
	line pred_logdur age, graphregion(color(white)) bgcolor(white) plotregion(style(none)) ///
	xlabel(0(30)365, nogrid) xtitle("Age of Child in Days") ylabel(0(30)180, ///
	nogrid angle(horizontal)) color(navy) ///
	ytitle("Minutes per Day", placement(n) ///
	orient(horizontal)) ysc(titlegap(-10) outergap(0)) ///
	graphregion(margin(l+4 r+4 h+8)) title("") legend(off) aspect(0.55)
gr_edit yaxis1.title.DragBy 4 10
graph export "$outdir/fig2/2_milk_logdur_margins_30.pdf", replace

******************************************************************************
* FIGURE 3: ANNUAL MILK-PRODUCTION TIME AND ECONOMIC VALUE
******************************************************************************

use "$indir/fig23_prediction_results.dta", clear

* Annual duration in minutes
gen duration_minutes = total_duration * 60

quietly summarize duration_minutes
local avg_duration = r(mean)

* Delta-method confidence interval
local profile_ratio = `avg_duration' / `profile_total_min'
local annual_se = `profile_ratio' * `profile_total_se'
local annual_low = `avg_duration' - 1.96 * `annual_se'
local annual_high = `avg_duration' + 1.96 * `annual_se'

* Convert to hours and workweeks
local avg_hours = `avg_duration' / 60
local avg_weeks = `avg_hours' / 40

* Economic valuation ($15.93 per hour)
local wage = 15.93
local mean_cost = `avg_hours' * `wage'
local low_cost = (`annual_low' / 60) * `wage'
local high_cost = (`annual_high' / 60) * `wage'

display "=================================================="
display "FIGURE 3: ANNUAL MILK-PRODUCTION TIME AND VALUE"
display "=================================================="

display "Annual duration (minutes): " %12.0fc `avg_duration'
display "Annual duration (hours):   " %12.1fc `avg_hours'
display "Equivalent 40-hour weeks: " %12.1f `avg_weeks'

display "Annual duration 95% CI (minutes):"
display "  [" %12.0fc `annual_low' ", " %12.0fc `annual_high' "]"

display "Value of time ($): " %12.0fc `mean_cost'
display "Value of time 95% CI ($):"
display "  [" %12.0fc `low_cost' ", " %12.0fc `high_cost' "]"

* Compute Stata's default bin width: min(ceil(sqrt(N)), ceil(10*log10(N))) bins
qui sum total_duration if total_duration < 1500
local h_min = r(min)
local h_max = r(max)
local N_hist = r(N)
local h_nbins = min(ceil(sqrt(`N_hist')), ceil(10 * log10(`N_hist')))
local hw = (`h_max' - `h_min') / `h_nbins'

preserve
	quietly {
		keep if total_duration < 1500
		gen long _bin = floor((total_duration - `h_min') / `hw')
		collapse (count) _cnt = total_duration, by(_bin)
		sum _cnt
	}
	local max_3b = r(max)
restore

qui count
local ymx_3b = ceil(`max_3b' / r(N) * 100 / 5) * 5

axis_lab_pct 0 `ymx_3b' 5 ypctlabs3b
axis_lab_count 0 `ymx_3b' 5 ylabs3b

gen_stats total_duration

* 95% CI for mean annual duration (hours), plotted around the mean marker
gen double ci_low_total_duration  = `annual_low' / 60 if _n == 1
gen double ci_high_total_duration = `annual_high' / 60 if _n == 1

// Second graph: histogram
histogram_stats total_duration if total_duration < 1500, ///
	cilow(ci_low_total_duration) cihigh(ci_high_total_duration) ///
	yaxis(1 2) ///
	xtitle("Hours" "(Economic Value of Time at Median Wage)") ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	ytitle("Mothers", placement(n) orient(horizontal) axis(2)) ///
	ylabel(${ypctlabs3b}, nogrid angle(horizontal) axis(1)) ///
	ylabel(${ylabs3b}, nogrid angle(horizontal) axis(2)) ///
	ylabel(, nogrid angle(horizontal)) ///
	xlabel(0 `" "0"   "($0)" "' 250 `" "250"   "($3,983)" "'  ///
		500 `" "500"   "($7,965)" "'  750 `" "750"   "($11,948)" "'  ///
		1000 `" "1000"   "($15,930)" "'   1250 `" "1250"   "($19,913)" "' ///
		1500 `" "1500"   "($23,895)" "', nogrid) ///
	graphregion(margin(l+4 r+4 h+8)) title("") aspect(0.50)

gr_edit yaxis1.title.DragBy 4 4
gr_edit yaxis2.title.DragBy 4 -15
graph export "$outdir/fig3/3_milk_logdur_sums_30.pdf", replace

** Alternative wage rate (Goldszmidt)
histogram_stats total_duration if total_duration < 1500, ///
	cilow(ci_low_total_duration) cihigh(ci_high_total_duration) ///
	yaxis(1 2) ///
	xtitle("Hours" "(Economic Value of Time, Revealed Preference Benchmark)") ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	ytitle("Mothers", placement(n) orient(horizontal) axis(2)) ///
	ylabel(${ypctlabs3b}, nogrid angle(horizontal) axis(1)) ///
	ylabel(${ylabs3b}, nogrid angle(horizontal) axis(2)) ///
	ylabel(, nogrid angle(horizontal)) ///
	xlabel(0 `" "0"   "($0)" "' 250 `" "250"   "($4,845)" "'  ///
		500 `" "500"   "($9,690)" "'  750 `" "750"   "($14,535)" "'  ///
		1000 `" "1000"   "($19,380)" "'   1250 `" "1250"   "($24,225)" "' ///
		1500 `" "1500"   "($29,070)" "', nogrid) ///
	graphregion(margin(l+4 r+4 h+8)) title("") aspect(0.50)

gr_edit yaxis1.title.DragBy 4 -1
gr_edit yaxis2.title.DragBy 4 -15
graph export "$apdxoutdir/3_milk_logdur_sums_30_vot.pdf", replace

* Distribution of annual milk-production hours
display "=================================================="
display "FIGURE 3: ANNUAL DURATION DISTRIBUTION (HOURS)"
display "=================================================="
summarize total_duration, detail

log close
