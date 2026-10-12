# Makefile
# SPDX-License-Identifier: MIT
# See LICENSE file in the repository root for full license text.

# Commands — edit these to match your local installation
# Examples:  STATA_BIN=/usr/local/stata17/stata-mp   (Linux)
#            STATA_BIN=/Applications/Stata/StataSE.app/Contents/MacOS/stata-se   (macOS)
# Stata is run through setup/run_stata.sh, which runs `$(STATA_BIN) -b do <file>`
# and fails the Make step if the Stata log ends in an error (r(NNN);). Plain
# `stata -b do` returns exit code 0 even on errors which are unnoticed by Make.
STATA_BIN ?= stata-mp
PYTHON    ?= python3

# Directories — edit these to match your local paths
SRC_DIR           ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

export STATA_BIN
STATA ?= bash $(SRC_DIR)/setup/run_stata.sh
DATA_DIR          ?= $(abspath $(SRC_DIR)/../data)
OUTPUT_DIR        ?= $(abspath $(SRC_DIR)/../output)

## Code
CLEAN_CODE_DIR    := $(SRC_DIR)/cleaning
ANALYSIS_CODE_DIR := $(SRC_DIR)/analysis
MISC_CODE_DIR     := $(ANALYSIS_CODE_DIR)/misc

## Data
RAW_DIR           := $(DATA_DIR)/Raw/BabyConnect
INTER_DIR         := $(DATA_DIR)/Intermediate/BabyConnect
ANA_DIR           := $(DATA_DIR)/Analysis/BabyConnect/full

## Figures
FIG_DIR           := $(OUTPUT_DIR)/Subfigures/full
APDX_DIR          := $(FIG_DIR)/appendix
APDX_CODE_DIR     := $(ANALYSIS_CODE_DIR)/figures/appendix

## Tables / Stats
STATS_CODE_DIR      := $(ANALYSIS_CODE_DIR)/stats
TABLE_DIR           := $(OUTPUT_DIR)/Tables/full

## Replication mode: USE_SYNTHETIC=1 generates synthetic data directly,
## while USE_SYNTHETIC=0 processes the confidential raw data.
##   make USE_SYNTHETIC=1 all
USE_SYNTHETIC ?= 1
# Exported so Stata scripts can read it (nurse_only_sample_restriction.do)
export USE_SYNTHETIC


##############################################################################
# Create all output directories (runs before any target that needs them)
##############################################################################

OUTDIRS := \
	$(DATA_DIR)/Raw/BabyConnect \
	$(DATA_DIR)/Intermediate/BabyConnect \
	$(DATA_DIR)/Analysis/BabyConnect/full \
	$(OUTPUT_DIR)/Log \
	$(OUTPUT_DIR)/Subfigures/full/fig1 \
	$(OUTPUT_DIR)/Subfigures/full/fig2 \
	$(OUTPUT_DIR)/Subfigures/full/fig3 \
	$(OUTPUT_DIR)/Subfigures/full/fig4 \
	$(OUTPUT_DIR)/Subfigures/full/appendix/first_year \
	$(OUTPUT_DIR)/Tables/full

dirs:
	mkdir -p $(OUTDIRS)

.PHONY: dirs


ifeq ($(USE_SYNTHETIC),1)
##############################################################################
# Synthetic path — generate bc_full_sample_formatted.dta directly
##############################################################################

SYNTH_SCRIPT := $(SRC_DIR)/replication/generate_synthetic.py

$(ANA_DIR)/bc_full_sample_formatted.dta: $(SYNTH_SCRIPT) | dirs
	$(PYTHON) $< --output $@

else
##############################################################################
# Full pipeline — requires raw BabyConnect CSVs (steps 0-3)
##############################################################################

# Step 0: Install Stata dependencies (gtools, reghdfe, ftools)
STATA_DEPS_STAMP := $(INTER_DIR)/.stata_deps_done

$(STATA_DEPS_STAMP): $(SRC_DIR)/setup/install_stata_deps.do | dirs
	$(STATA) $<
	touch $@

# Step 1: Python import — raw CSVs → 162 individual .dta files
RAW_INPUTS := $(patsubst %,$(RAW_DIR)/bc-anon-2211-%.csv,$(shell seq 1 162))
RAW_STAMP  := $(INTER_DIR)/raw_bc_stata/.import_done

