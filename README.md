# Baby Connect replication package

This repository reproduces the Baby Connect analysis workflow. The pipeline is orchestrated by a Makefile that combines Stata and Python to build analysis datasets, main-paper figures, appendix figures, summary tables, and sample/cohort statistics reported in Stata logs. In the public replication path, the package uses a synthetic-data generator to create an analysis-ready Stata dataset directly; that path bypasses the confidential raw-data import steps.

The Makefile distinguishes between two modes:

- **Public replication path:** `USE_SYNTHETIC=1` (default). This calls `generate_synthetic.py` to create `bc_full_sample_formatted.dta` directly and then runs the downstream analysis pipeline.
- **Confidential/raw-data path:** `USE_SYNTHETIC=0`. This runs the raw CSV import and cleaning steps before formatting the analysis-ready dataset.

After either path creates `bc_full_sample_formatted.dta`, the pipeline runs `sample_creation.do` to build the figure-specific analysis datasets used by the second half of the package.

### Verification status

The synthetic-data path (`USE_SYNTHETIC=1`) has been validated end to end (`make USE_SYNTHETIC=1 analysis_data`, `all_figures`, then `all`). All steps completed without Stata or Python errors, and every output listed in the Makefile was produced, other than the balanced-panel appendix, which is skipped in synthetic mode. The confidential raw-data path (`USE_SYNTHETIC=0`) depends on data that are not included in this repository and was not run as part of this validation. Accordingly, this repository should be understood as a public replication package adapted for confidential-data constraints.

## 1. System requirements

### Operating system

The scripts are written for a **Unix-like environment**.

- **Linux** is the main target implied by the Makefile and the absolute paths used in the scripts.
- **macOS** should also work with path edits and a shell-accessible Stata executable.
- No Windows-specific setup is provided.

### Software dependencies

#### Required

- **Stata/MP** (see "Versions tested on" below)
- **Python 3** (see "Versions tested on" below)
- **GNU Make**

#### Python packages

Install the following Python packages:

- `pandas` (2.2.1)
- `numpy` (1.26.4)
- `matplotlib` (3.9.0)

#### Stata packages

The setup materials indicate that the package installs or depends on the following user-written Stata packages.

**Installed from SSC:**

- `gtools` (1.11.8)
- `require` (1.3.1)
- `reghdfe` (6.12.3)
- `ftools` (2.49.1)
- `egenmore`
- `listtex`
- `winsor2` (1.1)

`gtools` also provides the `gcollapse`, `gdistinct` and `gisid` commands used by the scripts. The scripts use Stata's default variable-abbreviation setting.

### Versions tested on

The package was developed and tested with the following versions:

- **Stata/MP 19**
- **Python 3.11** (pandas 2.2.1, NumPy 1.26.4, matplotlib 3.9.0)
- **Stata packages:** `reghdfe` 6.12.3, `ftools` 2.49.1, `gtools` 1.11.8, `require` 1.3.1, `winsor2` 1.1 (`egenmore` and `listtex` are distributed without version numbers)

`setup/install_stata_deps.do` installs the current SSC versions, which may be newer than those listed. The synthetic path was also run without errors on `reghdfe` 6.13.1, `ftools` 2.50.0 and Python 3.9.12 (pandas 2.2.2, NumPy 1.26.3).

`profile.do` may optionally also set `python set exec /path/to/python3, permanently` (see Installation step 4) and, on Stata builds with a low default, `set maxvar`; the synthetic path ran with Stata's default `maxvar`.

### Non-standard hardware

No non-standard hardware is required.

- No GPU is needed.
- A standard desktop or laptop is sufficient for the synthetic-data replication path.
- For the full confidential-data path, more CPU time and substantial disk space are helpful, but no specialized hardware is required.

## 2. Installation guide

### Before installation

The Stata scripts expect globals such as `BFPrep_codedir`, `BFPrep_datadir`, and `BFPrep_outdir` to be defined so that `make_globals.do` can construct downstream paths. Stata loads `profile.do` automatically from its working directory at startup.

**Edit** the file `code/profile.do` (included in the repository as a template) and set the three paths to match your local directory layout:

```stata
global BFPrep_codedir "/path/to/BFP_replication/code"
global BFPrep_datadir "/path/to/BFP_replication/data"
global BFPrep_outdir  "/path/to/BFP_replication/output"
```

