cap program drop gen_stats
program gen_stats
	args varname
	egen mean_`varname' = mean(`varname')
	egen p25_`varname' = pctile(`varname'), p(25)
	egen p50_`varname' = pctile(`varname'), p(50)
	egen p75_`varname' = pctile(`varname'), p(75)
	gen zero = 0 if _n == 1

	replace mean_`varname' = . if _n != 1
	replace p25_`varname' = . if _n != 1
	replace p50_`varname' = . if _n != 1
	replace p75_`varname' = . if _n != 1
	qui count
end

cap program drop histogram_stats
program define histogram_stats
    syntax varlist(min=1 max=1) [if] [in] ///
        [, MYOPT CILOW(varname) CIHIGH(varname) *]

	local varname "`varlist'"
	local plotvar "`varname'"
	if substr("`varname'", -5, 5) == "_plot" {
		local plotvar = substr("`varname'", 1, length("`varname'") - 5)
	}

    * Optional 95% CI error bar around the mean marker
    local ci_plot
    if "`cilow'" != "" & "`cihigh'" != "" {
        local ci_plot "|| rcap `cilow' `cihigh' zero, horizontal lcolor(dkorange) lwidth(medthick) msize(small)"
    }

    * Plot the histogram with stats
	twoway histogram `varlist' `if' `in', `options' ///
		graphregion(color(white)) bgcolor(white) plotregion(style(none)) ///
		color(navy%70) freq legend(off) ysc(titlegap(-10) outergap(0)) ///
		`ci_plot' ///
		|| scatter zero mean_`plotvar', msize(large) msymbol(d) mfcolor(dkorange) mlcolor(dkorange) mlwidth(medthick) ///
		|| scatter zero p25_`plotvar', msize(large) msymbol(|) mfcolor(white) mlcolor(maroon) mlwidth(medthick) ///
		|| scatter zero p50_`plotvar', msize(large) msymbol(|) mfcolor(white) mlcolor(maroon) mlwidth(medthick) ///
		|| scatter zero p75_`plotvar', msize(large) msymbol(|) mfcolor(white) mlcolor(maroon) mlwidth(medthick)
end