$(RAW_STAMP): $(CLEAN_CODE_DIR)/importing/data_clean_import.py $(RAW_INPUTS)
	mkdir -p $(dir $@)
	$(PYTHON) $<
	touch $@

# Step 2: Stata import — 162 raw .dta files → bc_full_cleaned.dta
$(INTER_DIR)/bc_full_cleaned.dta: \
	$(CLEAN_CODE_DIR)/importing/bc_import_part.do \
	$(RAW_STAMP) \
	$(STATA_DEPS_STAMP)
	$(STATA) $<

# Step 3: Format data → bc_full_sample_formatted.dta
$(ANA_DIR)/bc_full_sample_formatted.dta: \
	$(CLEAN_CODE_DIR)/prep/bc_data_format.do \
	$(INTER_DIR)/bc_full_cleaned.dta
	$(STATA) $<

endif

##############################################################################
# Step 4: Sample creation — figures 1–4 analysis datasets
##############################################################################

SAMPLE_CREATION_OUTPUTS := \
	$(ANA_DIR)/figure1_analysis_data.dta \
	$(ANA_DIR)/figure1cd_analysis_data.dta \
	$(ANA_DIR)/figure1_analysis_nurse_only_data.dta \
	$(ANA_DIR)/figure1cd_analysis_nurse_only_data.dta \
	$(ANA_DIR)/figure1cd_cohort_analysis_data.dta \
	$(ANA_DIR)/figure1cd_analysis_data_8_8.dta \
	$(ANA_DIR)/figure1_cohort_analysis_data.dta \
	$(ANA_DIR)/figure23_analysis_data.dta \
	$(ANA_DIR)/figure123_analysis_feed_data.dta \
	$(ANA_DIR)/figure1cd_analysis_feed_data.dta \
	$(ANA_DIR)/figure1_analysis_feed_data.dta \
	$(ANA_DIR)/figure4_base_data.dta \
	$(ANA_DIR)/milk_prod_obs_pctile.dta \
	$(ANA_DIR)/figure4_analysis_data_week.dta \
	$(ANA_DIR)/childid_age_fe.dta \
	$(ANA_DIR)/logcoef_all.ster

SAMPLE_CREATION_STAMP := $(ANA_DIR)/.sample_creation_done

$(SAMPLE_CREATION_STAMP): \
	$(CLEAN_CODE_DIR)/prep/sample_creation.do \
	$(CLEAN_CODE_DIR)/prep/cleaning_tools.do \
	$(CLEAN_CODE_DIR)/prep/base_sample_restriction.do \
	$(CLEAN_CODE_DIR)/prep/feed_sample_restriction.do \
	$(CLEAN_CODE_DIR)/prep/nurse_only_sample_restriction.do \
	$(CLEAN_CODE_DIR)/prep/conversion_sample_restriction.do \
	$(CLEAN_CODE_DIR)/prep/conversion_estimation.do \
	$(CLEAN_CODE_DIR)/prep/conversion_imputation.do \
	$(CLEAN_CODE_DIR)/prep/prep_milk_prod_pct_restrict_graph.do \
	$(CLEAN_CODE_DIR)/prep/feeding_partition_generic.do \
	$(CLEAN_CODE_DIR)/prep/daytime_nighttime_generic.do \
	$(ANA_DIR)/bc_full_sample_formatted.dta | dirs
	$(STATA) $<
	touch $@

$(SAMPLE_CREATION_OUTPUTS): $(SAMPLE_CREATION_STAMP)

##############################################################################
# Step 5a: Figure 2/3 regression preparation
##############################################################################

FIG23_PREP_OUTPUTS := \
	$(ANA_DIR)/fig23_regression_results.dta \
	$(ANA_DIR)/fig23_prediction_results.dta

FIG23_PREP_STAMP := $(ANA_DIR)/.fig23_prep_done

$(FIG23_PREP_STAMP): \
	$(ANALYSIS_CODE_DIR)/figures/main/fig23_prep.do \
	$(ANA_DIR)/figure23_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG23_PREP_OUTPUTS): $(FIG23_PREP_STAMP)

##############################################################################
# Step 5b: Figure 2/3 balanced regression preparation
# NOTE: Skipped under USE_SYNTHETIC=1. This step requires children who record
# every day for ~365 consecutive days ("super-recorders"). Such children exist
# in the full confidential dataset but cannot be reliably synthesized; the
# balanced-panel appendix figure is therefore not produced in the synthetic path.
##############################################################################

