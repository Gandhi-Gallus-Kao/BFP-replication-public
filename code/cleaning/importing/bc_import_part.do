clear
set more off, perm
est clear

cap log close
do "$BFPrep_codedir/make_globals.do"
log using "$logdir/bc_import_part.log", replace

forvalues j=1/162{
	display `"Importing bc_raw_`j'.dta"'
	use "$interdir/BabyConnect/raw_bc_stata/bc_raw_`j'.dta"
	rename *, lower

	gen birthdate_temp = date(birthdate, "YMD")
	gen double starttime_temp = Clock(starttime, "YMDhm")
	replace starttime_temp = Clock(starttime, "YMD") if missing(starttime_temp)
	gen double endtime_temp = Clock(endtime, "YMDhm")
	replace endtime_temp = Clock(endtime, "YMD") if missing(endtime_temp)

	drop starttime endtime birthdate
	drop if missing(starttime_temp)
	rename (starttime_temp endtime_temp birthdate_temp) (starttime endtime birthdate)
	gen startdate = dofC(starttime)
	gen enddate = dofC(endtime)
	replace extradata = strlower(extradata)
	replace text = strlower(text)
	replace activity = strproper(strtrim(activity))

	* extracts first numeric part of quantity (e.g. cases of alphabetical characters)
	rename quantity quantity_old
	gen quantity = real(regexs(1)) if regexm(quantity_old,"([0-9]+)")
	drop quantity_old

	destring durationmin, replace force
	destring childid, replace force
	destring postedbyuserid, replace force

	format birthdate %td
	format startdate %td
	format enddate %td
	format starttime %tC
	format endtime %tC

	order birthdate, after(childid)
	order starttime endtime startdate enddate, after(timezoneinfo)

	tostring extradata, replace
	tostring text, replace

	gen unit = "ml" if strpos(extradata, "ml") > 0 | strpos(text, "ml") > 0
	replace unit = "oz" if strpos(extradata, "oz") > 0 | strpos(text, "oz") > 0
	replace unit = "mn" if strpos(extradata, "mn") > 0 | strpos(text, "mn") > 0
	
	gen formula = strpos(extradata, "formula") > 0

	replace lang = "" if lang == "nan"
	replace countrycode = "" if countrycode == "nan"
	replace timezoneinfo = "" if timezoneinfo == "nan"

	drop notes		
	gduplicates drop

	gen data_source_num = `j'

	tempfile tf_`j'
	save `tf_`j''
	clear
	di `j'
}

clear
forvalues i=1/162{
	cap append using `tf_`i''
}

label var starttime "Start Time"
label var endtime "End Time"
label var startdate "Start Date"
label var enddate "End Date"
label var birthdate "Birth Date"

rename durationmin duration
qui compress
save "$interdir/BabyConnect/bc_full_cleaned.dta", replace

log close
