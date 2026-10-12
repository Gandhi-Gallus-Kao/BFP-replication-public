clear
set more off, perm
est clear
clear frames

cap log close

do "$BFPrep_codedir/make_globals.do"

global sample = 0
log using "$logdir/fig1_cohort_stats_$sample.log", replace

if $sample == 1 {
    local indir "${anadatadir}/BabyConnect/sample"
}
else {
    local indir "${anadatadir}/BabyConnect/full"
}

************************************************************
* FIGURE 1 COHORT STATISTICAL TESTS
*
* 1. Regular age cohorts
* 2. Intersection age cohorts
*
* Tests:
*   - ANOVA of daily milk-production duration
*   - Bonferroni-adjusted pairwise comparisons
*   - ANOVA of daily milk-production sessions
*   - Bonferroni-adjusted pairwise comparisons
************************************************************

foreach sample_type in regular intersection {

    display as text _newline "=================================================="
    display as text "FIGURE 1 COHORT TESTS: `sample_type'"
    display as text "=================================================="

    * Load appropriate analysis dataset
    if "`sample_type'" == "regular" {

        use "`indir'/figure1_cohort_analysis_data.dta", clear

        recode age_day ///
            (0/90 = 1 "<90 days") ///
            (91/180 = 2 "91 - 180 days") ///
            (181/365 = 3 "181 - 365 days") ///
            (else = 9), gen(age_cohort)
    }
    else {

        use "`indir'/figure1_cohort_analysis_data_intrsct.dta", clear

        * age_cohort is already defined in this dataset
    }

    keep if milk_producing

    ********************************************************
    * Construct child-day analysis observations
    ********************************************************

    gcollapse ///
        (sum) duration ///
        (max) milk_producing ///
        (sum) obs_milk = milk_producing, ///
        by(childid startdate activity age_cohort)

    gen dur_milk = duration if milk_producing == 1
    keep if milk_producing == 1

    gcollapse (sum) dur_milk obs_milk, ///
        by(startdate childid age_cohort)

    * Report test sample sizes
    display as text _newline "Sample sizes by age cohort:"
    tabulate age_cohort

    ********************************************************
    * FIGURE 1A: DAILY MILK-PRODUCTION DURATION
    ********************************************************

    display as text _newline "------------------------------------------"
    display as text "Daily milk-production duration (minutes)"
    display as text "------------------------------------------"

    anova dur_milk age_cohort

    display as text _newline "Bonferroni pairwise comparisons:"
    pwmean dur_milk, over(age_cohort) mcompare(bonferroni)

    ********************************************************
    * FIGURE 1B: DAILY MILK-PRODUCTION SESSIONS
    ********************************************************

    display as text _newline "------------------------------------------"
    display as text "Daily milk-production sessions"
    display as text "------------------------------------------"

    anova obs_milk age_cohort

    display as text _newline "Bonferroni pairwise comparisons:"
    pwmean obs_milk, over(age_cohort) mcompare(bonferroni)

}

log close