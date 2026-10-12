clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0

log using "$logdir/pumping_by_age_$sample.log", replace

if $sample == 1{
    global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
	global indir "${anadatadir}/BabyConnect/sample"
}
else {
    global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
	global indir "${anadatadir}/BabyConnect/full"
}

do "$anadir/misc/label_functions.do"

use "$indir/figure23_analysis_data.dta", clear

gen nursing_dur = cond(activity == "Nursing":activity, duration, 0)
gen express_dur = cond(activity == "Expressed":activity, duration, 0)

preserve
    * First collapse to child-age level in case there are multiple obs per child-age
    collapse ///
        (sum) nursing_dur express_dur ///
        , by(childid age_day)

    gen milk_prod_dur = nursing_dur + express_dur
    gen pump_share_child = 100 * express_dur / milk_prod_dur if milk_prod_dur > 0

    * Number of child-days entering the figure
    count if pump_share_child < .
    display "Pumping-share figure child-days: " r(N)

    * Number of unique children entering the figure
    egen tag_child = tag(childid) if pump_share_child < .
    count if tag_child == 1
    display "Pumping-share figure children: " r(N)
    drop tag_child

    * Average across children at each age
    collapse ///
        (mean) pump_share_child ///
        (count) n_child_age = pump_share_child ///
        , by(age_day)

    *------------------------------------------------------------
    * 7-day centered moving average: age_day-3 through age_day+3
    * Uses smaller windows near boundaries
    *------------------------------------------------------------

    gen pump_share_child_ma7 = .

    forvalues d = 0/365 {
        quietly summarize pump_share_child if inrange(age_day, `d' - 3, `d' + 3), meanonly
        replace pump_share_child_ma7 = r(mean) if age_day == `d'
    }

    line pump_share_child_ma7 age_day if inrange(age_day, 0, 365), lwidth(medthick) ///
        ytitle("Percent", placement(n) orient(horizontal) axis(1) yoffset(4) xoffset(17)) ///
        graphregion(color(white)) bgcolor(white) plotregion(style(none)) ///
        color(navy%70) ///
        xtitle("Age of Child in Days") ///
        xlabel(0 90 180 270 360, nogrid) ///
        ylabel(0 "0%" 10 "10%" 20 "20%" 30 "30%", nogrid) ///
        graphregion(margin(l+0 r+2 h+8))

    graph export "$outdir/avg_pumping_share_by_age_ma7.pdf", replace
restore

log close