format starttime %tC
format endtime %tC

keep childid activity starttime endtime duration birthdate startdate
gduplicates drop
decode activity, gen(activity_decode)
drop activity
rename activity_decode activity
compress

** Below merges if activity is shared and overlaps time with same user (e.g. 3-5 nursing, 4-6 nursing -> 3-6 nursing)
bys childid activity (starttime endtime): gen overlap_ind = endtime[_n-1] < starttime[_n] //note that overlap_ind is 1 if there is NO overlap
bys childid activity (starttime endtime): gen groupid = sum(overlap_ind)
collapse (min) starttime (max) endtime (firstnm) birthdate startdate, by(childid activity groupid)
drop groupid

gen duration = (endtime - starttime) / (60*1000)
** Below is to make sure that the any cases such as
**  |-------|
**    |-|
**        |---|
** does not introduce a "nothing" variable

bys childid (starttime endtime): egen double latest_endtime = min(endtime)
bys childid (starttime endtime): replace latest_endtime = max(endtime, latest_endtime[_n-1]) if _n > 1
format latest_endtime %tC

** Preparing generate nothing observations
bys childid: gen lag = (starttime[_n] > latest_endtime[_n-1]) + 1
bys childid: replace lag = 2 if _n == 1
expand lag, gen(copy)
gsort childid -lag starttime endtime copy

** Generate nothing, with the start time and endttime adjusted properly. 
replace activity = "Nothing" if copy == 1
by childid: replace endtime = starttime if copy == 1
by childid: replace starttime = endtime[_n-3] if copy == 1

**
drop if missing(starttime)
gen age_day = (startdate - birthdate)

drop lag copy latest_endtime
