clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/margins_apdx_$sample.log", replace

if $sample == 1{
    global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
    global indir "${anadatadir}/BabyConnect/sample"
    use "$anadatadir/BabyConnect/sample/bc_sub_sample_formatted.dta", clear
}
else {
    global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
    global indir "${anadatadir}/BabyConnect/full"
    use "$anadatadir/BabyConnect/full/bc_full_sample_formatted.dta", clear
}
** Min duration restriction (duration of negatives and 0s)
drop if duration < 1 | missing(duration)

** Max duration restriction (12 hours = 60*12 minutes)
drop if duration > 720

** Apply sample restriction & generate total_feed_count
gen feeding_ind = activity == "Nursing":activity | activity == "Bottle":activity | activity == "Solid Food":activity
gen milk_producing_ind = activity == "Nursing":activity | activity == "Expressed":activity
gen feeding_related_ind = feeding_ind | milk_producing_ind

gsort childid startdate
by childid startdate: egen express_day_ind = total(activity == "Expressed":activity)
gen rationalize_ind = activity == "Bottle":activity & formula == 0 & express_day_ind > 0
tab formula
tab rationalize_ind
egen total_feed_count = total(feeding_ind | rationalize_ind), by(childid startdate)

generate age = datediff_frac(birthdate, startdate, "day")
gcollapse (max) total_feed_count, by(childid age)

** Restrict to days with at least one feeding-related event
drop if total_feed_count < 1
keep if age >=0 & age <= 365

qui reghdfe total_feed_count i.age, a(childid) vce(cluster childid)

* Figure 5 regression sample sizes
local n_childdays = e(N)
local n_children = e(N_clust)

display "Figure 5 child-days: `n_childdays'"
display "Figure 5 children: `n_children'"

margins i.age
matrix M = r(table)
local events1mo = M[1,31]   // age=30 → col 31
local events6mo = M[1,181]  // age=180 → col 181
local events1yr = M[1,366]  // age=365 → col 366

di "`events1mo' at 1 mo; `events6mo' at 6 mo; `events1yr' at 1 yr"
marginsplot, graphregion(color(white)) bgcolor(white) plotregion(style(none)) ///
    xlabel(0(60)365, nogrid) xtitle("Baby Age (Days)") ylabel(2(2)12, nogrid angle(horizontal)) ///
    ytitle("Model Predicted Average" "Milk Production Events", placement(n) ///
    orient(horizontal)) ysc(titlegap(-10) outergap(0)) ///
    graphregion(margin(l+2 r+2 h+8)) title("") ///
    ciopt(recast(rarea) color(navy%25)) plotopt(msize(vsmall) color(navy)) recast(line)
gr_edit yaxis1.title.DragBy 8 18

graph export "$outdir/reg_coef_marginsplot.pdf", replace

log close