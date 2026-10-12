*** Base sample restriction do file:
* Initial sample size
quietly count
local N_initial = r(N)

** Max duration restriction (12 hours = 60*12 minutes)
drop if duration > 720 & !missing(duration)

quietly count
local N_duration = r(N)

gen year = yofd(startdate)
bys childid: egen start_yr = min(year)
drop if start_yr < 2012
drop year start_yr

quietly count
local N_year = r(N)

** Generate age, drop if missing:
gen age_day = datediff_frac(birthdate, startdate, "day")
gen age_weeks = datediff_frac(birthdate, startdate, "day")/7
drop if missing(age_day) | age_day < 0
keep if age_day >=15 & age_day <= 365

quietly count
local N_age = r(N)

*** Milk production cleaning/filtering
gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
gen feeding = inlist(activity, "Nursing":activity, "Bottle":activity)
gen feeding_related = feeding | milk_producing
keep if feeding_related == 1

quietly count
local N_feeding = r(N)

*** Drop any days that have ANY formula.
bys childid startdate: egen formula_day = total(formula)
drop if formula_day > 0

quietly count
local N_formula = r(N)

*** Imputing missing values for expression:
gen amount_ml = quantity if unit == "ml":unit
replace amount_ml = 29.57 * quantity if unit == "oz":unit
recode amount_ml (min/15 = 1 "0-15 ml") (15/45 = 2 "15-45 ml") (45/75 = 3 "45-75 ml") ///
	(75/105 = 4 "75-105 ml") (105/135 = 5 "105-135 ml") (135/165 = 6 "135-165 ml") ///
	(165/195 = 7 "165-195 ml") (195/225 = 8 "195-225 ml") (225/255 = 9 "225-255 ml") ///
	(255/285 = 10 "255-285 ml")  (285/max = 11 "285+ ml") (missing = 0 "Missing"), ///
	gen(amount_bin_ml)
	
** Imputing Expression
gen expression_time = duration if activity == "Expressed":activity
winsor2 expression_time, cut(0 99)
qui reg expression_time_w i.age_day##i.amount_bin_ml
predict expression_time_pred, xb
replace duration = expression_time_pred if missing(duration) & activity == "Expressed":activity

** Imputing Nursing
gen nurse_time = duration if activity == "Nursing":activity
winsor2 nurse_time, cut(0 99)
qui reg nurse_time_w i.age_day
predict nurse_time_pred, xb
replace duration = nurse_time_pred if missing(duration) & activity == "Nursing":activity

** Imputing Bottle
gen bottle_time = duration if activity == "Bottle":activity
winsor2 bottle_time, cut(0 99)
qui reg bottle_time_w i.age_day##i.amount_bin_ml
predict bottle_time_pred, xb
replace bottle_time_pred = 0 if bottle_time_pred < 0 // Added 2/14/25
replace duration = bottle_time_pred if missing(duration) & activity == "Bottle":activity

drop amount_ml amount_bin_ml bottle_time* nurse_time* expression_time*

*** Apply 20th percentile restriction
do "$cleandir/prep/prep_milk_prod_pct_restrict_graph.do" // Produces data for graph
pct_restrict milk_producing, p(20)
drop if !milk_producing_insamp

quietly count
local N_coverage = r(N)

*** Recompute end times after imputing missing durations
drop endtime
gen double endtime = starttime + duration*60*1000
format endtime %tC
order endtime, after(starttime)

// Restricting to at least 1 (feeding related) observation in daytime
gen enddate = dofC(endtime)
gen daytime_cond1 = starttime < (Cofd(startdate) + Chms(22,0,0)) // Event started before 10 PM of startdate
gen daytime_cond2 = endtime >= (Cofd(enddate) + Chms(6,0,0)) // Event ended after 6 AM of enddate
gen daytime_all = (starttime < (Cofd(enddate) + Chms(22,0,0))) & (endtime >= (Cofd(startdate) + Chms(6,0,0))) // Event started before 10 PM of enddate and ended after 6 AM of startdate
gen daytime_ind = daytime_all & (daytime_cond1 | daytime_cond2) // Indicates that an event has some intersection with daytime (6 AM - 10 PM)
gen daytimedate = cond(daytime_cond1 & daytime_all, startdate, .) // Specifies the "date" where the daytime has nonzero intersection the event
replace daytimedate = enddate if daytime_cond2 & daytime_all // Updating for above
replace daytimedate = startdate if missing(daytimedate)
format daytimedate %td

bys childid daytimedate: egen total_daytime = total(daytime_ind)
bys childid startdate: egen min_daytime = min(total_daytime) // Ensure that any particular day has at least one daytime observation

drop if min_daytime < 1

quietly count
local N_daytime = r(N)

drop daytime* total_daytime enddate formula_day min_daytime

************************************************************
* BASE SAMPLE RESTRICTION: SAMPLE SIZE SUMMARY
************************************************************

di as text _newline "======================================================"
di as text "             BASE SAMPLE RESTRICTIONS"
di as text "======================================================"

di as text "Initial observations:           " as result %14.0fc `N_initial'
di as text "After duration restriction:     " as result %14.0fc `N_duration'
di as text "After 2012 cohort restriction:  " as result %14.0fc `N_year'
di as text "After age restriction (15-365): " as result %14.0fc `N_age'
di as text "After feeding-related filter:   " as result %14.0fc `N_feeding'
di as text "After excluding formula days:   " as result %14.0fc `N_formula'
di as text "After 20th-percentile filter:   " as result %14.0fc `N_coverage'
di as text "After daytime requirement:      " as result %14.0fc `N_daytime'

di as text "======================================================"