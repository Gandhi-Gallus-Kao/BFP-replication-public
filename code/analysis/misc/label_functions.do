cap program drop axis_lab_pct
program axis_lab_pct
	args begin end space lab_name
	qui count
	local i = 0
	local labels
	forvalues y = `begin'(`space')`end' {
		local i = `i' + 1
		local raw_val`i' = `r(N)' * `y' / 100
		local u`i' = `y'
		local u`i' "`u`i''%"
		local labels `labels' `raw_val`i'' "`u`i''"
	}
	global `lab_name' `labels'
end

// Generate count-axis labels at the same positions as axis_lab_pct.
// Formats values as "Xk" (thousands) or "X.XM" (millions) for readability.
cap program drop axis_lab_count
program axis_lab_count
	args begin end space lab_name
	qui count
	local N = r(N)
	local labels
	forvalues pct = `begin'(`space')`end' {
		local raw = round(`N' * `pct' / 100)
		if `raw' >= 1000000 {
			local disp = string(round(`raw' / 100000) / 10)
			local lab "`disp'M"
		}
		else if `raw' >= 1000 {
			local disp = string(round(`raw' / 100) / 10)
			local lab "`disp'k"
		}
		else {
			local lab = string(`raw')
		}
		local labels `"`labels' `raw' "`lab'""'
	}
	global `lab_name' `labels'
end

cap program drop axis_lab_pct_simple
program axis_lab_pct_simple
	args begin end space lab_name
	local i = 0
	local labels
	forvalues y = `begin'(`space')`end' {
		local i = `i' + 1
		local u`i' = `y'
		local u`i' "`u`i''%"
		local labels `labels' `y' "`u`i''"
	}
	global `lab_name' `labels'
end
