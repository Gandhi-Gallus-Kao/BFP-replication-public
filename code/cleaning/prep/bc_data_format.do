clear
set more off, perm
est clear

do "$BFPrep_codedir/make_globals.do"

log using "$logdir/bc_data_format.log", replace
use "$interdir/BabyConnect/bc_full_cleaned.dta", clear
drop extradata
recast str activity

foreach v of varlist genderbg lang countrycode activity unit{
	encode `v', gen(new`v')
	cap label drop `v'
	drop `v'
	rename new`v' `v'
	label copy new`v' `v'
	ds, has(vallabel new`v')
	label values `r(varlist)' `v'
	label drop new`v'
}

generate baby_age_month = datediff_frac(birthdate, startdate, "month")

recode baby_age_month (min/0 = 0 "Negative") (0/0.5 = 1 "<2 weeks") (0.5/3 = 2 "<3 months") (3/6 = 3 "3-6 months") (6/12 = 4 "6-12 months") (12/24 = 5 "12-24 months") (24/max = 6 ">24 months"), gen(age_cohort)
replace baby_age_month = 1 if baby_age_month == 0
duplicates drop
qui compress
save "$anadatadir/BabyConnect/full/bc_full_sample_formatted.dta", replace

log close
