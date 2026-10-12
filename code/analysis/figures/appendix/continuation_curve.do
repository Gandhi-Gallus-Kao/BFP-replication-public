clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/continuation_curve_$sample.log", replace

if $sample == 1{
    global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
    global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
	global indir "${anadatadir}/BabyConnect/full"
}

do "$anadir/misc/label_functions.do"

use "$anadatadir/BabyConnect/full/bc_full_sample_formatted.dta", clear
keep childid startdate starttime endtime birthdate activity duration quantity unit country formula postedbyuserid
do "$cleandir/prep/cleaning_tools.do"
do "$cleandir/prep/cont_curve_sample_restriction.do"
save "$indir/feed_full_data.dta", replace

use "$indir/figure1_analysis_feed_data.dta", clear

keep childid
duplicates drop

tempfile base_children
save `base_children', replace

*------------------------------------------------------------
* Use extended activity file, but restrict to base children
*------------------------------------------------------------
use "$indir/feed_full_data.dta", clear

merge m:1 childid using `base_children', keep(match) nogen
describe activity

* App-based evidence of breastfeeding / milk production
gen byte bf_event = inlist(activity, "Nursing":activity, "Expressed":activity)
gen byte any_event = 1

* Collapse to child-day level
gcollapse ///
    (max) bf_day = bf_event ///
    (max) any_day = any_event, ///
    by(childid age_day)

*------------------------------------------------------------
* Continuation-style curves
*------------------------------------------------------------

* Get child-level last observed app day and last breastfeeding day
gen bf_age = age_day if bf_day == 1

gcollapse ///
    (max) last_bf_day = bf_age ///
    (max) last_observed_day = age_day, ///
    by(childid)

count
display "Continuation curve sample size (children): " r(N)

* Create child-age panel from 0 to 365
expand 366
bys childid: gen age = _n - 1

* Denominator for conditional curve:
* children still observed in the app through age t
gen byte observed_through_age = ///
    (last_observed_day < . & last_observed_day >= age)

* Numerator for conditional continuation curve:
* must be observed through age t and have last BF day at/after t
gen byte continued_bf_age_cond = ///
    (observed_through_age == 1 & last_bf_day < . & last_bf_day >= age)

* Numerator for fixed-denominator lower bound:
* have last BF day at/after t, regardless of later app observation
gen byte continued_bf_age_fixed = ///
    (last_bf_day < . & last_bf_day >= age)

* Fixed baseline denominator
gen byte baseline_child = 1


gcollapse ///
    (sum) n_continued_cond = continued_bf_age_cond ///
    (sum) n_continued_fixed = continued_bf_age_fixed ///
    (sum) n_observed_through = observed_through_age ///
    (sum) n_baseline = baseline_child, ///
    by(age)

* Conditional continuation curve
gen bf_continuation = n_continued_cond / n_observed_through if n_observed_through > 0
gen bf_continuation_pct = 100 * bf_continuation

* Fixed-denominator lower-bound curve
gen bf_lower = n_continued_fixed / n_baseline if n_baseline > 0
gen bf_lower_pct = 100 * bf_lower

* Safety checks
assert bf_continuation_pct <= 100 if bf_continuation_pct < .
assert bf_lower_pct <= 100 if bf_lower_pct < .
assert bf_lower_pct <= bf_continuation_pct if bf_lower_pct < . & bf_continuation_pct < .

*------------------------------------------------------------
* Continuation-style curve
*------------------------------------------------------------
line bf_continuation_pct age if inrange(age, 0, 365), lwidth(medthick) ///
    ytitle("Percent", placement(n) orient(horizontal) axis(1) yoffset(4) xoffset(17)) ///
    graphregion(color(white)) bgcolor(white) plotregion(style(none)) ///
    color(navy%70) ///
    xtitle("Age of Child in Days") ///
    xlabel(0 90 180 270 360, nogrid) ///
    ylabel(0 "0%" 20 "20%" 40 "40%" 60 "60%" 80 "80%" 100 "100%", nogrid) ///
    graphregion(margin(l+0 r+2 h+8))

graph export "$outdir/continuation_survival_app_vs_cdc.pdf", replace

quietly summarize bf_continuation_pct if age == 180, meanonly
di "Percent of children still breastfeeding at 6 months (180 days): " %6.2f r(mean)

quietly summarize bf_continuation_pct if age == 365, meanonly
di "Percent of children still breastfeeding at 12 months (365 days): " %6.2f r(mean)
log close