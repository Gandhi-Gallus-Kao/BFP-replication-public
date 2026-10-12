***** Generates the 20th percentile restriction; run from base_sample_restriction.do
preserve
gcollapse (sum) total_milk_prod = milk_producing, by(childid age_day)

** Restrict to days with at least one milk-production event
drop if total_milk_prod < 1

* Sample counts
count
display "Milk-production percentile figure child-days: " r(N)

egen tag_child = tag(childid)
count if tag_child
display "Milk-production percentile figure children: " r(N)
drop tag_child

replace total_milk_prod = 10 if total_milk_prod >= 10

** obs_count_`j' equals 1 if that child-age has `j' feeding-related events
foreach i of num 1/10{	
    gen obs_count_`i' = total_milk_prod == `i'
}

gen obs_count_adj_1 = obs_count_1

** Adjust for stacking
foreach i of num 2/10{	
    local j = `i' - 1
    gen obs_count_adj_`i' = obs_count_adj_`j' + obs_count_`i'
}

gcollapse (sum) obs_count_adj_*, by(age_day)

* Convert into percentile
foreach i of num 1/10{	
    replace obs_count_adj_`i' = 100*obs_count_adj_`i'/obs_count_adj_10
}

* Find cutoff value for the 20th percentile
foreach i of num 1/10{	
    gen cutoff_`i' = obs_count_adj_`i' < 20
}

save "$outdir/milk_prod_obs_pctile.dta", replace
restore
