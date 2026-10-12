
import sys
import pandas as pd
import matplotlib as mpl
mpl.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
mpl.rcParams['hatch.linewidth'] = 4.0  # 4.0 is the hatch line width

# ── Arguments ─────────────────────────────────────────────────────────────────
# Called from Stata as:
#   python script "$anadir/figures/main/fig4a_graph.py", ///
#       args("$indir" "$outdir" dataset_name [appendix] [split_version])
#
# argv[1] = input directory  (where <dataset_name>.csv lives)
# argv[2] = output directory (where <output>.pdf is saved)
# argv[3] = dataset name     (e.g. figure4a_analysis_data)
# argv[4] = appendix flag    (0 or 1, optional, default 0)
# argv[5] = split version    (default or atus_22_23, optional, default "default")
input_dir  = sys.argv[1].rstrip("/") + "/"
output_dir = sys.argv[2].rstrip("/") + "/"
dataset_name = sys.argv[3] if len(sys.argv) > 3 else "figure4a_analysis_data"
appendix = int(sys.argv[4]) if len(sys.argv) > 4 else 0
split_version = sys.argv[5] if len(sys.argv) > 5 else "default"
# Build output filename from dataset name
output_base = dataset_name.replace("_sample", "")
if "first_quarter" in dataset_name:
    output_base = output_base.replace("figure4a_first_quarter_data", "4a_cf_bottle_dur_first_quarter")
elif "intrsct" in dataset_name:
    output_base = output_base.replace("figure4a_analysis_intrsct_data", "4a_cf_bottle_dur_intrsct")
elif "figure4a_analysis_data" in dataset_name:
    output_base = output_base.replace("figure4a_analysis_data", "4a_cf_bottle_dur")
else:
    output_base = "4a_cf_bottle_dur_" + dataset_name.replace("figure4a_", "").replace("_data", "")

# Construct input file path
input_file = input_dir + dataset_name + ".csv"

# Corresponding delta-method confidence interval file
ci_base = dataset_name.replace("_sample", "")
ci_file = input_dir + ci_base + "_ci.csv"

print(f"Using CI file: {ci_file}")

# Print selected paths for debugging
print(f"Using dataset: {dataset_name}")
print(f"Using input file: {input_file}")
print(f"Using output directory: {output_dir}")
print(f"Output base name: {output_base}")

# Read the data from the CSV file
data = pd.read_csv(input_file)

# Read delta-method confidence intervals
ci = pd.read_csv(ci_file)

cf_frac_ci_lo = ci.loc[0, "cf_frac_lo"]
cf_frac_ci_hi = ci.loc[0, "cf_frac_hi"]
cf_frac_stata = ci.loc[0, "cf_frac"]

# Sum the values for each column
sum_initial_bottle_dur = data['initial_bottle_dur'].sum()
sum_nursing_dur = data['nursing_dur'].sum()
sum_express_dur = data['express_dur'].sum()
sum_cf_bottle_dur = data['cf_bottle_dur'].sum()

# Total for left bar (Factual)
left_bar_total = sum_initial_bottle_dur + sum_nursing_dur + sum_express_dur

# Calculate percentages based on left bar total
percent_initial_bottle_dur = (sum_initial_bottle_dur / left_bar_total) * 100
percent_nursing_dur = (sum_nursing_dur / left_bar_total) * 100
percent_express_dur = (sum_express_dur / left_bar_total) * 100
percent_cf_bottle_dur = (sum_cf_bottle_dur / left_bar_total) * 100
percent_cf_total = percent_initial_bottle_dur + percent_cf_bottle_dur

print(f"Python counterfactual total: {percent_cf_total:.6f}")
print(f"Stata delta point estimate: {cf_frac_stata:.6f}")
print(f"95% CI: [{cf_frac_ci_lo:.6f}, {cf_frac_ci_hi:.6f}]")

# Check that the two implementations agree
if abs(percent_cf_total - cf_frac_stata) > 1e-4:
    raise ValueError("Python and Stata counterfactual estimates differ.")

# Auto-adjust y-axis if bars 2-4 exceed threshold (bars 2-4 all share the same total height)
OVERFLOW_THRESHOLD = 105
max_height = max(percent_cf_total, cf_frac_ci_hi)
y_max = max(OVERFLOW_THRESHOLD, max_height * 1.05)

plt.figure(figsize=(6.25, 11))

# Plot
labels = ['Factual', 'Counterfactual', 'Even\nSplit', 'Literature\nSplit']
width = 0.08

# Adjust the position of the bars to move them closer together
positions = [x * 1.50 for x in [0.44, 0.56, 0.68, 0.80]]

# Specify colors
colors = ['#315a7d', '#9c494f', '#b17176', '#8ca3b7', '#9cb2c4']

# Values for Factual Bar
factual_values = [percent_initial_bottle_dur, percent_express_dur, percent_nursing_dur]

# Values for Counterfactual Bar
counterfactual_values = [percent_initial_bottle_dur, percent_cf_bottle_dur]

# Values for 50-50 Discount Counterfactual Bar
discount_50_values = [(percent_initial_bottle_dur + percent_cf_bottle_dur)*(1/2), (percent_initial_bottle_dur + percent_cf_bottle_dur)*(1-(1/2))]

# Values for X Discount Counterfactual Bar (X is partner percent)
# https://pubs.aeaweb.org/doi/pdfplus/10.1257/jep.22.3.23
# Partner/father share for the literature split bar
if split_version == "atus_22_23":
    x = 0.36
    output_base = output_base + "_atus_22_23"
else:
    x = 0.29

discount_x_values = [
    (percent_initial_bottle_dur + percent_cf_bottle_dur) * (1 - x),
    (percent_initial_bottle_dur + percent_cf_bottle_dur) * x
]

