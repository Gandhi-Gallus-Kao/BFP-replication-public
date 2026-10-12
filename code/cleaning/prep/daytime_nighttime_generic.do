by childid: gen obs_id = _n
gen startday = dofC(starttime)
gen endday = dofC(endtime)
** If something spans multiple days, duplicate it and fill in proper times
gen total_activity_day_count = endday - startday + 1
expand total_activity_day_count if total_activity_day_count > 0
bys childid obs_id: gen day_counter = _n - 1
bys childid obs_id: gen last_day = _n == _N

** below fixes the times
replace endtime = Cofd(startday) + Chms(23,59,59) if day_counter == 0 & total_activity_day_count > 1
replace starttime = Cofd(startday + day_counter) if day_counter > 0
replace endtime = starttime + Chms(23,59,59) if day_counter > 0 & last_day == 0

** Drop intermediate empty/"Nothing" days
drop if day_counter > 0 & last_day == 0 & activity == "Nothing"

gen double date = Cofd(dofC(starttime))
drop if endtime - starttime < 0
** If an observation spans a day/night boundary, split it. 3 cases:
** (1) starts before $day_start, ends between $day_start and $day_end
** (2) starts between $day_start and $day_end, ends after $day_end
** (3) starts before $day_start, ends after $day_end
by childid: gen obs_day_id = _n

gen case = 0
replace case = 1 if hhC(starttime) < $day_start & hhC(endtime) >= $day_start & hhC(endtime) < $day_end 
replace case = 2 if hhC(starttime) >= $day_start & hhC(starttime) < $day_end & hhC(endtime) >= $day_end 
replace case = 3 if hhC(starttime) < $day_start & hhC(endtime) >= $day_end

expand 2 if case == 1, gen(case1_dup)
replace endtime = date + Chms($day_start - 1, 59, 59) if case == 1 & case1_dup == 0
replace starttime = date + Chms($day_start, 0, 0) if case == 1 & case1_dup == 1

expand 2 if case == 2, gen(case2_dup)
replace endtime = date + Chms($day_end - 1, 59, 59) if case == 2 & case2_dup == 0
replace starttime = date + Chms($day_end,0,0) if case == 2 & case2_dup == 1

expand 3 if case == 3
bys childid obs_day_id: gen case3_dup = _n
replace endtime = date + Chms($day_start - 1, 59, 59) if case == 3 & case3_dup == 1
replace starttime = date + Chms($day_start, 0, 0) if case == 3 & case3_dup == 2
replace endtime = date + Chms($day_end - 1, 59, 59) if case == 3 & case3_dup == 2
replace starttime = date + Chms($day_end, 0, 0) if case == 3 & case3_dup == 3

gen daytime_ind = hhC(starttime) < $day_end & hhC(endtime) >= $day_start
gen nighttime_ind = hhC(starttime) < $day_start | hhC(endtime) >= $day_end

** Need to patch up data, since observations were split earlier. This is characterized by the end_part and start_part below IN ADDITION to having total_activity_day_count > 1

gen end_part_ind = hhC(endtime) == 23 & mmC(endtime) == 59 & ssC(endtime) == 59
gen start_part_ind = hhC(starttime) == 0 & mmC(starttime) == 0 & ssC(starttime) == 0

bys childid obs_id (starttime): gen patch_ind = end_part_ind == 1 & start_part_ind[_n+1] == 1
replace endtime = endtime[_n+1] if patch_ind == 1 & total_activity_day_count > 1
drop if patch_ind[_n-1] == 1

drop *_dup total_activity_day_count day_counter last_day startday endday obs_id case date
drop patch_ind start_part* end_part* 
encode activity, gen(new_activity)
drop activity
label drop activity
rename new_activity activity
capture label drop activity
label copy new_activity activity
ds, has(vallabel new_activity)
label values `r(varlist)' activity
label drop new_activity

* Creating adj_startdate for purposes of ensuring consecutive days for nighttime
* Subtract $day_start hours so early-morning nighttime events (after midnight but
* before $day_start) are assigned to the prior calendar day, keeping the nighttime
* block contiguous across midnight.
gen adjust_startdate = dofC(starttime - Chms($day_start,0,0)) if nighttime_ind
format adjust_startdate %td
format startdate %td

** Delete the days that are not consecutive
bysort childid (startdate): gen day_diff1 = abs(startdate - startdate[_n-1])
bysort childid (startdate): gen day_diff2 = abs(startdate - startdate[_n+1])
gen day_diff = max(day_diff1, day_diff2)
egen max_day_diff = min(day_diff) if day_diff != 0, by(childid startdate)

bysort childid startdate (max_day_diff) : replace max_day_diff = max_day_diff[_n-1] if missing(max_day_diff) 
drop if max_day_diff > 1
drop day_diff* max_day_diff
