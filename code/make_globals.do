** Note: Stata batch mode (-b) returns exit code 0 even on errors. Make detects
** failures via setup/run_stata.sh, which checks the log for a trailing r(NNN);.

** Guard: stop early if profile.do was not found/edited (template paths or empty).
** Stata only loads profile.do from the working directory (code/) or, failing
** that, from ~/profile.do, so run Make/Stata from code/.
if "$BFPrep_codedir" == "" | strpos("$BFPrep_codedir", "/path/to") > 0 | ///
   strpos("$BFPrep_datadir", "/path/to") > 0 | strpos("$BFPrep_outdir", "/path/to") > 0 {
    display as error "BFPrep_codedir/datadir/outdir are unset or still template paths."
    display as error "Edit code/profile.do and run Make/Stata from the code/ directory."
    exit 198
}

** Code Directories
global cleandir "$BFPrep_codedir/cleaning"
global anadir   "$BFPrep_codedir/analysis"

** Data Directories
global datadir   "$BFPrep_datadir"
global rawdir    "$datadir/Raw"
global interdir  "$datadir/Intermediate"
global anadatadir "$datadir/Analysis"

** Output Directories
global outdir  "$BFPrep_outdir"
global logdir  "$outdir/Log"