ifneq ($(USE_SYNTHETIC),1)

FIG23_BALANCED_PREP_OUTPUTS := \
	$(ANA_DIR)/fig23_balanced_apdx_regression_results.dta \
	$(ANA_DIR)/fig23_balanced_apdx_prediction_results.dta

FIG23_BALANCED_PREP_STAMP := $(ANA_DIR)/.fig23_balanced_prep_done

$(FIG23_BALANCED_PREP_STAMP): \
	$(APDX_CODE_DIR)/fig23_balanced_prep.do \
	$(ANA_DIR)/figure23_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG23_BALANCED_PREP_OUTPUTS): $(FIG23_BALANCED_PREP_STAMP)

endif

##############################################################################
# Step 5c: Figure 2/3 feeding regression preparation
##############################################################################

FIG23_FEED_PREP_OUTPUTS := \
	$(ANA_DIR)/fig23_feed_regression_results.dta \
	$(ANA_DIR)/fig23_feed_prediction_results.dta

FIG23_FEED_PREP_STAMP := $(ANA_DIR)/.fig23_feed_prep_done

$(FIG23_FEED_PREP_STAMP): \
	$(APDX_CODE_DIR)/fig23_feed_prep.do \
	$(ANA_DIR)/figure123_analysis_feed_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG23_FEED_PREP_OUTPUTS): $(FIG23_FEED_PREP_STAMP)

##############################################################################
# Step 6: Figure 1
##############################################################################

FIG1_OUTPUTS := \
	$(FIG_DIR)/fig1/1a_milk_dur_hist.pdf \
	$(FIG_DIR)/fig1/1b_milk_obs_hist.pdf \
	$(FIG_DIR)/fig1/1c_uninterrupted_day_1.pdf \
	$(FIG_DIR)/fig1/1c_uninterrupted_day_2.pdf \
	$(FIG_DIR)/fig1/1c_uninterrupted_day_3.pdf \
	$(FIG_DIR)/fig1/1c_uninterrupted_day_4.pdf \
	$(FIG_DIR)/fig1/1d_milk_prod_night_count.pdf

FIG1_STAMP := $(FIG_DIR)/fig1/.fig1_done

$(FIG1_STAMP): \
	$(ANALYSIS_CODE_DIR)/figures/main/fig1_graphs.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(MISC_CODE_DIR)/fig1_labels.do \
	$(ANA_DIR)/figure1_analysis_data.dta \
	$(ANA_DIR)/figure1cd_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG1_OUTPUTS): $(FIG1_STAMP)

##############################################################################
# Step 7: Figures 2 and 3 (paper) — both produced by fig23_graphs.do
##############################################################################

FIG23_OUTPUTS := \
    $(FIG_DIR)/fig2/2_milk_logdur_margins_30.pdf \
    $(FIG_DIR)/fig3/3_milk_logdur_sums_30.pdf \
    $(APDX_DIR)/3_milk_logdur_sums_30_vot.pdf

FIG23_STAMP := $(FIG_DIR)/fig3/.fig23_done

$(FIG23_STAMP): \
	$(ANALYSIS_CODE_DIR)/figures/main/fig23_graphs.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(FIG23_PREP_STAMP) | dirs
	$(STATA) $<
	touch $@

$(FIG23_OUTPUTS): $(FIG23_STAMP)

##############################################################################
# Step 8: Figure 4
##############################################################################

FIG4_OUTPUTS := \
	$(FIG_DIR)/fig4/4a_cf_bottle_dur.pdf \
	$(FIG_DIR)/fig4/4a_cf_bottle_dur_atus_22_23.pdf \
	$(FIG_DIR)/fig4/4b_histogram_save_pct_diff_log.pdf \
	$(FIG_DIR)/fig4/4b_ordered_save_pct_diff_log.pdf \
	$(FIG_DIR)/fig4/4c_histogram_outsrcble_pct_log.pdf \
	$(FIG_DIR)/fig4/4c_ordered_outsrcble_pct_log.pdf \
	$(ANA_DIR)/figure4a_analysis_data_ci.csv \
	$(ANA_DIR)/figure4a_analysis_data_ci.dta

FIG4_STAMP := $(FIG_DIR)/fig4/.fig4_done