# Stacked bar for Factual (1st)
p1 = plt.bar(positions[0], factual_values[0], width, color=colors[0], edgecolor=colors[0])  # Bottle
p2 = plt.bar(positions[0], factual_values[1], width, bottom=factual_values[0], color=colors[1], edgecolor=colors[1])  # Expressed
p3 = plt.bar(positions[0], factual_values[2], width, bottom=factual_values[0]+factual_values[1], color=colors[2], edgecolor=colors[2])  # Nursing

# Stacked bar for Counterfactual (2nd)
p4 = plt.bar(positions[1], counterfactual_values[0], width, color=colors[0], edgecolor=colors[0])  # Bottle Time
p5 = plt.bar(positions[1], counterfactual_values[1], width, bottom=counterfactual_values[0], facecolor='white', edgecolor=colors[0], hatch='//')

# Stacked bar for Discount Counterfactual (50/50) (3rd)
p6 = plt.bar(positions[2], discount_50_values[0], width, color=colors[4], edgecolor=colors[4])  # Bottle Time
p7 = plt.bar(positions[2], discount_50_values[1], width, bottom=discount_50_values[1], color=colors[4], edgecolor=colors[4], fill = False)

# Stacked bar for Discount Counterfactual (Literature) (4th)
p8 = plt.bar(positions[3], discount_x_values[0], width, color=colors[4], edgecolor=colors[4])  # Bottle Time
p9 = plt.bar(positions[3], discount_x_values[1], width, bottom=discount_x_values[0], color=colors[4], edgecolor=colors[4], fill = False)

# 95% confidence intervals for counterfactual total
cf_err_lower = percent_cf_total - cf_frac_ci_lo
cf_err_upper = cf_frac_ci_hi - percent_cf_total

if cf_err_lower < 0 or cf_err_upper < 0:
    raise ValueError("Counterfactual point estimate lies outside its confidence interval.")

cf_yerr = [[cf_err_lower], [cf_err_upper]]

# Counterfactual, Even Split, and Literature Split
# share the same total counterfactual hours
for pos in positions[1:]:
    plt.errorbar(
        pos,
        percent_cf_total,
        yerr=cf_yerr,
        fmt='none',
        ecolor='black',
        elinewidth=1.5,
        capsize=10,
        capthick=1.5,
        zorder=10
    )

# Set the Y-axis limit and labels
plt.ylim(0, y_max)
plt.xticks(positions, labels, fontsize=15)
plt.yticks(fontsize=15)

# Adding title and legend below the plot
shareable_line = Line2D([0], [0], color='green', lw=2, label='Shareable', linestyle='-')
plt.legend([p3, p2, shareable_line, p5, p1, p6], ['Nursing', 'Expressed', 'Shareable', 'Additional Bottle Time', 'Bottle', 'Counterfactual Mother Time'], loc='upper center', bbox_to_anchor=(0.5, -0.075), ncol=2, frameon=False, fontsize=15)

# Adjust position of '% Factual Hours' and place it horizontally at the top
ax = plt.gca()

ax.text(
    0, y_max + 2,
    '% Factual Hours',
    horizontalalignment='center',
    fontsize=15,
    transform=ax.get_yaxis_transform()
)

text_height = 7
## Labels
plt.text(positions[2] + width - 0.03, discount_50_values[0]/2 - text_height, 'Mother Split', horizontalalignment='center', color = 'red', rotation=270, fontsize=15)
plt.text(positions[2] + width - 0.03, discount_50_values[1] + discount_50_values[1]/2 - text_height, 'Partner Split', horizontalalignment='center', color = 'red', rotation=270, fontsize=15)

plt.text(positions[3] + width - 0.03, discount_x_values[0]/2 - text_height, 'Mother Split', horizontalalignment='center', color = 'red', rotation=270, fontsize=15)
plt.text(positions[3] + width - 0.03, discount_x_values[0] + discount_x_values[1]/2 - text_height, 'Partner Split', horizontalalignment='center', color = 'red', rotation=270, fontsize=15)

plt.tick_params(axis='x', which='both', length=0)

ax = plt.gca()
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# vertical bracket
x_position = positions[1] + width - 0.035  # Change this to set the x-position of the bracket
bottom = 1
top = counterfactual_values[1] + counterfactual_values[0] - 1

# bracket's offset for drawing
bracket_width = 0.005

# plot bracket lines:
plt.plot([x_position + bracket_width, x_position + bracket_width], [bottom, top], color='green', linewidth=3)
plt.plot([x_position, x_position + bracket_width], [bottom, bottom], color='green', linewidth=3)
plt.plot([x_position, x_position + bracket_width], [top, top], color='green', linewidth=3)

# vertical bracket
x_position = positions[0] + width - 0.035 # Change this to set the x-position of the bracket
bottom = 1
top = counterfactual_values[0] - 1

# bracket's offset for drawing
bracket_width = 0.005

# plot bracket lines:
plt.plot([x_position + bracket_width, x_position + bracket_width], [bottom, top], color='green', linewidth=3)
plt.plot([x_position, x_position + bracket_width], [bottom, bottom], color='green', linewidth=3)
plt.plot([x_position, x_position + bracket_width], [top, top], color='green', linewidth=3)

# Save the figure with appropriate naming
if appendix == 1:  
    # For appendix figures, don't add extra _apdx suffix since we're already in appendix directory
    plt.savefig(output_dir + output_base + ".pdf", format='pdf', bbox_inches='tight')
    print(f"Saved to: {output_dir}{output_base}.pdf")
else:
    plt.savefig(output_dir + output_base + ".pdf", format='pdf', bbox_inches='tight')
    print(f"Saved to: {output_dir}{output_base}.pdf")
