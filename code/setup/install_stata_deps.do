version 17

** gtools: gcollapse, gduplicates, gsort
cap which gcollapse
if _rc ssc install gtools, replace

** require: package manager used internally by reghdfe
cap which require
if _rc ssc install require, replace

** reghdfe: high-dimensional fixed effects
cap which reghdfe
if _rc ssc install reghdfe, replace

** ftools: required by reghdfe
cap which fcollapse
if _rc ssc install ftools, replace

** egenmore: additional egen functions, including nvals()
cap which _gnvals
if _rc ssc install egenmore, replace

** listtex: write dataset rows to LaTeX/HTML tabular output
cap which listtex
if _rc ssc install listtex, replace

** winsor2: winsorize variables
cap which winsor2
if _rc ssc install winsor2, replace

** compile platform-specific plugins where relevant
cap noisily gtools, upgrade
cap noisily ftools, compile
