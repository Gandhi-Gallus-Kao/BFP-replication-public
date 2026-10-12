clear
set more off, perm
est clear
clear frames
cap log close
graph drop _all

// Descriptives table to show what countries, years etc. we have represented

do "$BFPrep_codedir/make_globals.do"
global sample = 0
log using "$logdir/summary_tables_$sample.log", replace

if $sample == 1{
    global indir "${anadatadir}/BabyConnect/sample"
    global outdir "${BFPrep_outdir}/Tables/sample"
}
else {
    global indir "${anadatadir}/BabyConnect/full"
    global outdir "${BFPrep_outdir}/Tables/full"
}

// Descriptives table to show what countries, years etc. we have represented
use "$indir/figure23_analysis_data.dta", clear
gcollapse (sum) total_duration = duration (count) record_count = activity (mean) avg_duration = duration (firstnm) age_day, by(childid startdate)

gen year = yofd(startdate)
bys childid: replace age_day = . if _n > 1
gcollapse (mean) total_duration record_count avg_duration age_day (nunique) unique_cid = childid (count) total_count = record_count, by(year)

egen total_obs = total(total_count)
gen freq_obs = 100 * total_count / total_obs
format total_duration record_count avg_duration age_day %12.2fc
format  freq_obs %12.1fc
format unique_cid  %12.2gc

listtex year total_duration record_count avg_duration age_day unique_cid freq_obs ///
	using "$outdir/stats_by_year.tex", ///
	rstyle(tabular) replace ///
	head("{" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
	"\begin{tabular}{lrrrrrrr}" "\hline\hline"  ///
 	`"\textit{Year} & \makecell{\textit{Duration} \\ \textit{per Day}} & \makecell{\textit{Count} \\ \textit{per Day}} & \makecell{\textit{Duration} \\ \textit{per Record}} & \textit{Average Age} & \makecell{\textit{ChildID} \\ \textit{Count}} & \makecell{\textit{\% of} \\ \textit{Observations}}\\\hline"') ///
 	foot("\hline\hline" "\end{tabular}" "}") 
	
	
use "$indir/figure23_analysis_data.dta", clear
gcollapse (sum) total_duration = duration (count) record_count = activity (mean) avg_duration = duration (firstnm) age_day country, by(childid startdate)

gen year = yofd(startdate)
bys childid: replace age_day = . if _n > 1

bys country: gen ctry_count = _N if _n == 1
egen total_count = total(ctry_count)
gen ctry_freq = 100 * ctry_count / total_count
bys country (ctry_freq): replace ctry_freq = ctry_freq[1]
replace country = -1 if ctry_freq < 1
label define countrycode -1 "Other", add

* If a child has any nonmissing final country, assign missing child-days
* to that child's modal nonmissing country.
bys childid: egen n_nonmiss_country = nvals(country)
bys childid: egen child_country_fill = mode(country), minmode

count if missing(country) & n_nonmiss_country >= 1
di "Missing child-day country values filled = " r(N)

replace country = child_country_fill if missing(country) & n_nonmiss_country >= 1

drop n_nonmiss_country child_country_fill

recode country (missing = .a)
label define countrycode .a "Missing", add

gcollapse (mean) total_duration record_count avg_duration age_day (nunique) unique_cid = childid (count) total_count = record_count, by(country)

egen total_obs = total(total_count)
gen freq_obs = 100 * total_count / total_obs
format total_duration record_count avg_duration age_day %12.2fc
format  freq_obs %12.1fc
format unique_cid  %12.2gc
gen last = 3 if country == "Missing":countrycode
replace last = 2 if country == "Other":countrycode
replace last = 1 if missing(last)

gsort last -freq_obs
listtex country total_duration record_count avg_duration age_day unique_cid freq_obs ///
	using "$outdir/stats_by_country.tex", ///
	rstyle(tabular) replace ///
	head("{" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
	"\begin{tabular}{lrrrrrrr}" "\hline\hline"  ///
 	`"\textit{Country} & \makecell{\textit{Duration} \\ \textit{per Day}} & \makecell{\textit{Count} \\ \textit{per Day}} & \makecell{\textit{Duration} \\ \textit{per Record}} & \textit{Average Age} & \makecell{\textit{ChildID} \\ \textit{Count}} & \makecell{\textit{\% of} \\ \textit{Observations}}\\\hline"') ///
 	foot("\hline\hline" "\end{tabular}" "}") 

log close
