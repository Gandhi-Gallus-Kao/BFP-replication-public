use "$outdir/figure4_base_data.dta", clear
drop age_weeks
gen age_weeks = ceil(age_day / 7)
merge m:1 childid age_weeks using "$outdir/childid_age_fe.dta", keep(1 3)
replace childid_age_fe = 0 if missing(childid_age_fe)

gen dayofweek = dow(startdate) + 1
gen day_within_ageweek = mod(age_day - 1, 7) + 1
gen total_feeding_events = 1

gen nursing_dur = duration * (activity == "Nursing":activity)
gen express_dur = duration * (activity == "Expressed":activity)
gen bottle_dur = duration * (activity == "Bottle":activity)

gcollapse (sum) bottle_dur nursing_dur express_dur total_feeding_events (firstnm) age_weeks dayofweek day_within_ageweek childid_age_fe, by(childid age_day)
replace total_feeding_events = 20 if total_feeding_events > 20

** Regression: time = b_0 + b_1 * bottle_share + \sum_w b_2w * 1_w * bottle_share + FE
gen share_bottle_time = bottle_dur / (bottle_dur + nursing_dur)

est use "$outdir/logcoef_all.ster"
predict log_pred_total_actual_absorb, xb
replace log_pred_total_actual_absorb = log_pred_total_actual_absorb + childid_age_fe
rename share_bottle_time factual_share_bottle_time
gen share_bottle_time = 1
predict log_pred_total_cf_absorb, xb
replace log_pred_total_cf_absorb = log_pred_total_cf_absorb + childid_age_fe
drop share_bottle_time
rename factual_share_bottle_time share_bottle_time 

gen pred_total_actual_absorb = exp(log_pred_total_actual_absorb)
gen pred_total_cf_absorb = exp(log_pred_total_cf_absorb)

recode age_day (0/90 = 1 "<90 days") (91/180 = 2 "91 - 180 days") (181/365 = 3 "181 - 365 days") (else = 9), gen(age_cohort)

* Robustness to conversion/imputation strength, varying the share of predicted counterfactual effect. 
gen log_cf_effect = log_pred_total_cf_absorb - log_pred_total_actual_absorb

foreach pct in 80 90 100 110 120 {
    local scale = `pct' / 100

    gen log_pred_total_cf_conv`pct' = ///
        log_pred_total_actual_absorb + `scale' * log_cf_effect

    gen pred_total_cf_conv`pct' = exp(log_pred_total_cf_conv`pct')
}