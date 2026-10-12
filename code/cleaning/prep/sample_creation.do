clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"
do "$cleandir/prep/cleaning_tools.do"

global sample = 0
log using "$logdir/sample_creation_$sample.log", replace

if $sample == 1{
    use "$anadatadir/BabyConnect/sample/bc_sub_sample_formatted.dta", clear
    global outdir "${anadatadir}/BabyConnect/sample"
}
else {
    use "$anadatadir/BabyConnect/full/bc_full_sample_formatted.dta", clear
    global outdir "${anadatadir}/BabyConnect/full"
}

keep childid startdate starttime endtime birthdate activity duration quantity unit country formula postedbyuserid
frames copy default figure123_sample
frames copy default figure123_feed_sample
frames copy default figure123_nurse_only_sample
frames change figure123_sample

quietly count
display "Initial sample observations: " %14.0fc r(N)

do "$cleandir/prep/base_sample_restriction.do"
sum age_day
preserve
keep if age_day <= 365
save "$outdir/figure4_base_data.dta", replace
restore

keep if milk_producing == 1
keep if age_day <= 365
save "$outdir/figure23_analysis_data.dta", replace
save "$outdir/figure1_cohort_analysis_data.dta", replace

global day_start = 6
global day_end = 22
preserve
do "$cleandir/prep/feeding_partition_generic.do"
do "$cleandir/prep/daytime_nighttime_generic.do"
gen date = dofC(starttime)
format date %td
save "$outdir/figure1cd_cohort_analysis_data.dta", replace
restore

keep if age_day <= 90
save "$outdir/figure1_analysis_data.dta", replace

global day_start = 6
global day_end = 22
preserve
do "$cleandir/prep/feeding_partition_generic.do"
do "$cleandir/prep/daytime_nighttime_generic.do"
save "$outdir/figure1cd_analysis_data.dta", replace
restore

global day_start = 8
global day_end = 20
preserve
do "$cleandir/prep/feeding_partition_generic.do"
do "$cleandir/prep/daytime_nighttime_generic.do"
save "$outdir/figure1cd_analysis_data_8_8.dta", replace
restore

frames copy default figure4_sample
frames change figure4_sample

** Two parts -- restriction + counterfactual generation
do "$cleandir/prep/conversion_sample_restriction.do" 
do "$cleandir/prep/conversion_estimation.do"
do "$cleandir/prep/conversion_imputation.do"
save "$outdir/figure4_analysis_data_week.dta", replace

** Generate appendix version
frames change figure123_feed_sample
cap frames drop figure123_sample
cap frames drop figure4_sample

do "$cleandir/prep/feed_sample_restriction.do"

keep if age_day <= 365
save "$outdir/figure123_analysis_feed_data.dta", replace

keep if age_day <= 90
save "$outdir/figure1_analysis_feed_data.dta", replace

global day_start = 6
global day_end = 22
preserve
do "$cleandir/prep/feeding_partition_generic.do"
do "$cleandir/prep/daytime_nighttime_generic.do"
save "$outdir/figure1cd_analysis_feed_data.dta", replace
restore

frames change figure123_nurse_only_sample
cap frames drop figure123_feed_sample figure123_sample

do "$cleandir/prep/nurse_only_sample_restriction.do"

keep if age_day <= 365
keep if age_day <= 90
save "$outdir/figure1_analysis_nurse_only_data.dta", replace

global day_start = 6
global day_end = 22
preserve
do "$cleandir/prep/feeding_partition_generic.do"
do "$cleandir/prep/daytime_nighttime_generic.do"
save "$outdir/figure1cd_analysis_nurse_only_data.dta", replace
restore

log close
