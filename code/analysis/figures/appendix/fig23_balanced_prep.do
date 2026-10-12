clear
set more off, perm
est clear
clear frames

cap log close

do "$BFPrep_codedir/make_globals.do"

global sample = 0

log using "$logdir/fig23_balanced_prep_$sample.log", replace

if $sample == 1{
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
	global indir "${anadatadir}/BabyConnect/full"
}

use "$indir/figure23_analysis_data.dta", clear
gcollapse (sum) duration, by(childid age_day)
bysort childid: gen day_obs_count = _N

**** Duration (Log): 30
drop if day_obs_count < 30

* Number of children with at least 30 observed days
quietly gdistinct childid
display "Children with >=30 observed days: " r(ndistinct)

* Restrict to children with at least 351 observed days
drop if day_obs_count < 351

quietly gdistinct childid
display "Children with >=351 observed days: " r(ndistinct)

gen logdur = log(duration)
qui reghdfe logdur i.age_day, a(childid) vce(cluster childid) resid

// Save margins results for first graph
margins i.age_day
matrix v = r(b)

forvalues i = 1/351 {
	matrix v[1,`i']= exp(v[1,`i'])
}

matrix tran_v = v'
matrix V = r(V)
matrix var_cov = diag(v)' * V * diag(v)
matrix dur_var = vecdiag(var_cov)' // ??

* Delta-method variance of the sum of daily fitted values
matrix ones = J(rowsof(var_cov), 1, 1)
matrix total_profile_var = ones' * var_cov * ones
scalar total_profile_se = sqrt(total_profile_var[1,1])

matrix total_profile_mean_mat = v * ones
scalar total_profile_mean = total_profile_mean_mat[1,1]

// Store margins results
preserve
clear
svmat double dur_var, name(pred_var)
svmat double tran_v, name(pred_logdur)

gen pred_se = sqrt(pred_var)
gen age = _n + 14 if !missing(pred_logdur)
gen low = pred_logdur  - 1.96 * pred_se if !missing(pred_logdur)
gen hi = pred_logdur  + 1.96 * pred_se if !missing(pred_logdur)

gen total_profile_mean = scalar(total_profile_mean)
gen total_profile_se = scalar(total_profile_se)

save "$indir/fig23_balanced_apdx_regression_results.dta", replace
restore

// Prediction results for second graph
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

replace total_duration = total_duration / 60

save "$indir/fig23_balanced_apdx_prediction_results.dta", replace

log close
