clear
set more off, perm
est clear
clear frames

cap log close

do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig23_feed_prep_$sample.log", replace

if $sample == 1{
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
	global indir "${anadatadir}/BabyConnect/full"
}

use "$indir/figure123_analysis_feed_data.dta", clear

gcollapse (sum) duration, by(childid age_day)
bysort childid: gen day_obs_count = _N

**** Duration (Log): 30
drop if day_obs_count < 30

gen logdur = log(duration)
qui reghdfe logdur i.age_day, a(childid) vce(cluster childid) resid

* Feed appendix regression sample size
count if e(sample)
display "Feed appendix Figure 2 sample size (child-days): " r(N)

egen fig2_feed_child_tag = tag(childid) if e(sample)
count if fig2_feed_child_tag
display "Feed appendix Figure 2 sample size (children): " r(N)
drop fig2_feed_child_tag

margins i.age_day
matrix v = r(b)

forvalues i = 1/351 {
	matrix v[1,`i']= exp(v[1,`i'])
}

matrix tran_v = v'
matrix V = r(V)
matrix var_cov = diag(v)' * V * diag(v)

* Daily variances, used for daily confidence intervals
matrix dur_var = vecdiag(var_cov)'

* Delta-method variance of the SUM of all daily fitted values
matrix ones = J(rowsof(var_cov), 1, 1)
matrix total_profile_var = ones' * var_cov * ones
scalar total_profile_se = sqrt(total_profile_var[1,1])

* Point estimate corresponding to that sum
matrix total_profile_mean_mat = v * ones
scalar total_profile_mean = total_profile_mean_mat[1,1]

display "Number of daily margins: " rowsof(var_cov)
display "Sum of daily fitted values (minutes): " scalar(total_profile_mean)
display "SE of sum of daily fitted values: " scalar(total_profile_se)

// Store regression results and delta-method quantities
preserve
clear
svmat double dur_var, name(pred_var)
svmat double tran_v, name(pred_logdur)

gen pred_se = sqrt(pred_var)
gen age = _n + 14 if !missing(pred_logdur)
gen low = pred_logdur  - 1.96 * pred_se if !missing(pred_logdur)
gen hi = pred_logdur  + 1.96 * pred_se if !missing(pred_logdur)

* Annual-profile quantities for subsequent delta-method CI
gen total_profile_mean = scalar(total_profile_mean)
gen total_profile_se   = scalar(total_profile_se)

save "$indir/fig23_feed_regression_results.dta", replace
restore

* Annual feeding duration
preserve
gcollapse (sum) duration, by(childid)
quietly summarize duration
display "Mean annual feeding duration (minutes): " %12.2f r(mean)
restore

// Prediction results for histogram
predict duration_actual, xbd
predict absorb_actual, d

keep if e(sample)==1
xtset childid age_day
tsfill, full
bys childid (absorb_actual): replace absorb_actual = absorb_actual[1]

predict duration_pred_counterfactual, xb
replace duration_pred_counterfactual = duration_pred_counterfactual + absorb_actual

gen pred_dur_exp = exp(duration_pred_counterfactual)
gcollapse (sum) total_duration = pred_dur_exp, by(childid)

* Compare child-level annual total against fitted daily profile
summarize total_duration
display "Mean predicted annual total (minutes): " r(mean)
display "Annual fitted profile (minutes): " scalar(total_profile_mean)
display "Ratio child-level / fitted profile: " ///
    r(mean) / scalar(total_profile_mean)

replace total_duration = total_duration / 60

* Figure 3 feeding appendix sample sizes
count
display "Feed Figure 3 full prediction sample (children): " r(N)

count if total_duration < 1500
display "Feed Figure 3 displayed sample (children): " r(N)

save "$indir/fig23_feed_prediction_results.dta", replace

log close
