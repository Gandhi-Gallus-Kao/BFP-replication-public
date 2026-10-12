********************************************************************************
* FIGURE 4 DELTA-METHOD CONFIDENCE INTERVALS
*
* Propagates uncertainty in the estimated age-week bottle-share conversion
* coefficients into the Figure 4A counterfactual quantities.
********************************************************************************

clear
set more off, perm
est clear
clear frames

* make_globals.do resets $outdir to the top-level output directory. This file is
* also called from figure-generating scripts (fig4_graphs.do, fig4_first_qtr_apdx.do,
* fig4_hist_intrsct_apdx.do) that rely on their own $outdir afterwards (e.g., for
* fig4a_graph.py), so preserve the caller's value across the call.
local caller_outdir `"$outdir"'
do "$BFPrep_codedir/make_globals.do"
if `"`caller_outdir'"' != "" {
    global outdir `"`caller_outdir'"'
}

****************************************************************************
* ARGUMENTS
*
* spec:
*   main
*   first_quarter
*   intersection
*
* sample:
*   0 = full sample
*   1 = development subsample (not included in this package)
****************************************************************************

args spec sample_arg

* Defaults if run without arguments
if "`spec'" == "" {
    local spec "main"
}

if "`sample_arg'" == "" {
    local sample_arg 0
}

global sample `sample_arg'


* Check specification name
if !inlist("`spec'", "main", "first_quarter", "intersection") {
    di as error "spec must be main, first_quarter, or intersection"
    exit 198
}

if $sample == 1 {
    local ci_datadir "${anadatadir}/BabyConnect/sample"
}
else {
    local ci_datadir "${anadatadir}/BabyConnect/full"
}

********************************************************************************
* LOAD FIXED FIGURE 4 APPLICATION DATA
********************************************************************************

use "`ci_datadir'/figure4_analysis_data_week.dta", clear

********************************************************************************
* LOAD ORIGINAL CONVERSION REGRESSION
*
* IMPORTANT: this must be the same regression used to generate the
* Figure 4 predictions above.
********************************************************************************

est use "`ci_datadir'/logcoef_all.ster"
matrix conversion_b = e(b)
matrix conversion_V = e(V)
scalar conversion_df_r = e(df_r)

di ""
di "============================================================"
di "CONVERSION REGRESSION COEFFICIENTS"
di "============================================================"

matrix list conversion_b

****************************************************************************
* SPECIFICATION-SPECIFIC RESTRICTIONS
****************************************************************************

local min_hours 15


if "`spec'" == "main" {
    local output_name "figure4a_analysis_data_ci"

}

else if "`spec'" == "first_quarter" {
    drop if age_day > 90
    local output_name "figure4a_first_quarter_data_ci"

}

else if "`spec'" == "intersection" {
    keep if childid_age_fe != 0
    local output_name "figure4a_analysis_intrsct_data_ci"

}

********************************************************************************
* RECONSTRUCT FIGURE 4A POINT ESTIMATE
********************************************************************************

gen factual_dur = ///
    bottle_dur + nursing_dur + express_dur


gen time_diff = ///
    pred_total_cf_absorb - pred_total_actual_absorb

replace time_diff = 0 ///
    if missing(time_diff)


gen cf_bottle_dur = ///
    nursing_dur + time_diff


********************************************************************************
* IDENTIFY CHILDREN INCLUDED IN FIGURE 4A
*
* Same restrictions as existing Figure 4A code:
*   - at least 15 hours of factual feeding time
*   - less than 90% expressed
********************************************************************************

bysort childid: egen child_factual_dur = ///
    total(factual_dur)

bysort childid: egen child_express_dur = ///
    total(express_dur)


gen child_express_frac = ///
    child_express_dur / child_factual_dur


****************************************************************************
* FIGURE 4B: MEAN TIME SAVED
*
* Child-weighted mean of each child's percentage change.
****************************************************************************

preserve

