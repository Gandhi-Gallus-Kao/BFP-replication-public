clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/sample_summary_$sample.log", replace

if $sample == 1 {
    global indir "$anadatadir/BabyConnect/sample"
}
else {
    global indir "$anadatadir/BabyConnect/full"
}

*****************************************************************************
* 1. Country-level mean daily milk-production duration
*****************************************************************************
use "$indir/figure23_analysis_data.dta", clear

gcollapse (sum) total_duration = duration ///
          (count) record_count = activity ///
          (mean) avg_duration = duration ///
          (firstnm) age_day country, by(childid startdate)

gen year = yofd(startdate)
bys childid: replace age_day = . if _n > 1

bys country: gen ctry_count = _N if _n == 1
egen total_count = total(ctry_count)
gen ctry_freq = 100 * ctry_count / total_count
bys country (ctry_freq): replace ctry_freq = ctry_freq[1]
replace country = -1 if ctry_freq < 1
label define countrycode -1 "Other", add
recode country (missing = .a)
label define countrycode .a "Missing", add

gcollapse (mean) total_duration record_count avg_duration age_day ///
          (nunique) unique_cid = childid ///
          (count) total_count = record_count, by(country)
egen total_obs = total(total_count)
gen freq_obs = 100 * total_count / total_obs

quietly summarize total_duration
local min_country_mean_duration = r(min)
local max_country_mean_duration = r(max)


*****************************************************************************
* 2. Base sample, users, children, activities, and geography
*****************************************************************************
use "$indir/figure4_base_data.dta", clear

quietly count
local n_base_records = r(N)

* Distinct infants associated with each user
bys postedbyuserid: egen infant_count = nvals(childid)
bys postedbyuserid: replace infant_count = . if _n > 1
quietly summarize infant_count, detail
local mean_infants_per_user = r(mean)
local median_infants_per_user = r(p50)

* Feeding events per user-day
bys postedbyuserid startdate: egen feed_day_count = total(feeding)
bys postedbyuserid startdate: replace feed_day_count = . if _n > 1
quietly summarize feed_day_count, detail
local mean_feeds_per_user_day = r(mean)
local median_feeds_per_user_day = r(p50)

* Percentage of users associated with more than one infant
quietly count if infant_count > 1 & !missing(infant_count)
local n_multi_infant_users = r(N)
quietly count if !missing(infant_count)
local n_users = r(N)
local pct_multi_infant_users = 100 * `n_multi_infant_users' / `n_users'

* Percentage of children associated with more than one parent account
bys childid: egen parent_count = nvals(postedbyuserid)
bys childid: replace parent_count = . if _n > 1
quietly count if parent_count > 1 & !missing(parent_count)
local n_multi_parent_children = r(N)
quietly count if !missing(parent_count)
local n_children_with_parent_info = r(N)
local pct_multi_parent_children = ///
    100 * `n_multi_parent_children' / `n_children_with_parent_info'

* Activity and sample counts
quietly count if milk_producing == 1
local n_milkprod_records = r(N)

gdistinct childid
local n_children = r(ndistinct)

gdistinct countrycode
local n_countries = r(ndistinct)

quietly count if countrycode == "US":countrycode
local n_us_records = r(N)
quietly count if !missing(countrycode)
local n_geocoded_records = r(N)
local pct_us_records = 100 * `n_us_records' / `n_geocoded_records'

*****************************************************************************
* 3. Mean daily duration and child age
*****************************************************************************
use "$indir/figure23_analysis_data.dta", clear
* Share of children who ever logged pumping
preserve
    gen express_dur = cond(activity == "Expressed":activity, duration, 0)

    bys childid: egen ever_pumped = max(express_dur > 0)
    bys childid: keep if _n == 1

    quietly summarize ever_pumped, meanonly
    local ever_pumped_pct = 100 * r(mean)
restore

gcollapse (sum) total_duration = duration ///
          (count) record_count = activity ///
          (mean) avg_duration = duration ///
          (firstnm) age_day country, by(childid startdate)

quietly summarize total_duration, detail
local mean_daily_duration = r(mean)

quietly summarize age_day, detail
local mean_age_day = r(mean)

