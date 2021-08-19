****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/07/27
****Version: 17
****Purpose: explore way to collect alter-alter tie data while reducing participant burden


***************************************************************
**# 1 calculate density for people > 12 alters (NETCANVAS)
***************************************************************

cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp"

*calculate netsize from alter level
use "Netcanvas-participant-alter.dta",clear
keep if broughtforward == "TRUE" | broughtforward == "true" | stilldiscuss== "1" //drop alters from previous wave but not chose in this wave
bysort networkcanvasegouuid: egen netsize = count(networkcanvasuuid) //networkcanvasuuid: unique alterid
gen npossties = netsize*(netsize-1)/2
drop if netsize <= 12 //drop people with <= 12 alters
save "Netcanvas-participant-alter-12.dta",replace

duplicates drop networkcanvasegouuid,force  
keep networkcanvasegouuid npossties netsize

*clean alter-alter tie 
merge 1:m networkcanvasegouuid using "Netcanvas-participant-altertie-long.dta"
keep if _merge==3
drop _merge totval tievalue totnum newtievalue totnum1 //drop density measures based on full data

bysort networkcanvasegouuid: egen totval=total(alteralterclose),mi //for value density
gen density = totval/npossties

recode alteralterclose (2/3=1) (1=0),gen(tievalue)
bysort networkcanvasegouuid: egen totnum=total(tievalue),mi //for Binary density
gen bdensity = totnum/npossties

recode alteralterclose (1/3=1),gen(newtievalue)
bysort networkcanvasegouuid: egen totnum1=total(newtievalue),mi // for Density of networks know each other
gen b1density = totnum1/npossties

*calculate Effective size
gen efctsize=netsize-2*totnum1/netsize

keep networkcanvasegouuid *density efctsize netsize npossties
rename *density *density_12
rename (efctsize netsize npossties) (efctsize_12 netsize_12 npossties_12) 
duplicates drop networkcanvasegouuid, force //N=31
save "Netcanvas-participant-density-EGOAGG-12.dta",replace



***************************************************************
**# 2 calculate density for people > 12 alters (ENSO)
***************************************************************
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\temp"

use "ENSO-participant-altertie-long.dta", clear
drop if missing(tievalue) //drop missing/inaccurate data
bysort SUBID: egen nties=count(tievalue)
drop if nties<=132 //drop people<= 12 alters: 90=2*(12 chose 2) 
merge m:1 SUBID using "ENSO-Participant-alter-EGOAGG-clean.dta",keepusing(netsize)
keep if _merge==3
drop _merge 
/* code to check netsize match with nties
replace netsize=4 if nties==12 
replace netsize=5 if nties==20
replace netsize=6 if nties==30
replace netsize=7 if nties==42
replace netsize=8 if nties==56
replace netsize=9 if nties==72
replace netsize=10 if nties==90
replace netsize=11 if nties==110
replace netsize=12 if nties==132
replace netsize=13 if nties==156
replace netsize=14 if nties==182
replace netsize=15 if nties==210
replace netsize=16 if nties==240
replace netsize=17 if nties==272
replace netsize=18 if nties==306
replace netsize=19 if nties==342
replace netsize=21 if nties==420
replace netsize=22 if nties==462
replace netsize=24 if nties==552
replace netsize=26 if nties==650
replace netsize=28 if nties==756
replace netsize=31 if nties==930
*/

save "ENSO-participant-altertie-12.dta",replace

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
replace npossties=npossties/2 
*calculate Effective size
gen efctsize=netsize-2*totnum1/netsize

keep SUBID *density efctsize netsize npossties
rename *density *density_12
rename (efctsize netsize npossties) (efctsize_12 netsize_12 npossties_12) 
duplicates drop SUBID, force //n=23
save "ENSO-participant-density-EGOAGG-12.dta",replace

***************************************************************
**# 3 Randomization 
***************************************************************

