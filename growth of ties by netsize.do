****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/08/18
****Version: 17
****Purpose: plot exponential growth by network size


***************************************************************
**# 1 of alter-alter ties by netsize
***************************************************************
clear
set obs 20 //generate observations
gen netsize = 5
replace netsize = netsize*_n
gen totnum = netsize*(netsize-1)/2	
gen tottime = round(totnum*7.5/60) //assuming 7.5s (range 5-10s) to do one tie

label var netsize "Network size"
label var totnum "# alter-alter ties"
label var tottime "Minutes"

twoway (connected tottime netsize, xlab(5(5)100) mlab(tottime) mlabposition(12)) 
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\exponential-growth-time.tif",replace

twoway (connected totnum netsize, xlab(5(5)100) mlab(totnum) mlabposition(12)) 
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\exponential-growth-num.tif",replace
