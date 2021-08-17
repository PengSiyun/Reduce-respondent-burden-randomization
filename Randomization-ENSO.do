****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/07/12
****Version: 17
****Purpose: explore way to collect alter-alter tie data while reducing participant burden


***************************************************************
**# 1 randomly chose alters for ENSO only
***************************************************************

cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\temp"

***************************************************************
**# 2 calculate density for people > 10 alters
***************************************************************

use "ENSO-participant-altertie-long.dta", clear
drop if missing(tievalue) //drop missing/inaccurate data
bysort SUBID: egen nties=count(tievalue)
drop if nties<=90 //drop people<= 10 alters: 90=2*(10 chose 2) 
save "ENSO-participant-altertie-10.dta",replace

*clean density
bysort SUBID: egen npossties=count(tievalue)

bysort SUBID: egen totval=total(tievalue),mi //for value density
gen density=totval/npossties
lab var density "Valued density of networks from matrix"

recode tievalue (2/3=1) (0/1=0),gen(tievalue1)
bysort SUBID: egen totnum=total(tievalue1),mi //for Binary density
gen bdensity=totnum/npossties
lab var bdensity "Binary density of networks from matrix"

recode tievalue (1/3=1) (0=0),gen(tievalue2)
bysort SUBID: egen totnum1=total(tievalue2),mi // for Density of networks know each other
gen b1density=totnum1/npossties
lab var b1density "Density of networks know each other"

replace totnum1=totnum1/2 //it is double counting, so need to divide by 2
keep SUBID *density totnum1
rename *density *density_10
rename totnum1 totnum1_10
duplicates drop SUBID, force
save "ENSO-participant-density-EGOAGG-10.dta",replace

***************************************************************
**# 3 Randomization
***************************************************************

set seed 20210727
forvalues x=5/10 {
	qui postutil clear
	qui postfile buffer mhat mhat_rd using mcs, replace //creates a place in memory called buffer in which I can store the results that will eventually be written out to a dataset. mhat is the name of the variable that will hold the estimates in the new dataset called mcs.dta. 

forvalues i=1/1000 {
	qui use "ENSO-participant-altertie-10.dta", clear
	qui drop dup pickone
	 
	*randomly select 10 alters per FOCAL
	qui duplicates drop SUBID alter_a_id,force
	qui sample `x',count by(SUBID) //random sample x IDs per FOCAL
	qui keep SUBID alter_a_id 
	qui gen alter_b_id=alter_a_id //copy x IDs for alter_b_id
	qui save "ENSO-participant-altertie-long-random-alter.dta",replace
	
	*calculate density based on the x randomly selected alters
	qui use "ENSO-participant-altertie-long.dta",clear
	qui merge m:1 SUBID alter_a_id using "ENSO-participant-altertie-long-random-alter.dta",keepusing(alter_a_id)
	qui keep if _merge==3 //keep x selected alters for alter_a_id
	qui drop _merge
	qui merge m:1 SUBID alter_b_id using "ENSO-participant-altertie-long-random-alter.dta",keepusing(alter_b_id)
	qui keep if _merge==3 //keep x selected alters for alter_b_id
	qui drop _merge
	
	*clean density
    qui bysort SUBID: egen npossties=count(tievalue)

    qui bysort SUBID: egen totval=total(tievalue),mi //for value density
    qui gen density=totval/npossties
    qui lab var density "Valued density of networks from matrix"

    qui recode tievalue (2/3=1) (0/1=0),gen(tievalue1)
    qui bysort SUBID: egen totnum=total(tievalue1),mi //for Binary density
    qui gen bdensity=totnum/npossties
    qui lab var bdensity "Binary density of networks from matrix"

    qui recode tievalue (1/3=1) (0=0),gen(tievalue2)
    qui bysort SUBID: egen totnum1=total(tievalue2),mi // for Density of networks know each other
    qui gen b1density=totnum1/npossties
    qui lab var b1density "Density of networks know each other"

    qui replace totnum1=totnum1/2 //it is double counting, so need to divide by 2
    qui keep SUBID *density totnum1
    qui rename *density *density_rd
    qui rename totnum1 totnum1_rd
    qui duplicates drop SUBID, force

    qui merge 1:1 SUBID using "ENSO-participant-density-EGOAGG-10.dta" //all matched
    qui ttest b1density_10=b1density_rd
    qui post buffer (r(mu_1)) (r(mu_2)) //stores the estimated mean for the current draw in buffer for what will be the next observation on mhat.
}
postclose buffer //writes the stuff stored in buffer to the file mcs.dta
use mcs, clear
gen n = `x'
save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\ENSO_random_`x'",replace
display "Randomly selected:" `x'
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
ttest mhat=mhat_rd
}

***************************************************************
// #4 Figures
***************************************************************
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data"
use "ENSO_random_5",clear
foreach i of numlist 6/10 {
	append using "ENSO_random_`i'"
}

*Plot error<1
label var n "# alters randomly selected"
bysort n: egen error_2=count(n) if abs(mhat-mhat_rd) <= 5/100 
label var error_2 "Error<5%"
bysort n: egen error_1=count(n) if abs(mhat-mhat_rd) <= 2/100 
label var error_1 "Error<2%"
twoway (connected error_2 n,mlab(error_2) mlabposition(12)) (connected error_1 n,mlab(error_1) mlabposition(12)),title("# random samples in 1000 trails that have acceptable error") legend(order(1 "Error<5 ties" "in 100 ties" 2 "Error<2 ties" "in 100 ties"))
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\ENSO-miss.tif",replace

*boxcox plot
label var mhat_rd "Density"
graph box mhat_rd, over(n) box(1, color(gray%70)) yline(0.514,lcolor(red)) ///
b1title("# randomly selected alters") 
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\ENSO.tif",replace
     
*histogram of netsize
use "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\Clean data\ENSO-Participant-EGOAGG-clean.dta", clear
drop if missing(density) //drop missing/inaccurate data in alter-alter ties
hist netsize,freq w(1)
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\ENSO-histogram.tif",replace

***************************************************************
**# 4 randomly chose alters for Pilot
***************************************************************

***************************************************************
**# 5 density of full vs pilot generators 
***************************************************************

cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\Clean data"
use "ENSO-Participant-EGOAGG-clean",clear
keep SUBID *density
reid *density *density_full

merge 1:1 SUBID using "ENSO-Participant-EGOAGG-pilot-clean", keepusing(*density)
keep if _merge==3
ttest density=density_full