$(FIG4_STAMP): \
	$(ANALYSIS_CODE_DIR)/figures/main/fig4_graphs.do \
	$(ANALYSIS_CODE_DIR)/figures/main/fig4a_graph.py \
	$(CLEAN_CODE_DIR)/prep/figure4_delta_ci.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(ANA_DIR)/figure4_analysis_data_week.dta \
	$(ANA_DIR)/logcoef_all.ster | dirs
	$(STATA) $<
	touch $@

$(FIG4_OUTPUTS): $(FIG4_STAMP)

##############################################################################
# Step 9: Figure 1 by age cohort (appendix)
##############################################################################

FIRST_YEAR_DIR := $(APDX_DIR)/first_year

FIG1COH_OUTPUTS := \
	$(FIRST_YEAR_DIR)/1a_milk_dur_hist_cohort_1.pdf \
	$(FIRST_YEAR_DIR)/1a_milk_dur_hist_cohort_2.pdf \
	$(FIRST_YEAR_DIR)/1a_milk_dur_hist_cohort_3.pdf \
	$(FIRST_YEAR_DIR)/1b_milk_obs_hist_cohort_1.pdf \
	$(FIRST_YEAR_DIR)/1b_milk_obs_hist_cohort_2.pdf \
	$(FIRST_YEAR_DIR)/1b_milk_obs_hist_cohort_3.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_1_1.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_1_2.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_1_3.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_1_4.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_2_1.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_2_2.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_2_3.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_2_4.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_3_1.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_3_2.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_3_3.pdf \
	$(FIRST_YEAR_DIR)/1c_uninterrupted_day_cohort_3_4.pdf \
	$(FIRST_YEAR_DIR)/1d_milk_prod_night_count_cohort_1.pdf \
	$(FIRST_YEAR_DIR)/1d_milk_prod_night_count_cohort_2.pdf \
	$(FIRST_YEAR_DIR)/1d_milk_prod_night_count_cohort_3.pdf

FIG1COH_STAMP := $(FIRST_YEAR_DIR)/.fig1_coh_done

$(FIG1COH_STAMP): \
	$(APDX_CODE_DIR)/fig1_cohort_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(MISC_CODE_DIR)/fig1_cohort_labels.do \
	$(ANA_DIR)/figure1_cohort_analysis_data.dta \
	$(ANA_DIR)/figure1cd_cohort_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG1COH_OUTPUTS): $(FIG1COH_STAMP)

##############################################################################
# Step 10: Figure 1 feeding and 8-8 appendix
##############################################################################

FIG1_APDX_OUTPUTS := \
	$(APDX_DIR)/1a_feed_dur_hist_apdx.pdf \
	$(APDX_DIR)/1b_feed_obs_hist_apdx.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_feed_apdx_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_feed_apdx_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_feed_apdx_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_feed_apdx_4.pdf \
	$(APDX_DIR)/1d_feed_night_count_apdx.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_8_8_apdx_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_8_8_apdx_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_8_8_apdx_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_8_8_apdx_4.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_8_8_apdx.pdf

FIG1_APDX_STAMP := $(APDX_DIR)/.fig1_apdx_done

$(FIG1_APDX_STAMP): \
	$(APDX_CODE_DIR)/fig1_feed_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(MISC_CODE_DIR)/fig1_labels_apdx.do \
	$(ANA_DIR)/figure1_analysis_feed_data.dta \
	$(ANA_DIR)/figure1cd_analysis_feed_data.dta \
	$(ANA_DIR)/figure1cd_analysis_data_8_8.dta | dirs
	$(STATA) $<
	touch $@

$(FIG1_APDX_OUTPUTS): $(FIG1_APDX_STAMP)

##############################################################################
# Step 11: Figure 1 year comparison (appendix)
##############################################################################

FIG1_COMPARE_OUTPUTS := \
	$(APDX_DIR)/1a_milk_dur_hist_comparison.pdf \
	$(APDX_DIR)/1b_milk_obs_hist_comparison.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_1_comparison.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_2_comparison.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_3_comparison.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_4_comparison.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_comparison.pdf

FIG1_COMPARE_STAMP := $(APDX_DIR)/.fig1_compare_done

$(FIG1_COMPARE_STAMP): \
	$(APDX_CODE_DIR)/fig1_year_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(ANA_DIR)/figure1_analysis_data.dta \
	$(ANA_DIR)/figure1cd_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG1_COMPARE_OUTPUTS): $(FIG1_COMPARE_STAMP)