If these globals are missing or incorrect, the Stata scripts will fail because they call `make_globals.do` and then look for inputs and outputs relative to those globals.

**Important:** The Makefile also has its own `DATA_DIR` and `OUTPUT_DIR` variables (used to locate Make targets). These must point to the same directories as `BFPrep_datadir` and `BFPrep_outdir` in `profile.do`. Either edit the defaults at the top of the Makefile, or override them on the command line:

```bash
make DATA_DIR=/path/to/data OUTPUT_DIR=/path/to/output all
```

When running `data_clean_import.py` directly, configure the `BFP_DATADIR` and `BFP_OUTPUTDIR` environment variables, or update the directory paths in the script.

**Important:** All `make` commands must be run from the `code/` directory (where `profile.do` lives), so that Stata can find it:

```bash
cd code
make all
```

> **Note:** All `make` command examples in this README assume you have either edited the `DATA_DIR` and `OUTPUT_DIR` defaults at the top of the Makefile, or that you pass them on every `make` invocation. For brevity the examples below omit the overrides, but if you have not edited the Makefile defaults you must append `DATA_DIR=/path/to/data OUTPUT_DIR=/path/to/output` to every `make` command.

**Important:** The Makefile runs each Stata step through `code/setup/run_stata.sh`, which calls `$(STATA_BIN) -b do <file>` (default `STATA_BIN=stata-mp`). Stata's batch mode returns exit code 0 even when a do-file fails, so the wrapper checks the end of the Stata log for an `r(NNN);` error and makes the Make step fail if it finds one. If your Stata executable is not on `PATH` (common in HPC/server environments), override `STATA_BIN` on the command line or edit the default at the top of the Makefile:

```bash
make STATA_BIN=/usr/local/stata17/stata-mp all
```

Stata also writes a default `<name>.log` into `code/` for each step (gitignored; the wrapper reads it to detect errors). The detailed logs are in `<OUTPUT_DIR>/Log/`.

### Installation steps

1. Install Python dependencies:

```bash
python3.11 -m pip install pandas numpy matplotlib
```

Two Python interpreters are used: the one Stata is configured to use (for `fig4a_graph.py`, which needs `pandas`, `numpy` and `matplotlib`) and the `python3` on your `PATH` (Makefile variable `PYTHON`, used for `generate_synthetic.py` and the raw-data importer, which need `pandas` and `numpy`). They can be the same interpreter. To use a different one for the Makefile steps, pass `PYTHON=/path/to/python3` to `make`.

2. Install Stata dependencies (must be run from the `code/` directory so that `profile.do` is found and relative paths resolve correctly):

```bash
cd code
stata-mp -b do setup/install_stata_deps.do
```

3. Create the required directory structure (from the `code/` directory):

```bash
cd code
make dirs
```
In the public replication path (`USE_SYNTHETIC=1`), users do not need to provide any input data manually: `make dirs` creates the required directory structure, and `make all` generates the synthetic analysis-ready dataset automatically.

4. Verify that Stata can call Python, since Figure 4 scripts invoke Python from within Stata. To check, run:

```bash
cd code
echo 'python: print("ok")' > /tmp/check_python.do
stata-mp -b do /tmp/check_python.do
cat check_python.log   # should contain "ok" and no r(NNN); error
rm -f /tmp/check_python.do check_python.log
```

If this fails, you may need to tell Stata where Python lives by adding the following to `profile.do`:

```stata
python set exec /path/to/python3.11, permanently
```

If `python:` works but `python script ...` calls fail on your system, use a shell call instead (same script, explicit interpreter), for example:

```stata
python script "$anadir/figures/main/fig4a_graph.py", ///
  args("$indir" "$outdir" "`dataset_name'" 0 "default")
