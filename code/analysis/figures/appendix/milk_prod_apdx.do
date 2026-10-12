clear
set more off, perm
est clear
clear frames

cap log close

graph drop _all
do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/milk_prod_apdx_$sample.log", replace

if $sample == 1{
    global outdir "${BFPrep_outdir}/Subfigures/sample/appendix"
    global indir "${anadatadir}/BabyConnect/sample"
}
else {
    global outdir "${BFPrep_outdir}/Subfigures/full/appendix"
    global indir "${anadatadir}/BabyConnect/full"
}

use "$indir/milk_prod_obs_pctile.dta", clear

foreach i of num 1/10{	
    gen obs_count_in_`i' = cond(!cutoff_`i', obs_count_adj_`i', .)
    gen obs_count_out_`i' = cond(cutoff_`i', obs_count_adj_`i', .)
}

replace obs_count_in_1 = obs_count_out_1 if missing(obs_count_in_1)
foreach i of num 2/10{	
    local j = `i' - 1
    replace obs_count_out_`i' = obs_count_in_`j' if missing(obs_count_out_`i')
    replace obs_count_in_`i' = obs_count_out_`i' if missing(obs_count_in_`i')
}

twoway bar obs_count_out_1 age_day, color(maroon*.05) || ///
    rbar obs_count_out_1 obs_count_in_1 age_day, color(navy*.05) || ///
    rbar obs_count_in_1 obs_count_out_2 age_day, color(maroon*.15) || ///
    rbar obs_count_out_2 obs_count_in_2 age_day, color(navy*.15) || ///
    rbar obs_count_in_2 obs_count_out_3 age_day, color(maroon*.25) || ///
    rbar obs_count_out_3 obs_count_in_3 age_day, color(navy*.25) || ///
    rbar obs_count_in_3 obs_count_out_4 age_day, color(maroon*.35) || ///
    rbar obs_count_out_4 obs_count_in_4 age_day, color(navy*.35) || ///
    rbar obs_count_in_4 obs_count_out_5 age_day, color(maroon*.45) || ///
    rbar obs_count_out_5 obs_count_in_5 age_day, color(navy*.45) || ///
    rbar obs_count_in_5 obs_count_out_6 age_day, color(maroon*.55) || ///
    rbar obs_count_out_6 obs_count_in_6 age_day, color(navy*.55) || ///
    rbar obs_count_in_6 obs_count_out_7 age_day, color(maroon*.65) || ///
    rbar obs_count_out_7 obs_count_in_7 age_day, color(navy*.65) || ///
    rbar obs_count_in_7 obs_count_out_8 age_day, color(maroon*.75) || ///
    rbar obs_count_out_8 obs_count_in_8 age_day, color(navy*.75) || ///
    rbar obs_count_in_8 obs_count_out_9 age_day, color(maroon*.85) || ///
    rbar obs_count_out_9 obs_count_in_9 age_day, color(navy*.85) || ///
    rbar obs_count_in_9 obs_count_out_10 age_day, color(maroon*.95) || ///
    rbar obs_count_out_10 obs_count_in_10 age_day, color(navy*.95) || ///
    function y = 20, range(15 365) color(black) ///
    graphregion(color(white)) bgcolor(white) plotregion(style(none)) ///
    xlabel(0(60)365, nogrid) xtitle("Baby Age (Days)") ylabel(, nogrid angle(horizontal)) ///
    ytitle("Percent", placement(n) ///
    orient(horizontal)) ysc(titlegap(-10) outergap(0)) ///
    graphregion(margin(l+2 r+2 h+8)) ///
    legend(order(- "Included" - "Excluded" 20 9 18 7 16 5 14 3 12 1 10 - " " 8 - " " ///
    6 - " " 4 - "") lab(20 "10+") lab(19 "10+") lab(18 "9") lab(17 "9") lab(16 "8") ///
    lab(15 "8") lab(14 "7") lab(13 "7") lab(12 "6") lab(11 "6") lab(10 "5") lab(9 "5") ///
    lab(8 "4") lab(7 "4") lab(6 "3") lab(5 "3") lab(4 "2") lab(3 "2") lab(2 "1") lab(1 "1") ///
    pos(3) cols(2) subtitle("Number of" "Milk Production Events") size(3) region(lwidth(none)))

gr_edit yaxis1.title.DragBy 3 6
di "$outdir/milk_production_count_365_day.pdf"
graph export "$outdir/milk_production_count_365_day.pdf", replace

log close
