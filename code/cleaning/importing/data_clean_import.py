import os
import pandas as pd
import re
import logging
import time
import numpy as np
from datetime import datetime
print(pd.__version__)

# --- Edit these paths to match your local directory layout, or set the
#     corresponding environment variables before running.
DATA_DIR = os.environ.get("BFP_DATADIR", "/path/to/BFP_replication/data")
OUTPUT_DIR = os.environ.get("BFP_OUTPUTDIR", "/path/to/BFP_replication/output")

logging.basicConfig(filename=os.path.join(OUTPUT_DIR, 'Log', 'data_clean_import_py.log'),
                    level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

read_file_path_pattern = os.path.join(DATA_DIR, 'Raw', 'BabyConnect', 'bc-anon-2211-{}.csv')
save_file_path_pattern = os.path.join(DATA_DIR, 'Intermediate', 'BabyConnect', 'raw_bc_stata', 'bc_raw_{}.dta')
logging.info(f"Script started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

# clean column names
def adjust_col_name(df):
    df.columns = [re.sub(r'[^A-Za-z0-9_]', '', col).replace(' ', '_') for col in df.columns]
    return df

# Convert to ASCII or remove
def convert_to_ascii(df):
    for col in df.select_dtypes(include=[object]):  # Only select columns with object dtype
        df[col] = df[col].astype(str).apply(lambda x: x.encode('ascii', 'ignore').decode('ascii'))
    return df

## Detect a "YYYY-M-D HH:MM" timestamp string (used by right_adjust below).
def is_datetime_format(val):
    if not isinstance(val, str):
        return False
    pattern = r'\d{4}-\d{1,2}-\d{1,2} \d{2}:\d{2}'
    if re.fullmatch(pattern, val):
        return True
    else:
        return False

## Fix for a quirk specific to the raw BabyConnect CSV exports (not a general
## cleaning step). In some rows the 'TimezoneInfo' field is missing from the raw
## file, so every field from that point on is shifted one column to the left and
## a timestamp ends up in 'TimezoneInfo' (which should only hold timezone info).
## We detect these rows by checking whether 'TimezoneInfo' looks like a
## timestamp, shift them back one column to the right, and set 'TimezoneInfo'
## to missing for them.
def right_adjust(df):
    # Rows where 'TimezoneInfo' holds a timestamp instead of timezone info
    mask = df['TimezoneInfo'].apply(is_datetime_format)
    # Shift everything from 'TimezoneInfo' onward one column to the right
    # (the last column's value is dropped by the shift)
    tz_index = df.columns.get_loc('TimezoneInfo')
    df.loc[mask, df.columns[tz_index+1:]] = df.loc[mask, df.columns[tz_index:-1]].values
    # The true TimezoneInfo value is absent in these rows, so set it to missing
    df.loc[mask, 'TimezoneInfo'] = np.nan

    return df
            
dataframes = []


for i in range(1, 163):
    read_file_path = read_file_path_pattern.format(i)
    save_file_path = save_file_path_pattern.format(i)
    start_time = time.time()
    try:
        df = pd.read_csv(read_file_path, encoding='utf-8', low_memory=False, on_bad_lines='skip')
        df = adjust_col_name(df)
        df = convert_to_ascii(df)

        ## Drop if Child Id column has value equal to Child id
        df = df[df['ChildId'] != 'Child Id']
        df = right_adjust(df)
        dataframes.append(df) 
        df.to_stata(save_file_path, write_index=False, version=118)
        end_time = time.time()
        logging.info(f"Saved {save_file_path} - Time taken: {end_time - start_time:.2f} seconds")

    except Exception as e:
        logging.error(f"Error processing file {read_file_path}: {e}")
