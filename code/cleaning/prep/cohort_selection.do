clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/cohort_selection_$sample.log", replace

if $sample == 1{
    global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
    global indir "${anadatadir}/BabyConnect/sample"
}
else {
    global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
    global indir "${anadatadir}/BabyConnect/full"
}

use "$indir/figure1_cohort_analysis_data.dta", clear
keep if milk_producing
recode age_day (0/90 = 1 "<90 days") (91/180 = 2 "91 - 180 days") (181/365 = 3 "181 - 365 days") (else = 9), gen(age_cohort)

** Number of unique childid in each cohort (how many enter, exit)
preserve
gen cohort1 = age_cohort == 1
gen cohort2 = age_cohort == 2
gen cohort3 = age_cohort == 3
collapse (max) cohort*, by(childid)

count
display "Cohort entry/exit figure sample size (children): " r(N)

gen combination = ""
replace combination = "In All" if cohort1 == 1 & cohort2 == 1 & cohort3 == 1
replace combination = "In 1, 2" if cohort1 == 1 & cohort2 == 1 & cohort3 == 0
replace combination = "In 1, 3" if cohort1 == 1 & cohort2 == 0 & cohort3 == 1
replace combination = "In 2, 3" if cohort1 == 0 & cohort2 == 1 & cohort3 == 1
replace combination = "In only 1" if cohort1 == 1 & cohort2 == 0 & cohort3 == 0
replace combination = "In only 2" if cohort1 == 0 & cohort2 == 1 & cohort3 == 0
replace combination = "In only 3" if cohort1 == 0 & cohort2 == 0 & cohort3 == 1
gen order = .
replace order = 1 if combination == "In All"
replace order = 2 if combination == "In 1, 2"
replace order = 3 if combination == "In 1, 3"
replace order = 4 if combination == "In 2, 3"
replace order = 5 if combination == "In only 1"
replace order = 6 if combination == "In only 2"
replace order = 7 if combination == "In only 3"

collapse (count) cnt =childid, by(combination order)
gen total = sum(cnt)
replace total = total[_N]  // Ensure total is filled across all rows
gen percent = (cnt / total) * 100
sort order

graph bar percent, over(combination, sort(order) label(angle(45))) ///
    bar(1, color(navy%70)) ///
    ytitle("Percent" "of Children", placement(n) orient(horizontal) yoffset(4) xoffset(6)) ///
    bgcolor(white) plotregion(style(none)) ///
    legend(off) ylabel(, nogrid) ///
    graphregion(color(white) margin(l+2 r+2 h+8)) aspect(0.65)
    

graph export "$outdir/entry_exit_cohort.pdf", replace

restore

gdistinct childid 
bys childid age_cohort: gen exist = 1 if _n == 1
bys childid: egen exist_sum = total(exist)
keep if exist_sum == 3
drop exist exist_sum
gdistinct childid

save "$indir/figure1_cohort_analysis_data_intrsct.dta", replace

global day_start = 6
global day_end = 22
preserve
do "$cleandir/prep/feeding_partition_generic.do"
do "$cleandir/prep/daytime_nighttime_generic.do"
gen date = dofC(starttime)
format date %td

save "$indir/figure1cd_analysis_data_intrsct.dta", replace
restore

log close