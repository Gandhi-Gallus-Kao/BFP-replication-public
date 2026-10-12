
#!/usr/bin/env python3
"""
Generate a synthetic `bc_full_sample_formatted.dta` for replication.

This directly produces the formatted analysis-ready dataset, bypassing
the raw import/cleaning steps (steps 0-3) that require confidential data.

Usage
-----
python generate_synthetic.py \
    --output /path/to/bc_full_sample_formatted.dta \
    --n-children 500 \
    --n-survivors 25

--n-survivors (default 25) injects children that should survive all sample restrictions
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd

# ── Activity definitions ──────────────────────────────────────────────────────
# (duration_min, duration_max, has_quantity, daily_mean, daily_std, nighttime_frac)
# nighttime_frac: fraction of that activity's events placed in 10 PM–6 AM window
ACTIVITY_SPECS = {
    "Nursing":    (8,  45,  False, 5.0, 2.0, 0.25),
    "Bottle":     (5,  35,  True,  2.0, 1.5, 0.10),
    "Expressed":  (8,  30,  True,  1.5, 1.0, 0.00),
    "Solid Food": (5,  30,  True,  2.0, 1.0, 0.00),
    "Sleep":      (20, 480, False, 4.0, 1.5, 0.40),
    "Diaper":     (2,  15,  False, 5.0, 2.0, 0.20),
}

ACTIVITY_NAMES = list(ACTIVITY_SPECS.keys())

# ── Categorical choices ──────────────────────────────────────────────────────
GENDERS = ["B", "G"]
LANGS = ["es", "pt", "fr", "de"]
COUNTRIES = ["US", "CA", "GB", "AU", "BR"]
TIMEZONES = ["-300;1", "-300;0", "-240;1", "-360;1", "-420;1", "-480;1"]
USERTYPES = ["1", "2", "10"]
UNITS = ["ml", "oz"]

# Age cohort bins matching bc_data_format.do recode
AGE_COHORT_LABELS = {
    0: "Negative",
    1: "<2 weeks",
    2: "<3 months",
    3: "3-6 months",
    4: "6-12 months",
    5: "12-24 months",
    6: ">24 months",
}


def _age_cohort(months: float) -> int:
    if months <= 0:
        return 0
    if months <= 0.5:
        return 1
    if months <= 3:
        return 2
    if months <= 6:
        return 3
    if months <= 12:
        return 4
    if months <= 24:
        return 5
    return 6


def _generate_survivor_records(
    n_survivors: int, start_childid: int, start_uid: int, rng: np.random.Generator
) -> list[dict]:
    """
    Generate records for children that should survive all sample restrictions in
    base_sample_restriction.do

    Survivors are constructed to satisfy every filter in the pipeline:
      - age_day 15-365 fully covered  (start_age=0, n_days=370)
      - No formula on any day         (formula=0 always)
      - >= 2 Nursing events per day   (passes milk_producing pct_restrict; provides
                                       milk_producing rows in figure23_analysis_data.dta
                                       for every required age_day)
      - At least one event before 10 PM each day (daytime condition)
    """
    records: list[dict] = []
    next_uid = start_uid

    # Use births in a stable window so age filtering is clean
    birth_origin = pd.Timestamp("2015-01-01")
    birth_range_days = (pd.Timestamp("2018-12-31") - birth_origin).days + 1

    # Non-formula activities + probabilities (Bottle kept but formula always 0)
    survivor_acts = ["Nursing", "Bottle", "Expressed", "Solid Food", "Sleep", "Diaper"]
    survivor_probs = np.array([0.20, 0.20, 0.07, 0.08, 0.22, 0.23])

    for i in range(n_survivors):
        childid = start_childid + i
        birthdate = birth_origin + pd.Timedelta(days=int(rng.integers(0, birth_range_days)))
        gender = rng.choice(GENDERS)
        lang = rng.choice(LANGS)
        country = rng.choice(COUNTRIES)
        tz = rng.choice(TIMEZONES)
        dsn = int(rng.integers(1, 163))

        uid = next_uid
        utype = rng.choice(USERTYPES)
        next_uid += 1

        # Observe every day from birth through day 369 so age_days 15-365 are all present
        for day_off in range(370):
            day = birthdate + pd.Timedelta(days=day_off)
            age_days = day_off
            baby_age_month = max(1.0, age_days / 30.4375) if age_days >= 0 else 0.0

            n_random = int(np.clip(rng.poisson(5), 2, 10))

            # ── 2 guaranteed Nursing events in daytime ──────────────────────
            # Morning slot: 7–10 AM; afternoon slot: 2–5 PM
            for t_lo, t_hi in [(7 * 60, 10 * 60), (14 * 60, 17 * 60)]:
                minute = int(rng.integers(t_lo, t_hi))
                dur_lo, dur_hi, _, _, _, _ = ACTIVITY_SPECS["Nursing"]
                duration = int(rng.integers(dur_lo, dur_hi + 1))
                start_ts = day + pd.Timedelta(minutes=minute)
                end_ts = start_ts + pd.Timedelta(minutes=duration)
                records.append({
                    "childid": childid,
                    "birthdate": birthdate.normalize(),
                    "postedbyuserid": uid,
                    "postedbyusertype": utype,
                    "timezoneinfo": tz,
                    "starttime": start_ts,
                    "endtime": end_ts,
                    "startdate": day,
                    "enddate": end_ts.normalize(),
                    "quantity": np.nan,
                    "durationmin": duration,
                    "genderbg": gender,
                    "lang": lang,
                    "countrycode": country,
                    "activity": "Nursing",
                    "unit": "",
                    "formula": 0,
                    "data_source_num": dsn,
                    "baby_age_month": baby_age_month,
                    "age_cohort": _age_cohort(baby_age_month),
                })

            # ── Random additional events (no formula) ──────────────────────
            for _ in range(n_random):
                act = rng.choice(survivor_acts, p=survivor_probs)
                dur_lo, dur_hi, has_qty, _, _, _ = ACTIVITY_SPECS[act]
                minute = int(rng.integers(0, 24 * 60))
                duration = int(rng.integers(dur_lo, dur_hi + 1))
                start_ts = day + pd.Timedelta(minutes=minute)
                end_ts = start_ts + pd.Timedelta(minutes=duration)

                if act in {"Bottle", "Diaper"} and rng.random() < 0.5:
                    duration = np.nan
                    end_ts = start_ts

                quantity = np.nan
                unit = ""
                if has_qty:
                    unit = rng.choice(UNITS)
                    quantity = int(rng.integers(20, 240))
                    if unit == "oz":
                        quantity = max(1, round(quantity / 30))

                records.append({
                    "childid": childid,
                    "birthdate": birthdate.normalize(),
                    "postedbyuserid": uid,
                    "postedbyusertype": utype,
                    "timezoneinfo": tz,
                    "starttime": start_ts,
                    "endtime": end_ts,
                    "startdate": day,
                    "enddate": end_ts.normalize(),
                    "quantity": quantity,
                    "durationmin": duration,
                    "genderbg": gender,
                    "lang": lang,
                    "countrycode": country,
                    "activity": act,
                    "unit": unit,
                    "formula": 0,  # Never formula for survivor children
                    "data_source_num": dsn,
                    "baby_age_month": baby_age_month,
                    "age_cohort": _age_cohort(baby_age_month),
                })

    return records


def generate_dataset(n_children: int, seed: int, n_survivors: int = 25) -> pd.DataFrame:
    print(f"[generate_synthetic] Generating records for {n_children} random children "
          f"+ {n_survivors} guaranteed-survivor children...")
    rng = np.random.default_rng(seed)

    # Ensure all 162 data_source_num values appear
    source_ids = np.tile(np.arange(1, 163), math.ceil(n_children / 162))[:n_children]
    rng.shuffle(source_ids)

    birth_origin = pd.Timestamp("2012-01-01")
    birth_range_days = (pd.Timestamp("2022-12-31") - birth_origin).days + 1

    records = []
    next_uid = 50000

    for i in range(n_children):
        if i > 0 and i % 100 == 0:
            print(f"  ... {i}/{n_children} children processed", flush=True)
        childid = i + 1
        birthdate = birth_origin + pd.Timedelta(days=int(rng.integers(0, birth_range_days)))
        gender = rng.choice(GENDERS)
        lang = rng.choice(LANGS)
        country = rng.choice(COUNTRIES)
        tz = rng.choice(TIMEZONES)
        dsn = int(source_ids[i])

        # 1-2 caregivers per child
        n_cg = int(rng.choice([1, 2], p=[0.75, 0.25]))
        uids = list(range(next_uid, next_uid + n_cg))
        utypes = {u: rng.choice(USERTYPES) for u in uids}
        next_uid += n_cg

        # 50% of children are formula users (~30% of their bottles are formula),
        # the other 50% never use formula
        formula_child_prob = 0.3 if i % 2 == 0 else 0.0

        # Observe every day from birth for 400 days
        for day_off in range(400):
            day = birthdate + pd.Timedelta(days=day_off)
            age_days = day_off
            baby_age_month = max(1.0, age_days / 30.4375) if age_days >= 0 else 0.0

            # ── All activities: independent random placement ──────────────────
            for act, (dur_lo, dur_hi, has_qty, mn, sd, night_frac) in ACTIVITY_SPECS.items():
                n_events = int(max(0, round(rng.normal(mn, sd))))
                if n_events == 0:
                    continue

                for _ in range(n_events):
                    if rng.random() < night_frac:
                        minute = int(rng.integers(1320, 1440 + 360))
                        if minute >= 1440:
                            minute -= 1440
                    else:
                        minute = int(rng.integers(6 * 60, 22 * 60))

                    duration = int(rng.integers(dur_lo, dur_hi + 1))
                    start_ts = day + pd.Timedelta(minutes=minute)
                    end_ts = start_ts + pd.Timedelta(minutes=duration)

                    if act in {"Bottle", "Diaper"} and rng.random() < 0.5:
                        duration = np.nan
                        end_ts = start_ts

                    quantity = np.nan
                    unit = ""
                    if has_qty:
                        unit = rng.choice(UNITS)
                        quantity = int(rng.integers(20, 240))
                        if unit == "oz":
                            quantity = max(1, round(quantity / 30))

                    formula = int(rng.random() < formula_child_prob) if act == "Bottle" else 0
                    uid = int(rng.choice(uids))

                    records.append({
                        "childid": childid, "birthdate": birthdate.normalize(),
                        "postedbyuserid": uid, "postedbyusertype": utypes[uid],
                        "timezoneinfo": tz, "starttime": start_ts, "endtime": end_ts,
                        "startdate": day, "enddate": end_ts.normalize(),
                        "quantity": quantity, "durationmin": duration,
                        "genderbg": gender, "lang": lang, "countrycode": country,
                        "activity": act, "unit": unit, "formula": formula,
                        "data_source_num": dsn, "baby_age_month": baby_age_month,
                        "age_cohort": _age_cohort(baby_age_month),
                    })

    # ── Append survivor children ─────────────────────────────────────────────
    if n_survivors > 0:
        print(f"[generate_synthetic] Generating {n_survivors} guaranteed-survivor children...", flush=True)
        survivor_rng = np.random.default_rng(seed + 999)
        survivor_records = _generate_survivor_records(
            n_survivors=n_survivors,
            start_childid=n_children + 1,
            start_uid=next_uid,
            rng=survivor_rng,
        )
        records.extend(survivor_records)

    print(f"[generate_synthetic] Building DataFrame from {len(records):,} records...", flush=True)
    df = pd.DataFrame(records)
    df = df.drop_duplicates()
    df = df.sort_values(["childid", "starttime", "endtime", "activity"]).reset_index(drop=True)

    # Make ~20% of durations missing (applied uniformly; missing nursing/expressed
    # durations are imputed downstream in base_sample_restriction.do)
    rng_final = np.random.default_rng(seed + 1)
    mask = rng_final.random(len(df)) < 0.20
    df.loc[mask, "durationmin"] = np.nan

    return df


def write_stata(df: pd.DataFrame, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    convert_dates = {
        "birthdate": "td",
        "startdate": "td",
        "enddate": "td",
        "starttime": "tc",
        "endtime": "tc",
    }

    # Encode categoricals as Stata labeled numerics (matching Stata's encode)
    cat_cols = {
        "genderbg": pd.CategoricalDtype(categories=sorted(df["genderbg"].unique())),
        "lang": pd.CategoricalDtype(categories=sorted(df["lang"].unique())),
        "countrycode": pd.CategoricalDtype(categories=sorted(df["countrycode"].unique())),
        "activity": pd.CategoricalDtype(categories=sorted(df["activity"].unique())),
        "unit": pd.CategoricalDtype(categories=sorted(df["unit"].dropna().replace("", np.nan).dropna().unique())),
    }
    for col, dtype in cat_cols.items():
        df[col] = df[col].astype(dtype)

    # age_cohort as labeled categorical
    df["age_cohort"] = pd.Categorical(
        df["age_cohort"].map(AGE_COHORT_LABELS),
        categories=[AGE_COHORT_LABELS[k] for k in sorted(AGE_COHORT_LABELS.keys())],
        ordered=True,
    )

    # Numeric types
    df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce")
    df["durationmin"] = pd.to_numeric(df["durationmin"], errors="coerce").astype("Int64")
    df["formula"] = df["formula"].astype("int8")
    df["childid"] = df["childid"].astype("int32")
    df["postedbyuserid"] = df["postedbyuserid"].astype("int32")
    df["data_source_num"] = df["data_source_num"].astype("int16")
    df["baby_age_month"] = df["baby_age_month"].astype("float64")

    # String columns
    for col in ["timezoneinfo", "postedbyusertype"]:
        df[col] = df[col].fillna("").astype(object)

    df.to_stata(str(output_path), write_index=False, version=118, convert_dates=convert_dates)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate synthetic bc_full_sample_formatted.dta for replication."
    )
    parser.add_argument("--output", type=str, default="bc_full_sample_formatted.dta")
    parser.add_argument("--n-children", type=int, default=500)
    parser.add_argument("--seed", type=int, default=12345)
    parser.add_argument(
        "--n-survivors",
        type=int,
        default=25,
        help="Number of children guaranteed to survive all sample restrictions "
             "and reach day_obs_count >= 351 in fig23_balanced_prep.do (default: 25).",
    )
    args = parser.parse_args()

    if args.n_children <= 0:
        raise ValueError("--n-children must be positive")
    if args.n_survivors < 0:
        raise ValueError("--n-survivors must be non-negative")

    df = generate_dataset(
        n_children=args.n_children, seed=args.seed, n_survivors=args.n_survivors
    )
    print(f"[generate_synthetic] Writing {len(df):,} rows to {args.output} ...", flush=True)
    write_stata(df, Path(args.output))

    n_survivors_actual = df[df["childid"] > args.n_children]["childid"].nunique() if args.n_survivors > 0 else 0
    print(
        f"Wrote {len(df):,} rows ({df['childid'].nunique():,} children, "
        f"including {n_survivors_actual} guaranteed-survivor children) → {args.output}"
    )


if __name__ == "__main__":
    main()
