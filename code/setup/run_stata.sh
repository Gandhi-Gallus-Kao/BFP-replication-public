#!/usr/bin/env bash
# Run a Stata do-file in batch mode and fail (non-zero exit) if Stata hit an error.
#
# Stata's batch mode (`stata-mp -b do file.do`) returns exit code 0 even when the
# do-file stops on an error, so `make` cannot detect failures on its own. Batch
# mode stops at the first uncaught error, which leaves an "r(NNN);" line at the
# end of the log; this wrapper checks for it.
#
# Usage:  run_stata.sh path/to/file.do
# Env:    STATA_BIN  Stata executable (default: stata-mp). Must be run from code/
#                    so that Stata writes ./<name>.log and finds profile.do.

set -u

if [ $# -ne 1 ]; then
    echo "usage: $0 file.do" >&2
    exit 2
fi

do_file="$1"
stata_bin="${STATA_BIN:-stata-mp}"
log_file="$(basename "${do_file%.do}").log"

# Remove any stale log so an old success/failure cannot be mistaken for this run.
rm -f "$log_file"

# $stata_bin is intentionally unquoted so values like "/path/to/stata-mp -q" work.
# shellcheck disable=SC2086
$stata_bin -b do "$do_file"
status=$?
if [ "$status" -ne 0 ]; then
    echo "run_stata.sh: Stata exited with status $status for $do_file" >&2
    exit "$status"
fi

if [ ! -f "$log_file" ]; then
    echo "run_stata.sh: expected log $log_file not found (is Make running from code/?)" >&2
    exit 1
fi

if tail -n 10 "$log_file" | grep -Eq '^r\([0-9]+\);'; then
    echo "run_stata.sh: Stata error in $do_file; see $log_file:" >&2
    tail -n 15 "$log_file" >&2
    exit 1
fi

exit 0
