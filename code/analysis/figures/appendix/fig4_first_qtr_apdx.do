clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig4_first_qtr_apdx_$sample.log", replace

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
* Compute first-quarter Figure 4 delta-method confidence intervals
do "$BFPrep_codedir/cleaning/prep/figure4_delta_ci.do" first_quarter $sample

use "$indir/figure4_analysis_data_week.dta", clear

** Generate statistic on the amount of expression quantity for the age_day between 15 and 90 and the quantity for age_day between 90 and 365
preserve
gen factual_dur = (bottle_dur + nursing_dur + express_dur)
gcollapse (sum) express_dur factual_dur, by(childid age_day)
gen age_day_group = cond(age_day <= 90, 1, 2)
gen express_frac = express_dur / factual_dur
gcollapse (mean) express_frac (median) med_express_frac = express_frac, by(childid age_day_group)
summarize express_frac if age_day_group == 1, detail
summarize express_frac if age_day_group == 2, detail

summarize med_express_frac if age_day_group == 1, detail
summarize med_express_frac if age_day_group == 2, detail
restore

drop if age_day > 90
gen factual_dur = (bottle_dur + nursing_dur + express_dur)

gen time_diff_log = pred_total_cf_absorb - pred_total_actual_absorb
replace time_diff_log = 0 if missing(time_diff_log) // Accounts for only express days
gen cf_bottle_dur = nursing_dur + time_diff_log
gcollapse (sum) initial_bottle_dur = bottle_dur nursing_dur express_dur cf_bottle_dur factual_dur time_diff_log, by(childid)

******** Restriction step (applies to a, b, and c) ********
gen express_frac = express_dur / factual_dur

keep if factual_dur >= 15 * 60 // Ensures that only children with at least 5 hours of recorded feeding-related (excluding solid food) are kept
keep if express_frac < 0.90  // Ensures that only children with less than 90% time dedicated to expressed are kept

*** GRAPH (B) + GRAPH (B) ALT
gen time_saved_pct = 100*(nursing_dur + express_dur - cf_bottle_dur)/ factual_dur // Positive is saved time
gen rel_time_saved = time_diff_log / factual_dur

tabstat rel_time_saved
tabstat express_frac
tabstat time_saved_pct

gen_stats time_saved_pct
axis_lab_count 10 50 10 ylabs4b

* Load first-quarter delta-method 95% CI
preserve
use "$indir/figure4a_first_quarter_data_ci.dta", clear
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
graph export "$outdir/4b_histogram_save_pct_diff_log_first_quarter.pdf", replace

sum time_saved_pct, detail

preserve
keep if time_saved_pct > -100 & time_saved_pct <= 100
count
display "Figure 4B first-quarter sample size (children): " r(N)
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
graph export "$outdir/4b_ordered_save_pct_diff_log_first_quarter.pdf", replace
restore

*** GRAPH (C) ALT
gen outsrcable_time_pct = 100*(express_dur + nursing_dur)/(nursing_dur + express_dur + initial_bottle_dur) 
// Positive is time that is Shareable
// Shareable time is defined as bottle time, and so there is an increase in bottle time (defined as cf_bottle_dur - bottle_dur)
keep if outsrcable_time_pct > 0 & outsrcable_time_pct <= 100

count
display "Figure 4C first-quarter sample size (children): " r(N)

drop zero
gen_stats outsrcable_time_pct
axis_lab_count 10 50 10 ylabs4c
gen plt_outsrc_time_pct = cond(outsrcable_time_pct <= 10, 5, outsrcable_time_pct) // Doesn't affect accuracy, but simply aesthetics
rename (*_outsrcable_time_pct) (*_plt_outsrc_time_pct)
histogram_stats plt_outsrc_time_pct, disc width(5) start(0) ///
	ytitle("Children", placement(n) orient(horizontal) size(large)) ///
	ylabel(${ylabs4c}, nogrid labsize(large)) graphregion(margin(l-2 r+4 h+8)) ///
	xtitle("Non-Shareable Time (%)", size(large)) xlabel(0(25)100, nogrid labsize(large))

gr_edit yaxis1.title.DragBy 5 10
graph export "$outdir/4c_histogram_outsrcble_pct_log_first_quarter.pdf", replace

sum outsrcable_time_pct, detail

gsort outsrcable_time_pct
gen pct_rankorder = 100 * _n/_N

twoway area outsrcable_time_pct pct_rankorder, color(navy%70) lwidth(none none none none) ///
	ylabel(0(25)100, nogrid labsize(large)) xlabel(0(10)100, nogrid labsize(large)) ///
	ytitle("Non-Shareable" "Time (%)", placement(n) orient(horizontal) size(large)) ///
	xtitle("Percentile (%)", size(large)) graphregion(margin(l-20 r+4 h+8)) legend(off)
	
gr_edit yaxis1.title.DragBy 10 35
graph export "$outdir/4c_ordered_outsrcble_pct_log_first_quarter.pdf", replace
sum outsrcable_time_pct, detail

*** GRAPH (A)
use "$indir/figure4_analysis_data_week.dta", clear
drop if age_day > 90  
gen time_diff_log = pred_total_cf_absorb - pred_total_actual_absorb
replace time_diff_log = 0 if missing(time_diff_log) // Accounts for only express days
gen cf_bottle_dur = nursing_dur + time_diff_log

gcollapse (sum) initial_bottle_dur = bottle_dur nursing_dur express_dur cf_bottle_dur, by(childid)

gen total_hr = (initial_bottle_dur + nursing_dur + express_dur)/60
gen express_frac = express_dur / (nursing_dur + express_dur + initial_bottle_dur)

keep if total_hr >= 15 // Ensures that only children with at least 15 hours of recorded feeding-related (excluding solid food) are kept
keep if express_frac < 0.90  // Ensures that only children with less than 90% time dedicated to expressed are kept
count
display "Figure 4A first-quarter sample size (children): " r(N)

keep initial_bottle_dur nursing_dur express_dur cf_bottle_dur childid

* Define dataset name for flexibility
local dataset_name "figure4a_first_quarter_data"

if $sample == 1 {
    local dataset_name "`dataset_name'_sample"
}

export delim "$indir/`dataset_name'.csv", replace

python script "$anadir/figures/main/fig4a_graph.py", args("$indir" "$outdir" "`dataset_name'" 1)
log close