set seed 20210728
forvalues x=5/12 {
	qui postutil clear
	qui postfile buffer b1density_12 b1density_rd density_12 density_rd efctsize_12 efctsize_rd efctsize_std_12 efctsize_std_rd using mcs, replace //creates a place in memory called buffer in which I can store the results that will eventually be written out to a dataset. mhat is the name of the variable that will hold the estimates in the new dataset called mcs.dta. 

forvalues i=1/1000 {
	
	/*randomly select 12 alters per FOCAL (Netcanvas)*/
    qui cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp"
    qui use "Netcanvas-participant-alter-12.dta",clear
	qui gen networkcanvassourceuuid = networkcanvasuuid 
    qui gen networkcanvastargetuuid = networkcanvasuuid
    qui keep networkcanvasegouuid networkcanvassourceuuid networkcanvastargetuuid 
	qui sample `x',count by(networkcanvasegouuid) //random sample x IDs per FOCAL
	qui save "Netcanvas-participant-alter-randommatch.dta",replace

	*calculate density based on the x randomly selected alters
	qui use "Netcanvas-participant-altertie-long.dta",clear
	qui merge m:1 networkcanvasegouuid networkcanvassourceuuid using "Netcanvas-participant-alter-randommatch.dta",keepusing(networkcanvassourceuuid)
	qui keep if _merge==3 //keep x selected alters for networkcanvassourceuuid
	qui drop _merge
	qui merge m:1 networkcanvasegouuid networkcanvastargetuuid using "Netcanvas-participant-alter-randommatch.dta",keepusing(networkcanvastargetuuid)
	qui keep if _merge==3 //keep x selected alters for networkcanvassourceuuid

	*clean density
	qui drop _merge totval tievalue totnum newtievalue totnum1 //drop density measures based on full data
    qui gen npossties = `x'*(`x'-1)/2

    qui bysort networkcanvasegouuid: egen totval=total(alteralterclose),mi //for value density
	qui gen density = totval/npossties

    qui recode alteralterclose (2/3=1) (1=0),gen(tievalue)
    qui bysort networkcanvasegouuid: egen totnum=total(tievalue),mi //for Binary density
    qui gen bdensity = totnum/npossties

    qui recode alteralterclose (1/3=1),gen(newtievalue)
    qui bysort networkcanvasegouuid: egen totnum1=total(newtievalue),mi // for Density of networks know each other
    qui gen b1density = totnum1/npossties
	
    qui keep networkcanvasegouuid *density totnum1 npossties
    qui rename *density *density_rd
	qui rename (totnum1 npossties) (totnum1_rd npossties_rd)
	
    qui duplicates drop networkcanvasegouuid, force //N=38

	qui merge 1:1 networkcanvasegouuid using "Netcanvas-participant-density-EGOAGG-12.dta"
	qui gen efctsize_rd=netsize_12 - 2*totnum1_rd*(npossties_12/npossties_rd)/netsize_12 //adjust totnum1_rd proportionaly to npossties_12/npossties_rd

	qui replace b1density_rd=0 if _merge==2 //if missing from master, then all x selected alters are 0 in alter-alter ties
	qui replace density_rd=0 if _merge==2 
	qui replace efctsize_rd=netsize_12 if _merge==2 

	qui save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Netcanvas-density-12",replace

	
	/*randomly select 12 alters per FOCAL (ENSO)*/
	qui cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\temp"
	qui use "ENSO-participant-altertie-12.dta", clear
	qui drop dup pickone
	 
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
    qui replace npossties=npossties/2 //it is double counting, so need to divide by 2
	
    qui keep SUBID *density totnum1 npossties
    qui rename *density *density_rd
	qui rename (totnum1 npossties) (totnum1_rd npossties_rd)
    qui duplicates drop SUBID, force

    qui merge 1:1 SUBID using "ENSO-participant-density-EGOAGG-12.dta" //all matched
	qui gen efctsize_rd=netsize_12 - 2*totnum1_rd*(npossties_12/npossties_rd)/netsize_12 //adjust totnum1_rd proportionaly to npossties_12/npossties_rd


	qui save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\ENSO-density-12",replace
	
	
	/*append NETCANVAS and ENSO*/
	qui append using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Netcanvas-density-12"
    qui ttest b1density_12=b1density_rd
	qui local b1d_12 = r(mu_1)
	qui local b1d_rd = r(mu_2)
	
	qui ttest density_12=density_rd
	qui local d_12 = r(mu_1)
	qui local d_rd = r(mu_2)
	
	qui ttest efctsize_12=efctsize_rd
	qui local e_12 = r(mu_1)
	qui local e_rd = r(mu_2)
	
	qui gen efctsize_std_12 = efctsize_12/netsize_12
	qui gen efctsize_std_rd = efctsize_rd/netsize_12
	qui ttest efctsize_std_12=efctsize_std_rd
	
    qui post buffer (`b1d_12') (`b1d_rd') (`d_12') (`d_rd') (`e_12') (`e_rd') (r(mu_1)) (r(mu_2)) //stores the estimated mean for the current draw in buffer for what will be the next observation on mhat.
}
postclose buffer //writes the stuff stored in buffer to the file mcs.dta
use mcs, clear
gen n = `x'
save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\All_random_12_`x'",replace
display "Randomly selected:" `x'
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
ttest b1density_12=b1density_rd 
ttest density_12=density_rd 
ttest efctsize_12=efctsize_rd 
ttest efctsize_std_12=efctsize_std_rd
}

*append data
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data"
use "All_random_12_5",clear
foreach i of numlist 6/12 {
	append using "All_random_12_`i'"
}
save "Analysis_SNAD_12",replace



***************************************************************
**# 4 Figures (N=54)
***************************************************************


/*b1density*/

use "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Analysis_SNAD_12",clear
tempfile e_b1d e_d e_e e_estd b_b1d b_d b_e b_estd

