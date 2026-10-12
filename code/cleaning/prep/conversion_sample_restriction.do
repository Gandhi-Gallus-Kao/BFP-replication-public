*** Conversion sample preparation/restriction do file:

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
drop if missing(age_day) | age_day < 0
keep if age_day >=15 & age_day <= 365

gen feeding = inlist(activity, "Nursing":activity, "Bottle":activity)
keep if feeding == 1

** Imputing Nursing
gen nurse_time = duration if activity == "Nursing":activity
winsor2 nurse_time, cut(0 99)
qui reg nurse_time_w i.age_day
predict nurse_time_pred, xb
replace duration = nurse_time_pred if missing(duration) & activity == "Nursing":activity

** Drop days with missing bottle duration
gen amount_ml = quantity if unit == "ml":unit
replace amount_ml = 29.57 * quantity if unit == "oz":unit
recode amount_ml (min/15 = 1 "0-15 ml") (15/45 = 2 "15-45 ml") (45/75 = 3 "45-75 ml") ///
	(75/105 = 4 "75-105 ml") (105/135 = 5 "105-135 ml") (135/165 = 6 "135-165 ml") ///
	(165/195 = 7 "165-195 ml") (195/225 = 8 "195-225 ml") (225/255 = 9 "225-255 ml") ///
	(255/285 = 10 "255-285 ml")  (285/max = 11 "285+ ml") (missing = 0 "Missing"), ///
	gen(amount_bin_ml)

gen bottle_time = duration if activity == "Bottle":activity
winsor2 bottle_time, cut(0 99)
qui reg bottle_time_w i.age_day##i.amount_bin_ml
predict bottle_time_pred, xb
replace bottle_time_pred = 0 if bottle_time_pred < 0
replace duration = bottle_time_pred if missing(duration) & activity == "Bottle":activity

drop nurse_time*
pct_restrict feeding, p(20)
drop if !feeding_insamp

drop endtime
gen double endtime = starttime + duration*60*1000
format endtime %tC
order endtime, after(starttime)