##############################################################################
# Step 12: Cohort selection graph and intersect datasets
##############################################################################

COHORT_OUTPUTS := \
	$(APDX_DIR)/entry_exit_cohort.pdf \
	$(ANA_DIR)/figure1_cohort_analysis_data_intrsct.dta \
	$(ANA_DIR)/figure1cd_analysis_data_intrsct.dta

COHORT_STAMP := $(ANA_DIR)/.cohort_done

$(COHORT_STAMP): \
	$(CLEAN_CODE_DIR)/prep/cohort_selection.do \
	$(CLEAN_CODE_DIR)/prep/feeding_partition_generic.do \
	$(CLEAN_CODE_DIR)/prep/daytime_nighttime_generic.do \
	$(ANA_DIR)/figure1_cohort_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(COHORT_OUTPUTS): $(COHORT_STAMP)

##############################################################################
# Step 13: Figure 1 cohort intersect appendix
##############################################################################

FIG1COH_INTRSCT_OUTPUTS := \
	$(APDX_DIR)/1a_milk_dur_hist_cohort_intrsct_1.pdf \
	$(APDX_DIR)/1a_milk_dur_hist_cohort_intrsct_2.pdf \
	$(APDX_DIR)/1a_milk_dur_hist_cohort_intrsct_3.pdf \
	$(APDX_DIR)/1b_milk_obs_hist_cohort_intrsct_1.pdf \
	$(APDX_DIR)/1b_milk_obs_hist_cohort_intrsct_2.pdf \
	$(APDX_DIR)/1b_milk_obs_hist_cohort_intrsct_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_1_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_1_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_1_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_1_4.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_2_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_2_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_2_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_2_4.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_3_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_3_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_3_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_cohort_intrsct_3_4.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_cohort_intrsct_1.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_cohort_intrsct_2.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_cohort_intrsct_3.pdf

FIG1COH_INTRSCT_STAMP := $(APDX_DIR)/.fig1_coh_intrsct_done

$(FIG1COH_INTRSCT_STAMP): \
	$(APDX_CODE_DIR)/fig1_cohort_intersect_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(MISC_CODE_DIR)/fig1_cohort_labels_apdx.do \
	$(ANA_DIR)/figure1_cohort_analysis_data_intrsct.dta \
	$(ANA_DIR)/figure1cd_analysis_data_intrsct.dta | dirs
	$(STATA) $<
	touch $@

$(FIG1COH_INTRSCT_OUTPUTS): $(FIG1COH_INTRSCT_STAMP)

##############################################################################
# Step 14: Figure 3 balanced-panel appendix (real data only)
##############################################################################

ifneq ($(USE_SYNTHETIC),1)

FIG23_FULL_OUTPUTS := \
	$(APDX_DIR)/3_milk_logdur_sums_30_full.pdf \
	$(APDX_DIR)/2_milk_logdur_margins_30_full.pdf

FIG23_FULL_STAMP := $(APDX_DIR)/.fig23_full_done

$(FIG23_FULL_STAMP): \
	$(APDX_CODE_DIR)/fig23_balanced_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(FIG23_BALANCED_PREP_STAMP) | dirs
	$(STATA) $<
	touch $@

$(FIG23_FULL_OUTPUTS): $(FIG23_FULL_STAMP)

endif

##############################################################################
# Step 15: Figures 2 and 3 feeding appendix
##############################################################################

FIG23_FEED_OUTPUTS := \
	$(APDX_DIR)/2_feed_logdur_margins_30.pdf \
	$(APDX_DIR)/3_feed_logdur_sums_30.pdf

FIG23_FEED_STAMP := $(APDX_DIR)/.fig23_feed_done

$(FIG23_FEED_STAMP): \
	$(APDX_CODE_DIR)/fig23_feed_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(FIG23_FEED_PREP_STAMP) | dirs
	$(STATA) $<
	touch $@

$(FIG23_FEED_OUTPUTS): $(FIG23_FEED_STAMP)

##############################################################################
# Step 16: Milk production restriction graph (365 days)
##############################################################################

MILK_PROD_OUTPUTS := \
	$(APDX_DIR)/milk_production_count_365_day.pdf

MILK_PROD_STAMP := $(APDX_DIR)/.milk_prod_done

