* cleaning_tools.do: Custom utility programs for sample construction.
* Load with `do` before use; currently defines pct_restrict.

*--------------------------------------------------------
* pct_restrict: Restrict observations based on a given percentile threshold.
* Usage: pct_restrict varname, p(#)
*   - varname: The numeric variable to sum (e.g., milk_producing)
*   - p: The percentile value (e.g., 20)
* The program assumes the existence of the grouping variables childid and age_day.
* It creates an indicator variable named <varname>_insamp.
*--------------------------------------------------------
program define pct_restrict
    version 15.1
    syntax varlist(min=1 max=1 numeric) [if] [in], p(real)
    local varname : word 1 of `varlist'
    preserve
    // Collapse sum of the specified variable by childid and age_day.
    gcollapse (sum) total_prod = `varname', by(childid age_day)
    // Restrict to days with at least one event.
    drop if total_prod == 0
    
    // For each day, compute the specified percentile of total production.
    bys age_day: egen pct_val = pctile(total_prod), p(`p')
    
    // Drop observations below the threshold (pct_val - 1).
    drop if total_prod < pct_val - 1

    // Keep identifiers needed for merging.
    keep childid age_day
    tempfile pct_temp
    save `pct_temp'
    
    restore

    // Merge the restricted sample back into the original dataset.
    merge m:1 age_day childid using `pct_temp', keep(1 3)
    
    // Create an indicator variable for observations in the restricted sample.
    gen `varname'_insamp = (_merge == 3)
    drop _merge
end