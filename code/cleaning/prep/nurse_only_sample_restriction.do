*** Base sample restriction do file:

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
gen feeding = inlist(activity, "Nursing":activity, "Bottle":activity)
gen feeding_related = feeding | milk_producing
keep if feeding_related == 1

*** Keep the childid if they are exclusive nursing (no expression/bottle):
bys childid: egen has_nursing = max(activity == "Nursing":activity)
bys childid: egen has_expr_bottle = max(inlist(activity, "Expressed":activity, "Bottle":activity))
* The synthetic generator does not preserve realistic within-child feeding heterogeneity,
* so this restriction would drop nearly all synthetic observations. It is therefore skipped
* when the environment variable USE_SYNTHETIC is 1 (exported by the Makefile; the default
* path) and applied in all other cases, including the confidential raw-data run
* (USE_SYNTHETIC=0). If you run sample_creation.do by hand on synthetic data, first
* run: export USE_SYNTHETIC=1
local use_synthetic : environment USE_SYNTHETIC
if "`use_synthetic'" == "1" {
    display as text "USE_SYNTHETIC=1: skipping exclusive-nursing restriction (synthetic data)"
}
else {
    keep if has_nursing == 1 & has_expr_bottle == 0
}
drop has_nursing has_expr_bottle

** Imputing Nursing
gen nurse_time = duration if activity == "Nursing":activity
winsor2 nurse_time, cut(0 99)
qui reg nurse_time_w i.age_day
predict nurse_time_pred, xb
replace duration = nurse_time_pred if missing(duration) & activity == "Nursing":activity

drop nurse_time*

*** Apply 20th percentile restriction
pct_restrict milk_producing, p(20)
drop if !milk_producing_insamp

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
bys childid startdate: egen min_daytime = min(total_daytime) // Ensure that any particular day h

drop if min_daytime < 1
drop daytime* total_daytime enddate min_daytime