*****************************************************************************
* 4. Share of observations matched to child-by-age-week fixed effects
*****************************************************************************
use "$indir/figure4_base_data.dta", clear

drop age_weeks
gen age_weeks = ceil(age_day / 7)
merge m:1 childid age_weeks using "$indir/childid_age_fe.dta", keep(1 3)

quietly count if _merge == 3
local n_fe_matched = r(N)
quietly count
local n_fe_total = r(N)
local pct_fe_matched = 100 * `n_fe_matched' / `n_fe_total'


*****************************************************************************
* 5. Coverage across age cohorts
*****************************************************************************
use "$indir/figure1_cohort_analysis_data.dta", clear
keep if milk_producing

recode age_day (0/90 = 1 "<90 days") ///
               (91/180 = 2 "91 - 180 days") ///
               (181/365 = 3 "181 - 365 days") ///
               (else = 9), gen(age_cohort)

gen cohort1 = (age_cohort == 1)
gen cohort2 = (age_cohort == 2)
gen cohort3 = (age_cohort == 3)
collapse (max) cohort*, by(childid)

gen combination = ""
replace combination = "In All"    if cohort1 & cohort2 & cohort3
replace combination = "In 1, 2"   if cohort1 & cohort2 & !cohort3
replace combination = "In 1, 3"   if cohort1 & !cohort2 & cohort3
replace combination = "In 2, 3"   if !cohort1 & cohort2 & cohort3
replace combination = "In only 1" if cohort1 & !cohort2 & !cohort3
replace combination = "In only 2" if !cohort1 & cohort2 & !cohort3
replace combination = "In only 3" if !cohort1 & !cohort2 & cohort3

contract combination
egen total_children = total(_freq)
gen percent = (_freq / total_children) * 100

quietly summarize percent if combination == "In All", meanonly
local pct_all_three_cohorts = r(mean)

quietly summarize percent if combination == "In only 1", meanonly
local pct_first_cohort_only = r(mean)

*****************************************************************************
* Consolidated sample-description log
*****************************************************************************
di as text _newline "=================================================================="
di as text "                      SAMPLE DESCRIPTION"
di as text "=================================================================="

di as text _newline "SAMPLE SIZE AND GEOGRAPHY"
di as text "  Figure 4 base records:                  " as result %15.0fc `n_base_records'
di as text "  Milk-production records:                " as result %15.0fc `n_milkprod_records'
di as text "  Distinct children:                      " as result %15.0fc `n_children'
di as text "  Distinct countries:                     " as result %15.0fc `n_countries'
di as text "  US share of nonmissing-country records (%): " as result %8.1f `pct_us_records'

di as text _newline "USER AND CHILD CHARACTERISTICS"
di as text "  Children ever logging pumping (%):     " as result %12.1f `ever_pumped_pct'
di as text "  Infants per user, mean:                 " as result %12.2f `mean_infants_per_user'
di as text "  Infants per user, median:               " as result %12.2f `median_infants_per_user'
di as text "  Feeding events per user-day, mean:      " as result %12.2f `mean_feeds_per_user_day'
di as text "  Feeding events per user-day, median:    " as result %12.2f `median_feeds_per_user_day'
di as text "  Users with multiple infants (%):       " as result %12.1f `pct_multi_infant_users'
di as text "  Children with multiple parent accounts (%): " as result %8.1f `pct_multi_parent_children'

di as text _newline "DURATION AND AGE"
di as text "  Mean daily duration (minutes):          " as result %12.2f `mean_daily_duration'
di as text "  Mean child age (days):                  " as result %12.2f `mean_age_day'
di as text "  Minimum country mean daily duration (min): " as result %8.2f `min_country_mean_duration'
di as text "  Maximum country mean daily duration (min): " as result %8.2f `max_country_mean_duration'

di as text _newline "MATCHING AND COHORT COVERAGE"
di as text "  Matched to child-age-week FE (%):       " as result %12.1f `pct_fe_matched'
di as text "  Children in all three cohorts (%):     " as result %12.1f `pct_all_three_cohorts'
di as text "  Children in first cohort only (%):     " as result %12.1f `pct_first_cohort_only'

di as text "=================================================================="

log close