$(MILK_PROD_STAMP): \
	$(APDX_CODE_DIR)/milk_prod_apdx.do \
	$(ANA_DIR)/milk_prod_obs_pctile.dta | dirs
	$(STATA) $<
	touch $@

$(MILK_PROD_OUTPUTS): $(MILK_PROD_STAMP)

##############################################################################
# Step 17: Regression coefficient margins plot
##############################################################################

MARGINS_OUTPUTS := \
	$(APDX_DIR)/reg_coef_marginsplot.pdf

MARGINS_STAMP := $(APDX_DIR)/.margins_done

$(MARGINS_STAMP): \
	$(APDX_CODE_DIR)/margins_apdx.do \
	$(ANA_DIR)/bc_full_sample_formatted.dta | dirs
	$(STATA) $<
	touch $@

$(MARGINS_OUTPUTS): $(MARGINS_STAMP)

##############################################################################
# Step 18: Figure 4 appendix (session-type histograms and intersect cohort)
##############################################################################

FIG4_APDX_OUTPUTS := \
	$(APDX_DIR)/4_hist_pure.pdf \
	$(APDX_DIR)/4_hist_mixed.pdf \
	$(APDX_DIR)/4a_cf_bottle_dur_intrsct.pdf \
	$(APDX_DIR)/4b_histogram_save_pct_diff_log_intrsct.pdf \
	$(APDX_DIR)/4b_ordered_save_pct_diff_log_intrsct.pdf \
	$(APDX_DIR)/4c_histogram_outsrcble_pct_log_intrsct.pdf \
	$(APDX_DIR)/4c_ordered_outsrcble_pct_log_intrsct.pdf \
	$(ANA_DIR)/figure4a_analysis_intrsct_data_ci.csv \
	$(ANA_DIR)/figure4a_analysis_intrsct_data_ci.dta

FIG4_APDX_STAMP := $(APDX_DIR)/.fig4_hist_intrsct_apdx_done

$(FIG4_APDX_STAMP): \
	$(APDX_CODE_DIR)/fig4_hist_intrsct_apdx.do \
	$(CLEAN_CODE_DIR)/prep/figure4_delta_ci.do \
	$(ANALYSIS_CODE_DIR)/figures/main/fig4a_graph.py \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(ANA_DIR)/figure4_analysis_data_week.dta \
	$(ANA_DIR)/logcoef_all.ster | dirs
	$(STATA) $<
	touch $@

$(FIG4_APDX_OUTPUTS): $(FIG4_APDX_STAMP)

##############################################################################
# Step 19: Figure 4 first quarter appendix
##############################################################################

FIG4_FIRST_QTR_OUTPUTS := \
	$(APDX_DIR)/4a_cf_bottle_dur_first_quarter.pdf \
	$(APDX_DIR)/4b_histogram_save_pct_diff_log_first_quarter.pdf \
	$(APDX_DIR)/4b_ordered_save_pct_diff_log_first_quarter.pdf \
	$(APDX_DIR)/4c_histogram_outsrcble_pct_log_first_quarter.pdf \
	$(APDX_DIR)/4c_ordered_outsrcble_pct_log_first_quarter.pdf \
	$(ANA_DIR)/figure4a_first_quarter_data_ci.csv \
	$(ANA_DIR)/figure4a_first_quarter_data_ci.dta

FIG4_FIRST_QTR_STAMP := $(APDX_DIR)/.fig4_first_qtr_done

$(FIG4_FIRST_QTR_STAMP): \
	$(APDX_CODE_DIR)/fig4_first_qtr_apdx.do \
	$(CLEAN_CODE_DIR)/prep/figure4_delta_ci.do \
	$(ANALYSIS_CODE_DIR)/figures/main/fig4a_graph.py \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(ANA_DIR)/figure4_analysis_data_week.dta \
	$(ANA_DIR)/logcoef_all.ster | dirs
	$(STATA) $<
	touch $@

$(FIG4_FIRST_QTR_OUTPUTS): $(FIG4_FIRST_QTR_STAMP)

##############################################################################
# Step 20: Breastfeeding continuation curve appendix
##############################################################################

CONTINUATION_CURVE_OUTPUTS := \
	$(APDX_DIR)/continuation_survival_app_vs_cdc.pdf

CONTINUATION_CURVE_DERIVED_DATA := \
	$(ANA_DIR)/feed_full_data.dta