* Apply Figure 4B sample restriction
keep if child_factual_dur >= `min_hours' * 60
keep if child_express_frac < 0.90


****************************************************************************
* FIGURE 4B POINT ESTIMATE
****************************************************************************

bysort childid: egen child_nursing_dur = ///
    total(nursing_dur)

bysort childid: egen child_cf_bottle_dur = ///
    total(cf_bottle_dur)

gen child_time_saved_pct = ///
    100 * ///
    (child_nursing_dur + child_express_dur - child_cf_bottle_dur) ///
    / child_factual_dur


* One observation per child for calculating the mean
egen byte child_tag = tag(childid)

quietly summarize child_time_saved_pct if child_tag, meanonly
scalar mean_time_saved = r(mean)

quietly count if child_tag
scalar n_children_b = r(N)


****************************************************************************
* FIGURE 4B DELTA-METHOD GRADIENT
*
* For a given child, an increase in beta_w raises counterfactual
* duration and therefore lowers time saved.
****************************************************************************

gen derivative_component_b = ///
    pred_total_cf_absorb * ///
    (1 - share_bottle_time)

replace derivative_component_b = 0 ///
    if missing(derivative_component_b)


* Contribution to derivative of child-level time_saved_pct
gen gradient_component_mean = ///
    -100 * derivative_component_b / child_factual_dur


* Sum contributions within each age week
collapse ///
    (sum) gradient_component_mean, ///
    by(age_weeks)


* Mean across children
gen gradient_mean = ///
    gradient_component_mean / n_children_b


****************************************************************************
* CONSTRUCT GRADIENT VECTOR MATCHING e(V)
****************************************************************************

matrix G_mean = J(1, colsof(conversion_V), 0)

quietly count
local n_weeks_b = r(N)

forvalues i = 1/`n_weeks_b' {

    local week = age_weeks[`i']

    local coefname ///
        "`week'.age_weeks#c.share_bottle_time"

    local col = ///
        colnumb(conversion_V, "`coefname'")

    if missing(`col') {

        di as error ///
            "WARNING: coefficient not found: `coefname'"

    }

    else {

        scalar temp_gradient = gradient_mean[`i']

        matrix G_mean[1, `col'] = temp_gradient

    }
}


****************************************************************************
* FIGURE 4B DELTA-METHOD SE AND 95% CI
****************************************************************************

matrix mean_delta_variance = ///
    G_mean * conversion_V * G_mean'

scalar mean_time_saved_var = ///
    mean_delta_variance[1,1]

scalar mean_time_saved_se = ///
    sqrt(mean_time_saved_var)

scalar mean_time_saved_critical = ///
    invttail(conversion_df_r, 0.025)

scalar mean_time_saved_lo = ///
    mean_time_saved - mean_time_saved_critical * mean_time_saved_se

scalar mean_time_saved_hi = ///
    mean_time_saved + mean_time_saved_critical * mean_time_saved_se


di ""
di "FIGURE 4B MEAN TIME SAVED"
di "Estimate = " mean_time_saved
di "SE       = " mean_time_saved_se
di "95% CI   = [" mean_time_saved_lo ", " mean_time_saved_hi "]"

restore

* Apply Figure 4A sample restriction
keep if child_factual_dur >= `min_hours' * 60
keep if child_express_frac < 0.90


********************************************************************************
* FIGURE 4A POINT ESTIMATE
********************************************************************************

quietly summarize factual_dur, meanonly
scalar total_factual = r(sum)


gen cf_total_component = ///
    bottle_dur + cf_bottle_dur


quietly summarize cf_total_component, meanonly
scalar total_counterfactual = r(sum)


scalar cf_frac = ///
    100 * total_counterfactual / total_factual


scalar cf_saved = ///
    100 - cf_frac


di ""
di "============================================================"
di "FIGURE 4A POINT ESTIMATE"
di "============================================================"

di "Counterfactual total (% factual hours): " cf_frac
di "Time saved (% factual hours):           " cf_saved


********************************************************************************
* DELTA-METHOD GRADIENT
*
* For observation i in age week w:
*
*     log counterfactual effect
*          = beta_w * (1 - factual bottle share_i)
*
* Holding the factual prediction fixed:
*
*     d(predicted CF duration) / d(beta_w)
*          = pred_total_cf_absorb_i
*            * (1 - share_bottle_time_i)
*
* Therefore:
*
*     d(cf_frac) / d(beta_w)
*          = 100 / total_factual
*            * sum_i [
*                pred_total_cf_absorb_i
*                * (1 - share_bottle_time_i)
*              ]
*
* where the sum is over observations in age week w.
********************************************************************************

gen derivative_component = ///
    pred_total_cf_absorb * ///
    (1 - share_bottle_time)


* Express-only observations have no nursing/bottle conversion effect
replace derivative_component = 0 ///
    if missing(derivative_component)


collapse ///
    (sum) derivative_component, ///
    by(age_weeks)


gen gradient_cf = ///
    100 * derivative_component / total_factual


********************************************************************************
* CONSTRUCT GRADIENT VECTOR MATCHING e(V)
*
* Most coefficients in the regression have derivative zero.
* Only:
*
*     #.age_weeks#c.share_bottle_time
*
* contribute to the Figure 4 conversion effect.
********************************************************************************

matrix G = J(1, colsof(conversion_V), 0)


quietly count
local n_weeks = r(N)


forvalues i = 1/`n_weeks' {

    local week = age_weeks[`i']

    local coefname ///
        "`week'.age_weeks#c.share_bottle_time"

    local col = ///
        colnumb(conversion_V, "`coefname'")


    if missing(`col') {

        di as error ///
            "WARNING: coefficient not found: `coefname'"

    }

    else {

        scalar temp_gradient = gradient_cf[`i']

        matrix G[1, `col'] = temp_gradient

    }

}


********************************************************************************
* DELTA-METHOD VARIANCE
*
* Var[g(beta)] = G V G'
********************************************************************************

matrix delta_variance = ///
    G * conversion_V * G'


scalar cf_var = ///
    delta_variance[1,1]

scalar cf_se = ///
    sqrt(cf_var)


********************************************************************************
* 95% CONFIDENCE INTERVAL
*
* Use the regression residual degrees of freedom when available.
********************************************************************************

scalar critical_value = ///
    invttail(conversion_df_r, 0.025)

scalar cf_frac_lo = ///
    cf_frac - critical_value * cf_se

scalar cf_frac_hi = ///
    cf_frac + critical_value * cf_se


********************************************************************************
* DERIVED FIGURE 4A QUANTITIES
********************************************************************************

* Time saved = 100 - counterfactual total
scalar cf_saved_lo = ///
    100 - cf_frac_hi

scalar cf_saved_hi = ///
    100 - cf_frac_lo


* Even split: mother gets 50%
scalar mother_even = ///
    0.50 * cf_frac

scalar mother_even_lo = ///
    0.50 * cf_frac_lo

scalar mother_even_hi = ///
    0.50 * cf_frac_hi


* Literature split
local mother_share_lit = 7.69 / (7.69 + 3.17)

scalar mother_29 = ///
    `mother_share_lit' * cf_frac

scalar mother_29_lo = ///
    `mother_share_lit' * cf_frac_lo

scalar mother_29_hi = ///
    `mother_share_lit' * cf_frac_hi


* ATUS split: partner = 36%, mother = 64%
scalar mother_36 = ///
    0.64 * cf_frac

scalar mother_36_lo = ///
    0.64 * cf_frac_lo

scalar mother_36_hi = ///
    0.64 * cf_frac_hi


********************************************************************************
* DISPLAY RESULTS
********************************************************************************

di ""
di "============================================================"
di "FIGURE 4A: DELTA-METHOD 95% CONFIDENCE INTERVALS"
di "============================================================"

di ""
di "Counterfactual total:"
di "Estimate = " cf_frac
di "SE       = " cf_se
di "95% CI   = [" cf_frac_lo ", " cf_frac_hi "]"

di ""
di "Time saved:"
di "Estimate = " cf_saved
di "95% CI   = [" cf_saved_lo ", " cf_saved_hi "]"

di ""
di "Mother time -- Even split:"
di "Estimate = " mother_even
di "95% CI   = [" mother_even_lo ", " mother_even_hi "]"

di ""
di "Mother time -- Literature split (29% partner):"
di "Estimate = " mother_29
di "95% CI   = [" mother_29_lo ", " mother_29_hi "]"

di ""
di "Mother time -- ATUS split (36% partner):"
di "Estimate = " mother_36
di "95% CI   = [" mother_36_lo ", " mother_36_hi "]"

di ""
di "============================================================"


********************************************************************************
* SAVE RESULTS
********************************************************************************

clear
set obs 1

gen cf_frac = cf_frac
gen cf_frac_se = cf_se
gen cf_frac_lo = cf_frac_lo
gen cf_frac_hi = cf_frac_hi

gen cf_saved = cf_saved
gen cf_saved_lo = cf_saved_lo
gen cf_saved_hi = cf_saved_hi

gen mother_even = mother_even
gen mother_even_lo = mother_even_lo
gen mother_even_hi = mother_even_hi

gen mother_29 = mother_29
gen mother_29_lo = mother_29_lo
gen mother_29_hi = mother_29_hi

gen mother_36 = mother_36
gen mother_36_lo = mother_36_lo
gen mother_36_hi = mother_36_hi

gen mean_time_saved = mean_time_saved
gen mean_time_saved_se = mean_time_saved_se
gen mean_time_saved_lo = mean_time_saved_lo
gen mean_time_saved_hi = mean_time_saved_hi

save "`ci_datadir'/`output_name'.dta", replace

export delimited ///
    using "`ci_datadir'/`output_name'.csv", ///
    replace