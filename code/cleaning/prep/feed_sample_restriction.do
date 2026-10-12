*** Sample restriction do file

** Min duration restriction (durationmin of negatives and 0s)
drop if duration < 1 & !missing(duration)

** Max duration restriction (12 hours = 60*12 minutes)
drop if duration > 720 & !missing(duration)

gen year = yofd(startdate)
bys childid: egen start_yr = min(year)
drop if start_yr < 2012
drop year start_yr


** Generate age, drop if missing:
gen age_day = datediff_frac(birthdate, startdate, "day")
gen age_weeks = datediff_frac(birthdate, startdate, "day")/7
drop if missing(age_day) | age_day < 0
keep if age_day >=15 & age_day <= 365

*** Milk production cleaning/filtering
gen milk_producing = inlist(activity, "Nursing":activity, "Expressed":activity)
gen feeding = inlist(activity, "Nursing":activity, "Bottle":activity, "Solid Food":activity)
gen feeding_related = feeding | milk_producing
keep if feeding_related == 1

*** Drop any days that have ANY formula.
bys childid startdate: egen formula_day = total(formula)
drop if formula_day > 0

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

** Imputing Solid Food
gen solid_food_time = duration if activity == "Solid Food":activity
winsor2 solid_food_time, cut(0 99)
qui reg solid_food_time_w i.age_day
predict solid_food_pred, xb
replace duration = solid_food_pred if missing(duration) & activity == "Solid Food":activity

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
replace duration = bottle_time_pred if missing(duration) & activity == "Bottle":activity

drop amount_ml amount_bin_ml bottle_time* nurse_time* expression_time*

// Apply 20th percentile restriction
pct_restrict feeding, p(20)
drop if !feeding_insamp

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
drop daytime* total_daytime enddate formula_day min_daytime