CONTINUATION_CURVE_STAMP := $(APDX_DIR)/.continuation_curve_done

$(CONTINUATION_CURVE_STAMP): \
	$(APDX_CODE_DIR)/continuation_curve.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(CLEAN_CODE_DIR)/prep/cleaning_tools.do \
	$(CLEAN_CODE_DIR)/prep/cont_curve_sample_restriction.do \
	$(ANA_DIR)/bc_full_sample_formatted.dta \
	$(ANA_DIR)/figure1_analysis_feed_data.dta | dirs
	$(STATA) $<
	touch $@

$(CONTINUATION_CURVE_OUTPUTS): $(CONTINUATION_CURVE_STAMP)

$(CONTINUATION_CURVE_DERIVED_DATA): $(CONTINUATION_CURVE_STAMP)

##############################################################################
# Step 21: Figure 1 narrower age-window appendix
##############################################################################

FIG1_AGE_WINDOWS_APDX_OUTPUTS := \
	$(APDX_DIR)/1a_milk_dur_hist_31_60.pdf \
	$(APDX_DIR)/1a_milk_dur_hist_61_90.pdf \
	$(APDX_DIR)/1b_milk_obs_hist_31_60.pdf \
	$(APDX_DIR)/1b_milk_obs_hist_61_90.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_31_60_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_31_60_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_31_60_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_31_60_4.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_61_90_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_61_90_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_61_90_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_61_90_4.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_31_60.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_61_90.pdf

FIG1_AGE_WINDOWS_APDX_STAMP := $(APDX_DIR)/.fig1_age_windows_apdx_done

$(FIG1_AGE_WINDOWS_APDX_STAMP): \
	$(APDX_CODE_DIR)/fig1_age_windows_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(MISC_CODE_DIR)/fig1_labels_apdx.do \
	$(ANA_DIR)/figure1_analysis_data.dta \
	$(ANA_DIR)/figure1cd_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG1_AGE_WINDOWS_APDX_OUTPUTS): $(FIG1_AGE_WINDOWS_APDX_STAMP)

##############################################################################
# Step 22: Figure 1 nursing-only appendix
##############################################################################

FIG1_NURSING_ONLY_APDX_OUTPUTS := \
	$(APDX_DIR)/1a_milk_dur_hist_nurse_only.pdf \
	$(APDX_DIR)/1b_milk_obs_hist_nurse_only.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_nurse_only_1.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_nurse_only_2.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_nurse_only_3.pdf \
	$(APDX_DIR)/1c_uninterrupted_day_nurse_only_4.pdf \
	$(APDX_DIR)/1d_milk_prod_night_count_nurse_only.pdf

FIG1_NURSING_ONLY_APDX_STAMP := $(APDX_DIR)/.fig1_nursing_only_apdx_done

$(FIG1_NURSING_ONLY_APDX_STAMP): \
	$(APDX_CODE_DIR)/fig1_nursing_only_apdx.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(MISC_CODE_DIR)/fig1_labels_apdx.do \
	$(ANA_DIR)/figure1_analysis_data.dta \
	$(ANA_DIR)/figure1_analysis_nurse_only_data.dta \
	$(ANA_DIR)/figure1cd_analysis_nurse_only_data.dta | dirs
	$(STATA) $<
	touch $@

$(FIG1_NURSING_ONLY_APDX_OUTPUTS): $(FIG1_NURSING_ONLY_APDX_STAMP)

##############################################################################
# Step 23: Nighttime robustness appendix
##############################################################################

NIGHTTIME_ROBUSTNESS_OUTPUTS := \
	$(APDX_DIR)/1d_milk_prod_night_count_late_loggers.pdf \
	$(APDX_DIR)/night_hour_logging_dist.pdf

NIGHTTIME_ROBUSTNESS_STAMP := $(APDX_DIR)/.nighttime_robustness_done

$(NIGHTTIME_ROBUSTNESS_STAMP): \
	$(APDX_CODE_DIR)/nighttime_robustness.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(MISC_CODE_DIR)/plot_functions.do \
	$(ANA_DIR)/figure1cd_analysis_data.dta \
	$(ANA_DIR)/figure1_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(NIGHTTIME_ROBUSTNESS_OUTPUTS): $(NIGHTTIME_ROBUSTNESS_STAMP)

##############################################################################
# Step 24: Pumping share by child age appendix
##############################################################################

