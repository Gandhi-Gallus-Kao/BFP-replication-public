clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig4_hist_intrsct_apdx_$sample.log", replace

if $sample == 1{
	global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
	global indir "${anadatadir}/BabyConnect/sample"
	global apdxoutdir "${BFPrep_outdir}/Subfigures/sample/appendix"
}
else {
	global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
	global indir "${anadatadir}/BabyConnect/full"
	global apdxoutdir "${BFPrep_outdir}/Subfigures/full/appendix"
}

do "$anadir/misc/label_functions.do"
do "$anadir/misc/plot_functions.do"
* Compute intersection-sample Figure 4 delta-method confidence intervals
do "$BFPrep_codedir/cleaning/prep/figure4_delta_ci.do" intersection $sample

use "$indir/figure4_analysis_data_week.dta", clear
gisid childid age_day

** Plot robustness: observed vs. predicted feeding duration
gen factual_dur = bottle_dur + nursing_dur + express_dur
gen log_total_dur = log(bottle_dur + nursing_dur)

* Common observations for predicted and observed distributions
gen byte hist_mixed = ///
    !missing(log_pred_total_actual_absorb, log_total_dur) & ///
    log_pred_total_actual_absorb >= 0 & log_total_dur >= 0

gen byte hist_pure = hist_mixed & childid_age_fe != 0

* Figure-specific sample counts
quietly count if hist_pure
di as text "Figure 4 histogram, pure sample (child-days): " ///
    as result %12.0fc r(N)

quietly count if hist_mixed
di as text "Figure 4 histogram, mixed sample (child-days): " ///
    as result %12.0fc r(N)

axis_lab_pct_simple 3 12 3 histlabs

twoway (histogram log_pred_total_actual_absorb if hist_pure, color(red%30) start(0) width(0.2) percent) ///
       (histogram log_total_dur if hist_pure, color(blue%30) start(0) width(0.2) percent), ///
       legend(off) ///
	   ytitle("Percent", placement(n) orient(horizontal) yoffset(4) xoffset(15)) ///
	   xtitle("Log Daily Feeding Minutes") ///
       xlabel(, nogrid) ///
       bgcolor(white) plotregion(style(none)) ///
       ylabel(${histlabs}, nogrid angle(horizontal)) xlabel(, nogrid) ///
	   graphregion(color(white) margin(l+2 r+2 h+8)) aspect(0.65)

graph export "$apdxoutdir/4_hist_pure.pdf", replace

twoway (histogram log_pred_total_actual_absorb if hist_mixed, color(red%30) start(0) width(0.2) percent) ///
       (histogram log_total_dur if hist_mixed, color(blue%30) start(0) width(0.2) percent), ///
       legend(off) ///
	   ytitle("Percent", placement(n) orient(horizontal) yoffset(4) xoffset(15)) ///
	   xtitle("Log Daily Feeding Minutes") ///
       xlabel(, nogrid) ///
       bgcolor(white) plotregion(style(none)) ///
       ylabel(${histlabs}, nogrid angle(horizontal)) xlabel(, nogrid) ///
	   graphregion(color(white) margin(l+2 r+2 h+8)) aspect(0.65)

graph export "$apdxoutdir/4_hist_mixed.pdf", replace


** Keep only observations with non-zero fixed effects (intersection)
keep if childid_age_fe != 0
gen time_diff_log = pred_total_cf_absorb - pred_total_actual_absorb
replace time_diff_log = 0 if missing(time_diff_log) // Accounts for only express days
gen cf_bottle_dur = nursing_dur + time_diff_log

gcollapse (sum) initial_bottle_dur = bottle_dur nursing_dur express_dur cf_bottle_dur factual_dur time_diff_log, by(childid)

******** Restriction step (applies to a, b, and c) ********
gen express_frac = express_dur / factual_dur

keep if factual_dur >= 15 * 60 // Ensures that only children with at least 15 hours of recorded feeding-related (excluding solid food) are kept
keep if express_frac < 0.90  // Ensures that only children with less than 90% time dedicated to expressed are kept

*** GRAPH (B)
gen time_saved_pct = 100*(nursing_dur + express_dur - cf_bottle_dur)/ factual_dur // Positive is saved time
gen rel_time_saved = time_diff_log / factual_dur

tabstat rel_time_saved
tabstat express_frac
tabstat time_saved_pct

gen_stats time_saved_pct
axis_lab_count 10 50 10 ylabs4b

* Load intersection-sample delta-method 95% CI
preserve
use "$indir/figure4a_analysis_intrsct_data_ci.dta", clear
local ci_low  = mean_time_saved_lo[1]
local ci_high = mean_time_saved_hi[1]
local ci_mean = mean_time_saved[1]
restore

