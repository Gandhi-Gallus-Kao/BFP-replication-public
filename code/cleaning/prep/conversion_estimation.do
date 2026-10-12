drop if age_day > 365

gcollapse (sum) duration (firstnm) age_day (count) total_feeding_events = duration, by(childid startdate activity)
gen nursing_dur = duration * (activity == "Nursing":activity)
gen bottle_dur = duration * (activity == "Bottle":activity)

gcollapse (sum) *dur (firstnm) age_day (sum) total_feeding_events, by(childid startdate)
**
replace total_feeding_events = 20 if total_feeding_events >= 20

gen total_time = bottle_dur + nursing_dur
gen share_bottle_time = bottle_dur / total_time
rename age_day age
gen log_total_time = log(total_time)
gen dayofweek = dow(startdate) + 1
gen age_weeks = ceil(age / 7)
gen day_within_ageweek = mod(age - 1, 7) + 1

egen long childid_num = group(childid)

reghdfe log_total_time i.age_weeks#c.share_bottle_time i.dayofweek i.day_within_ageweek i.total_feeding_events#i.age_weeks, a(i.childid_num#i.age_weeks, savefe) cluster(childid)
est save "$outdir/logcoef_all.ster", replace

rename __hdfe1__ childid_age_fe
keep childid age_weeks childid_age_fe
gduplicates drop
save "$outdir/childid_age_fe.dta", replace