```

```stata
shell /path/to/python3 "$anadir/figures/main/fig4a_graph.py" "$indir" "$outdir" "`dataset_name'" 0 default
```

### Typical install time on a normal desktop computer

Installing software dependencies is typically **a few minutes to under 10 minutes**, assuming Stata is already installed and internet access is available for Stata package installation.

For runtime rather than installation:

- the **full confidential-data run** can take on the order of **60 hours**;
- the **public synthetic path** (`make USE_SYNTHETIC=1 all`) takes roughly **30 minutes** end to end.

## 3. Demo

### Demo goal

The recommended public demo is to generate the synthetic formatted dataset and the downstream figure-specific analysis datasets. These are the key handoff between the cleaning/import half of the package and the figure/table production half.

### Demo command

From the `code/` directory, run:

```bash
cd code
make analysis_data
```

> **Note:** `USE_SYNTHETIC=1` is the Makefile default, so you do not need to pass it explicitly. All `make` commands below include it for clarity, but a plain `make all` is equivalent to `make USE_SYNTHETIC=1 all`.

This will:

1. create the output directories,
2. generate `bc_full_sample_formatted.dta` using `generate_synthetic.py`,
3. run `sample_creation.do`, and
4. produce the figure-specific analysis datasets (and the conversion-model estimates, `logcoef_all.ster`) used by the later figure, table and statistics scripts.

### Expected output

At minimum, you should see the following files under the directories you configured as `DATA_DIR` and `OUTPUT_DIR` (shown here with relative paths):

```text
<DATA_DIR>/Analysis/BabyConnect/full/bc_full_sample_formatted.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1_analysis_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1cd_analysis_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1_analysis_nurse_only_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1cd_analysis_nurse_only_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1cd_analysis_data_8_8.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1_cohort_analysis_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1cd_cohort_analysis_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure23_analysis_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure123_analysis_feed_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1cd_analysis_feed_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure1_analysis_feed_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure4_base_data.dta
<DATA_DIR>/Analysis/BabyConnect/full/figure4_analysis_data_week.dta
<DATA_DIR>/Analysis/BabyConnect/full/milk_prod_obs_pctile.dta
<DATA_DIR>/Analysis/BabyConnect/full/childid_age_fe.dta
<DATA_DIR>/Analysis/BabyConnect/full/logcoef_all.ster
<OUTPUT_DIR>/Log/sample_creation_0.log
```

### Expected runtime for demo on a normal desktop computer

For the synthetic replication path, `make analysis_data` takes approximately **10–15 minutes** (of which generating the synthetic dataset itself takes roughly 4–5 minutes on a typical server).

## 4. Instructions for use

### A. Public replication path (synthetic data)

This is the intended path for users who do not have access to the confidential raw Baby Connect CSV files.

The balanced-panel appendix figure (`fig23_balanced_prep.do`, `fig23_balanced_apdx.do`; Steps 5b and 14 in the Makefile) requires children who record feeding on nearly every day for about a year, so it is skipped automatically when `USE_SYNTHETIC=1`.

Generate the synthetic formatted dataset only:

```bash
make USE_SYNTHETIC=1 synthetic
```

Generate the synthetic formatted dataset and all figure-specific analysis datasets:

```bash
make USE_SYNTHETIC=1 analysis_data
```

Generate the main-paper figures:

```bash
make USE_SYNTHETIC=1 all_figures
```

Generate appendix figures:

```bash
make USE_SYNTHETIC=1 all_apdx_figures
```

Generate summary tables:

```bash
make USE_SYNTHETIC=1 all_tables
```

Generate the sample descriptive statistics and the Figure 1 cohort statistical tests (reported in the Stata logs):

```bash
make USE_SYNTHETIC=1 sample_summary
make USE_SYNTHETIC=1 fig1_cohort_stats
```

Run the full public replication workflow:

```bash
make USE_SYNTHETIC=1 all
```

### B. Running on the confidential raw data

If you have authorized access to the original Baby Connect raw data:

1. Place the 162 raw CSV files in the raw-data directory expected by the pipeline, with names of the form:

```text
bc-anon-2211-1.csv
bc-anon-2211-2.csv
...
bc-anon-2211-162.csv
```

2. Set:

```bash
USE_SYNTHETIC=0
```

3. Run:

```bash
make all
```

This path performs Python import from raw CSV to intermediate `.dta` files, Stata append and formatting, sample creation, and all downstream analysis targets.

For confidential-data runs, `nurse_only_sample_restriction.do` applies the exclusive-nursing child restriction (`has_nursing == 1 & has_expr_bottle == 0`).

### C. What the second half of the package does

Once `analysis_data` has been built, the rest of the repository is mainly organized around three tasks: **figures**, **tables**, and **sample/cohort statistics** (reported in Stata logs).

#### Main-paper figures

- **Figure 1:** `analysis/figures/main/fig1_graphs.do` reads the Figure 1 analysis datasets and exports the 1A–1D PDF panels.
- **Figures 2 and 3:** `fig23_prep.do` prepares regression and prediction results, and `fig23_graphs.do` exports the figure PDFs (Figure 2 to `fig2/`, Figure 3 to `fig3/`).
- **Figure 4:** `fig4_graphs.do` reads `figure4_analysis_data_week.dta` and `logcoef_all.ster`, calls `figure4_delta_ci.do` to compute confidence intervals for the counterfactual totals, and calls the Python script `fig4a_graph.py` internally (twice: the default panel and an ATUS 22–23 comparison version) to generate Figure 4A. Figures 4B and 4C are exported directly from Stata.

Representative outputs include:

```text
<OUTPUT_DIR>/Subfigures/full/fig1/1a_milk_dur_hist.pdf
<OUTPUT_DIR>/Subfigures/full/fig1/1b_milk_obs_hist.pdf
<OUTPUT_DIR>/Subfigures/full/fig1/1c_uninterrupted_day_1.pdf
<OUTPUT_DIR>/Subfigures/full/fig1/1d_milk_prod_night_count.pdf
<OUTPUT_DIR>/Subfigures/full/fig2/2_milk_logdur_margins_30.pdf
<OUTPUT_DIR>/Subfigures/full/fig3/3_milk_logdur_sums_30.pdf
<OUTPUT_DIR>/Subfigures/full/fig4/4a_cf_bottle_dur.pdf
<OUTPUT_DIR>/Subfigures/full/fig4/4a_cf_bottle_dur_atus_22_23.pdf
<OUTPUT_DIR>/Subfigures/full/fig4/4b_histogram_save_pct_diff_log.pdf
<OUTPUT_DIR>/Subfigures/full/fig4/4b_ordered_save_pct_diff_log.pdf
<OUTPUT_DIR>/Subfigures/full/fig4/4c_histogram_outsrcble_pct_log.pdf
<OUTPUT_DIR>/Subfigures/full/fig4/4c_ordered_outsrcble_pct_log.pdf
<DATA_DIR>/Analysis/BabyConnect/full/figure4a_analysis_data_ci.csv
```


#### Appendix figures

The appendix scripts mirror the main-paper figures for robustness and subgroup analyses. They include:

- Figure 1 panels by age cohort (`fig1_cohort_apdx.do`),
- Figure 1 for all feeding events, and the 8am–8pm day-boundary variant (`fig1_feed_apdx.do`),
- Figure 1 year-over-year comparison (`fig1_year_apdx.do`),
- cohort entry/exit plot, which also creates the intersection-cohort datasets (`cohort_selection.do`; age cohorts are up to 90 days, 91–180 days and 181–365 days),
- Figure 1 cohort panels for the intersection cohort (`fig1_cohort_intersect_apdx.do`),
- balanced-panel version of Figure 3 (`fig23_balanced_prep.do`, `fig23_balanced_apdx.do`; **confidential data only**),
- Figures 2 and 3 for all feeding events (`fig23_feed_prep.do`, `fig23_feed_apdx.do`),
- the milk-production restriction plot (`milk_prod_apdx.do`),
- the regression-coefficient margins plot (`margins_apdx.do`),
- Figure 4 session-type histograms and the intersection-cohort version (`fig4_hist_intrsct_apdx.do`),
- Figure 4 restricted to the first quarter of life (`fig4_first_qtr_apdx.do`),
- breastfeeding continuation curve versus CDC (`continuation_curve.do`),
- Figure 1 for narrower age windows, 31–60 and 61–90 days (`fig1_age_windows_apdx.do`),
- Figure 1 restricted to nursing-only children (`fig1_nursing_only_apdx.do`),
- nighttime-logging robustness (`nighttime_robustness.do`), and
- pumping share by child age (`pumping_by_age.do`).

The Figure 4 appendix scripts also call `figure4_delta_ci.do` and `fig4a_graph.py`, and write confidence-interval files (`figure4a_*_ci.csv`/`.dta`) to the analysis data directory.

Representative appendix outputs include:

```text
<OUTPUT_DIR>/Subfigures/full/appendix/first_year/1a_milk_dur_hist_cohort_1.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/1a_feed_dur_hist_apdx.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/1a_milk_dur_hist_comparison.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/1a_milk_dur_hist_31_60.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/1a_milk_dur_hist_nurse_only.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/entry_exit_cohort.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/2_milk_logdur_margins_30_full.pdf     (confidential data only)
<OUTPUT_DIR>/Subfigures/full/appendix/3_milk_logdur_sums_30_full.pdf        (confidential data only)
<OUTPUT_DIR>/Subfigures/full/appendix/2_feed_logdur_margins_30.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/3_feed_logdur_sums_30.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/milk_production_count_365_day.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/reg_coef_marginsplot.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/continuation_survival_app_vs_cdc.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/4a_cf_bottle_dur_intrsct.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/4a_cf_bottle_dur_first_quarter.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/1d_milk_prod_night_count_late_loggers.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/night_hour_logging_dist.pdf
<OUTPUT_DIR>/Subfigures/full/appendix/avg_pumping_share_by_age_ma7.pdf
```

#### Tables and statistics

The `stats` scripts generate the summary tables and report sample and cohort statistics in the Stata logs.

- `analysis/stats/summary_tables.do` → summary-statistics tables `stats_by_year.tex` and `stats_by_country.tex`, written to `<OUTPUT_DIR>/Tables/full/`
- `analysis/stats/sample_summary.do` → sample characteristics, descriptive statistics and cohort coverage, reported in `<OUTPUT_DIR>/Log/sample_summary_0.log`
- `analysis/stats/fig1_cohort_stats.do` → ANOVA tests of daily milk-production duration and session counts across age cohorts (regular and intersection cohorts), with Bonferroni-adjusted pairwise comparisons, reported in `<OUTPUT_DIR>/Log/fig1_cohort_stats_0.log`

Both statistics scripts are included in the Makefile's `all` target (also available as `make sample_summary` and `make fig1_cohort_stats`).

### D. Role of the `misc` and `stats` folders

- The **`misc`** folder contains helper scripts used by the figure workflows, including plotting utilities (`plot_functions.do`), generic axis-label utilities (`label_functions.do`), and figure-specific label files such as `fig1_labels.do`, `fig1_labels_apdx.do`, `fig1_cohort_labels.do`, and `fig1_cohort_labels_apdx.do`. These are support code, not independent entry points.
- The **`stats`** folder contains downstream scripts (`summary_tables.do`, `sample_summary.do`, `fig1_cohort_stats.do`) that compute summary tables and statistics after the analysis datasets already exist. They are run through the Makefile targets above.

In general, you should run these through the Makefile targets above, or through the main figure/stat scripts that source them, rather than trying to run the helper files directly.

### E. Running individual scripts manually

If you need to rerun only part of the workflow after setting your Stata globals correctly, run from the `code/` directory so that Stata finds `profile.do`. Paths are relative to `code/`. Examples:

```bash
cd code
stata-mp -b do analysis/figures/main/fig1_graphs.do
stata-mp -b do analysis/figures/main/fig23_prep.do
stata-mp -b do analysis/figures/main/fig23_graphs.do
stata-mp -b do analysis/figures/main/fig4_graphs.do
stata-mp -b do analysis/stats/summary_tables.do
stata-mp -b do analysis/stats/sample_summary.do
stata-mp -b do analysis/stats/fig1_cohort_stats.do
```

`make` exports `USE_SYNTHETIC` to Stata. `sample_creation.do` uses it to decide whether to apply the exclusive-nursing restriction for the nursing-only appendix, which is skipped for synthetic data and applied for raw data. If you run `sample_creation.do` by hand, set it yourself (`export USE_SYNTHETIC=1` for synthetic data, `export USE_SYNTHETIC=0` for the confidential data); if it is unset, the restriction is applied.

Many scripts depend on datasets produced earlier (for example `sample_creation.do` must have been run before any figure script), so running through `make` is the safest way to respect those dependencies. When running scripts individually, check the corresponding Stata logs for execution errors.

## Workflow summary

The overall public replication flow is:

```text
synthetic formatted data
  -> figure-specific analysis .dta files (and logcoef_all.ster)
  -> main-paper figures
  -> appendix figures
  -> summary tables
  -> sample and cohort statistics (Stata logs)
```

Equivalently, the full pipeline transforms either confidential raw data or synthetic replication data into formatted data, then into figure-specific analysis datasets, and finally into PDFs, LaTeX tables, and Stata-log statistics.

To reproduce all figures, appendix figures, summary tables, and reported statistics, run from the `code/` directory:

```bash
cd code
make all
```