* Check consistency with plotted mean
quietly summarize time_saved_pct
assert abs(r(mean) - `ci_mean') < 0.01

* CI endpoints for the orange mean marker
gen double ci_low_time_saved_pct  = `ci_low' if _n == 1
gen double ci_high_time_saved_pct = `ci_high' if _n == 1

histogram_stats time_saved_pct if time_saved_pct > -100 & time_saved_pct <= 100, ///
	cilow(ci_low_time_saved_pct) cihigh(ci_high_time_saved_pct) ///
	disc width(10) ///
	start(-100) ytitle("Children", placement(n) orient(horizontal) size(large)) ///
	ylabel(${ylabs4b}, nogrid labsize(large)) graphregion(margin(l-2 r+4 h+8)) ///
	xlabel(-100(50)100, nogrid labsize(large)) ///
	xtitle("Time Saved (%)", size(large))

gr_edit yaxis1.title.DragBy 5 10
graph export "$outdir/4b_histogram_save_pct_diff_log_intrsct.pdf", replace

preserve
keep if time_saved_pct > -100 & time_saved_pct <= 100

quietly count
di as text "Figure 4B intersection ordered plot (children): " ///
	as result %12.0fc r(N)

gsort time_saved_pct
gen sub_save = time_saved_pct if time_saved_pct < 0
gen sup_save = time_saved_pct if time_saved_pct >= 0
gen pct_rankorder = 100 * _n/_N

twoway area sub_save pct_rankorder, color(maroon%70) lwidth(none none none none) || ///
	area sup_save pct_rankorder, color(navy%70) lwidth(none none none none) ///
	ylabel(-100(50)100, nogrid labsize(large)) xlabel(0(10)100, nogrid labsize(large)) ///
	ytitle("Time Saved (%)", placement(n) orient(horizontal) size(large)) ///
	xtitle("Percentile (%)", size(large)) graphregion(margin(l-30 r+4 h+8)) legend(off)

gr_edit yaxis1.title.DragBy 5 33
graph export "$outdir/4b_ordered_save_pct_diff_log_intrsct.pdf", replace
restore

*** GRAPH (C) ALT
gen outsrcable_time_pct = 100*(express_dur + nursing_dur)/(nursing_dur + express_dur + initial_bottle_dur) 
// Positive is time that is Shareable
// Shareable time is defined as bottle time, and so there is an increase in bottle time (defined as cf_bottle_dur - bottle_dur)
keep if outsrcable_time_pct > 0 & outsrcable_time_pct <= 100
quietly count
di as text "Figure 4C intersection sample (children): " ///
    as result %12.0fc r(N)

di as text _newline "===== FIGURE 4C: NON-SHAREABLE TIME (%) ====="
summarize outsrcable_time_pct, detail

drop zero
gen_stats outsrcable_time_pct
axis_lab_count 10 50 10 ylabs4c
gen plt_outsrc_time_pct = cond(outsrcable_time_pct <= 10, 5, outsrcable_time_pct)
rename (*_outsrcable_time_pct) (*_plt_outsrc_time_pct)
histogram_stats plt_outsrc_time_pct, disc width(5) start(0) ///
	ytitle("Children", placement(n) orient(horizontal) size(large)) ///
	ylabel(${ylabs4c}, nogrid labsize(large)) graphregion(margin(l-2 r+4 h+8)) ///
	xtitle("Non-Shareable Time (%)", size(large)) xlabel(0(25)100, nogrid labsize(large))

gr_edit yaxis1.title.DragBy 5 10
graph export "$outdir/4c_histogram_outsrcble_pct_log_intrsct.pdf", replace


gsort outsrcable_time_pct
gen pct_rankorder = 100 * _n/_N

twoway area outsrcable_time_pct pct_rankorder, color(navy%70) lwidth(none none none none) ///
	ylabel(0(25)100, nogrid labsize(large)) xlabel(0(10)100, nogrid labsize(large)) ///
	ytitle("Non-Shareable" "Time (%)", placement(n) orient(horizontal) size(large)) ///
	xtitle("Percentile (%)", size(large)) graphregion(margin(l-20 r+4 h+8)) legend(off)

gr_edit yaxis1.title.DragBy 10 35
graph export "$outdir/4c_ordered_outsrcble_pct_log_intrsct.pdf", replace


*** GRAPH (A)
use "$indir/figure4_analysis_data_week.dta", clear
** Keep only observations with non-zero fixed effects (intersection)
keep if childid_age_fe != 0
gen time_diff_log = pred_total_cf_absorb - pred_total_actual_absorb
replace time_diff_log = 0 if missing(time_diff_log) // Accounts for only express days
gen cf_bottle_dur = nursing_dur + time_diff_log

gcollapse (sum) initial_bottle_dur = bottle_dur nursing_dur express_dur cf_bottle_dur, by(childid)

gen total_hr = (initial_bottle_dur + nursing_dur + express_dur)/60
gen express_frac = express_dur / (nursing_dur + express_dur + initial_bottle_dur)

keep if total_hr >= 15 // Ensures that only children with at least 15 hours of recorded feeding-related (excluding solid food) are kept
keep if express_frac < 0.90  // Ensures that only children with less than 90% time dedicated to expressed are kept
quietly count
di as text "Figure 4A intersection sample (children): " ///
    as result %12.0fc r(N)

keep initial_bottle_dur nursing_dur express_dur cf_bottle_dur childid
export delim "$indir/figure4a_analysis_intrsct_data.csv", replace

* Plot Figure 4A (uses the confidence intervals computed above)
python script "$anadir/figures/main/fig4a_graph.py", ///
    args("$indir" "$outdir" figure4a_analysis_intrsct_data 1)

log close