*Plot acceptable error
label var n "# alters randomly selected"
bysort n: egen p95_b1density=pctile(abs(b1density_12-b1density_rd)),p(95)
label var p95_b1density "Density error"
gen p95_b1density_round = round(p95_b1density,0.001)
twoway (connected p95_b1density n, mlab(p95_b1density_round) mlabposition(12) xlab(5 (1)12)), saving(`e_b1d') 
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\b1density-error-p95-ap.tif",replace

/*
bysort n: egen error_2=count(n) if abs(b1density_12-b1density_rd) <= 5/100 
label var error_2 "Error<5% ties"
bysort n: egen error_1=count(n) if abs(b1density_12-b1density_rd) <= 2/100
label var error_1 "Error<1% ties"
twoway (connected error_2 n,mlab(error_2) mlabposition(12)) (connected error_1 n,mlab(error_1) mlabposition(12)),title("Density: # random samples in 1000 trails that have acceptable error") legend(order(1 "Error<5 ties" "in 100 ties" 2 "Error<2 ties" "in 100 ties")) saving(`e_b1d')  
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\b1density-error.tif",replace
*/

*boxcox plot
gen error_b1density = b1density_rd-b1density_12
label var error_b1density "Density error"

graph box error_b1density, over(n) box(1, color(gray%70)) yline(0,lcolor(red)) ///
b1title("# randomly selected alters") saving(`b_b1d')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\b1density.tif",replace
   
   
/*density*/

use "Analysis_SNAD_12",clear

*Plot acceptable error
label var n "# alters randomly selected"
bysort n: egen p95_density=pctile(abs(density_12-density_rd)),p(95)
label var p95_density "Value Density error"
gen p95_density_round = round(p95_density,0.001)
twoway (connected p95_density n, mlab(p95_density_round) mlabposition(12) xlab(5 (1)12)), saving(`e_d')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\density-error-p95-ap.tif",replace

*boxcox plot
gen error_density = density_rd-density_12
label var error_density "Value Density error"

graph box error_density, over(n) box(1, color(gray%70)) yline(0,lcolor(red)) ///
b1title("# randomly selected alters") saving(`b_d')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\density.tif",replace

   
/*effective size*/


use "Analysis_SNAD_12",clear

*Plot acceptable error
label var n "# alters randomly selected"
bysort n: egen p95_efctsize=pctile(abs(efctsize_12-efctsize_rd)),p(95)
label var p95_efctsize "Effective Size error"
gen p95_efctsize_round = round(p95_efctsize,0.01)
twoway (connected p95_efctsize n, mlab(p95_efctsize_round) mlabposition(12) xlab(5 (1)12)), saving(`e_e')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\efctsize-error-p95-ap.tif",replace

*boxcox plot
gen error_efctsize = efctsize_rd-efctsize_12
label var error_efctsize "Effective Size error"

graph box error_efctsize, over(n) box(1, color(gray%70)) yline(0,lcolor(red)) ///
b1title("# randomly selected alters") saving(`b_e')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\efctsize.tif",replace

	 
/*effective size (standardized by netsize)*/
use "Analysis_SNAD_12",clear

*Plot acceptable error
label var n "# alters randomly selected"
bysort n: egen p95_efctsize_std=pctile(abs(efctsize_std_12-efctsize_std_rd)),p(95)
label var p95_efctsize_std "Effective Size (std) error "
gen p95_efctsize_std_round = round(p95_efctsize_std,0.001)
twoway (connected p95_efctsize_std n, mlab(p95_efctsize_std_round) mlabposition(12) xlab(5 (1)12)), saving(`e_estd')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\efctsize-error-p95-ap.tif",replace

*boxcox plot
gen error_efctsize_std = efctsize_std_rd-efctsize_std_12
label var error_efctsize_std "Effective Size (std) error"

graph box error_efctsize_std, over(n) box(1, color(gray%70)) yline(0,lcolor(red)) b1title("# randomly selected alters") saving(`b_estd')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\efctsize.tif",replace
	 

graph combine "`e_b1d'" "`e_d'" "`e_e'" "`e_estd'", title("Max error for 95% of random samples in 1000 trails")
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\All-Error.tif", replace
 
graph combine "`b_b1d'" "`b_d'" "`b_e'" "`b_estd'"
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\All-boxcox.tif", replace



/*histogram of netsize*/


*Netcanvas
use "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp\Netcanvas-participant-alter.dta",clear
keep if broughtforward == "TRUE" | broughtforward == "true" | stilldiscuss== "1" //drop alters from previous wave but not chose in this wave
bysort networkcanvasegouuid: egen netsize = count(networkcanvasuuid) //networkcanvasuuid: unique alterid
duplicates drop networkcanvasegouuid,force
keep netsize 
gen source = "Netcanvas"

*ENSO merge
append using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\Clean data\ENSO-Participant-EGOAGG-clean.dta",keep(netsize density)
replace source = "ENSO" if missing(source)
drop if missing(density) & source == "ENSO" //drop missing/inaccurate data in alter-alter ties
hist netsize,freq w(1)
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\All-histogram.tif",replace

*hist netsize,freq w(1) by(source)