PUMPING_BY_AGE_OUTPUTS := \
	$(APDX_DIR)/avg_pumping_share_by_age_ma7.pdf

PUMPING_BY_AGE_STAMP := $(APDX_DIR)/.pumping_by_age_done

$(PUMPING_BY_AGE_STAMP): \
	$(APDX_CODE_DIR)/pumping_by_age.do \
	$(MISC_CODE_DIR)/label_functions.do \
	$(ANA_DIR)/figure23_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(PUMPING_BY_AGE_OUTPUTS): $(PUMPING_BY_AGE_STAMP)

##############################################################################
# Step 25: Summary statistics tables
##############################################################################

TABLE_OUTPUTS := \
	$(TABLE_DIR)/stats_by_country.tex \
	$(TABLE_DIR)/stats_by_year.tex

TABLES_STAMP := $(TABLE_DIR)/.tables_done

$(TABLES_STAMP): \
	$(STATS_CODE_DIR)/summary_tables.do \
	$(ANA_DIR)/figure23_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

$(TABLE_OUTPUTS): $(TABLES_STAMP)

##############################################################################
# Step 26: Sample descriptive statistics
##############################################################################

SAMPLE_SUMMARY_STAMP := $(ANA_DIR)/.sample_summary_done

$(SAMPLE_SUMMARY_STAMP): \
	$(STATS_CODE_DIR)/sample_summary.do \
	$(ANA_DIR)/figure23_analysis_data.dta \
	$(ANA_DIR)/figure4_base_data.dta \
	$(ANA_DIR)/childid_age_fe.dta \
	$(ANA_DIR)/figure1_cohort_analysis_data.dta | dirs
	$(STATA) $<
	touch $@

.PHONY: sample_summary
sample_summary: $(SAMPLE_SUMMARY_STAMP)

##############################################################################
# Step 27: Figure 1 cohort statistical tests
# Regular and intersection cohorts
##############################################################################

FIG1_COHORT_STATS_STAMP := $(ANA_DIR)/.fig1_cohort_stats_done

$(FIG1_COHORT_STATS_STAMP): \
	$(STATS_CODE_DIR)/fig1_cohort_stats.do \
	$(SAMPLE_CREATION_OUTPUTS) \
	$(COHORT_OUTPUTS) | dirs
	$(STATA) $<
	touch $@

.PHONY: fig1_cohort_stats
fig1_cohort_stats: $(FIG1_COHORT_STATS_STAMP)

##############################################################################
# Convenience targets
##############################################################################

# The balanced-panel appendix figure is only built with real data
ifeq ($(USE_SYNTHETIC),1)
BALANCED_APDX_TARGETS :=
else
BALANCED_APDX_TARGETS := $(FIG23_FULL_OUTPUTS)
endif

.PHONY: all all_figures all_apdx_figures all_tables analysis_data synthetic

synthetic: $(ANA_DIR)/bc_full_sample_formatted.dta

analysis_data: $(SAMPLE_CREATION_STAMP)

all_figures: $(FIG1_OUTPUTS) $(FIG23_OUTPUTS) $(FIG4_OUTPUTS)

all_apdx_figures: \
	$(FIG1COH_OUTPUTS) \
	$(FIG1_APDX_OUTPUTS) \
	$(FIG1_COMPARE_OUTPUTS) \
	$(COHORT_OUTPUTS) \
	$(FIG1COH_INTRSCT_OUTPUTS) \
	$(BALANCED_APDX_TARGETS) \
	$(FIG23_FEED_OUTPUTS) \
	$(MILK_PROD_OUTPUTS) \
	$(MARGINS_OUTPUTS) \
	$(FIG4_APDX_OUTPUTS) \
	$(FIG4_FIRST_QTR_OUTPUTS) \
	$(CONTINUATION_CURVE_OUTPUTS) \
	$(FIG1_AGE_WINDOWS_APDX_OUTPUTS) \
	$(FIG1_NURSING_ONLY_APDX_OUTPUTS) \
	$(NIGHTTIME_ROBUSTNESS_OUTPUTS) \
	$(PUMPING_BY_AGE_OUTPUTS)

all_tables: $(TABLE_OUTPUTS)

all: analysis_data all_figures all_apdx_figures all_tables sample_summary fig1_cohort_stats
	@echo "=== Pipeline complete: all outputs generated ==="