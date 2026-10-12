clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0

log using "$logdir/fig23_balanced_apdx_$sample.log", replace

if $sample == 1{
    global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
    global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
	global indir "${anadatadir}/BabyConnect/full"
}

***** DURATION
do "$anadir/misc/label_functions.do"
do "$anadir/misc/plot_functions.do"

// Load margins results for first graph
use "$indir/fig23_balanced_apdx_regression_results.dta", clear
* Annual-profile delta-method quantities
quietly summarize total_profile_mean, meanonly
local profile_total_min = r(mean)

quietly summarize total_profile_se, meanonly
local profile_total_se = r(mean)

// First graph: margins plot
twoway rarea low hi age, color(navy%70) || ///
	line pred_logdur age, graphregion(color(white)) bgcolor(white) plotregion(style(none)) ///
	xlabel(0(30)365, nogrid) xtitle("Age of Child in Days") ylabel(0(30)180, ///
	nogrid angle(horizontal)) color(navy) ///
	ytitle("Minutes per Day", placement(n) ///
	orient(horizontal)) ysc(titlegap(-10) outergap(0)) ///
	graphregion(margin(l+4 r+4 h+8)) title("") legend(off) aspect(0.55)
gr_edit yaxis1.title.DragBy 4 10
graph export "$outdir/2_milk_logdur_margins_30_full.pdf", replace

// Load prediction results for second graph
use "$indir/fig23_balanced_apdx_prediction_results.dta", clear

* Annual duration and delta-method confidence interval
quietly summarize total_duration, meanonly
local annual_mean_min = 60 * r(mean)

local annual_se_min = ///
    (`annual_mean_min' / `profile_total_min') * `profile_total_se'

local annual_lo_min = `annual_mean_min' - 1.96 * `annual_se_min'
local annual_hi_min = `annual_mean_min' + 1.96 * `annual_se_min'

display "=========================================="
display "BALANCED-PANEL APPENDIX: ANNUAL DURATION"
display "=========================================="
display "Mean (minutes): " %12.2f `annual_mean_min'
display "SE (minutes): " %12.4f `annual_se_min'
display "95% CI (minutes): [" ///
    %12.2f `annual_lo_min' ", " %12.2f `annual_hi_min' "]"

count if total_duration < 1500
display "Figure 3 balanced-panel sample size (children): " r(N)

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

* 95% CI for mean annual duration (convert minutes to hours)
gen double ci_low_total_duration  = `annual_lo_min' / 60 if _n == 1
gen double ci_high_total_duration = `annual_hi_min' / 60 if _n == 1

// Second graph: histogram
histogram_stats total_duration if total_duration < 1500, ///
	cilow(ci_low_total_duration) cihigh(ci_high_total_duration) ///
	yaxis(1 2) ///
	xtitle("Hours" "(Economic Value of Time at Median Wage)") ///
	ytitle("Percent", placement(n) orient(horizontal) axis(1)) ///
	ytitle("Children", placement(n) orient(horizontal) axis(2)) ///
	ylabel(${ypctlabs3b}, nogrid angle(horizontal) axis(1)) ///
	ylabel(${ylabs3b}, nogrid angle(horizontal) axis(2)) ///
	ylabel(, nogrid angle(horizontal)) ///
	xlabel(0 `" "0"   "($0)" "' 250 `" "250"   "($3,983)" "'  ///
		500 `" "500"   "($7,965)" "'  750 `" "750"   "($11,948)" "'  ///
		1000 `" "1000"   "($15,930)" "'   1250 `" "1250"   "($19,913)" "' ///
		1500 `" "1500"   "($23,895)" "', nogrid) ///
	graphregion(margin(l+4 r+4 h+8)) title("") aspect(0.50)

gr_edit yaxis1.title.DragBy 4 -1
gr_edit yaxis2.title.DragBy 4 -15
graph export "$outdir/3_milk_logdur_sums_30_full.pdf", replace

log close
