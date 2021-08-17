****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/07/19
****Version: 17
****Purpose: explore way to collect alter-alter tie data while reducing participant burden

***************************************************************
**# 1 randomly chose alters for NetCanvas
***************************************************************
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp"

***************************************************************
**# 2 calculate density for people > 10 alters
***************************************************************

*calculate netsize from alter level
use "Netcanvas-participant-alter.dta",clear
keep if broughtforward == "TRUE" | broughtforward == "true" | stilldiscuss== "1" //drop alters from previous wave but not chose in this wave
bysort networkcanvasegouuid: egen netsize = count(networkcanvasuuid) //networkcanvasuuid: unique alterid
gen npossties = netsize*(netsize-1)/2
drop if netsize <= 10 //drop people with <= 10 alters
save "Netcanvas-participant-alter-10.dta",replace

duplicates drop networkcanvasegouuid,force  
keep networkcanvasegouuid npossties

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

keep networkcanvasegouuid *density
rename *density *density_10
duplicates drop networkcanvasegouuid, force //N=38
save "Netcanvas-participant-density-EGOAGG-10.dta",replace


***************************************************************
**# 3 Randomization
***************************************************************

set seed 20210727
forvalues x=5/10 {
	qui postutil clear
	qui postfile buffer mhat mhat_rd using mcs, replace //creates a place in memory called buffer in which I can store the results that will eventually be written out to a dataset. mhat is the name of the variable that will hold the estimates in the new dataset called mcs.dta. 

forvalues i=1/1000 {
    
   	*randomly select 10 alters per FOCAL
    qui use "Netcanvas-participant-alter-10.dta",clear
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

    qui keep networkcanvasegouuid *density
    qui rename *density *density_rd
    qui duplicates drop networkcanvasegouuid, force //N=38

	qui merge 1:1 networkcanvasegouuid using "Netcanvas-participant-density-EGOAGG-10.dta"
	qui replace b1density_rd=0 if _merge==2 //if missing from master, then all x selected alters are 0
    qui ttest b1density_10=b1density_rd
    qui post buffer (r(mu_1)) (r(mu_2)) //stores the estimated mean for the current draw in buffer for what will be the next observation on mhat.
}
postclose buffer //writes the stuff stored in buffer to the file mcs.dta
use mcs, clear
gen n = `x'
save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Netcanvas_random_`x'",replace
display "Randomly selected:" `x'
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
ttest mhat=mhat_rd
}



***************************************************************
**# 4 Figures
***************************************************************

cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data"
use "Netcanvas_random_5",clear
foreach i of numlist 6/10 {
	append using "Netcanvas_random_`i'"
}

*Plot error<1
label var n "# alters randomly selected"
bysort n: egen error_2=count(n) if abs(mhat-mhat_rd) <= 5/100 
label var error_2 "Error<5%"
bysort n: egen error_1=count(n) if abs(mhat-mhat_rd) <= 2/100 
label var error_1 "Error<2%"
twoway (connected error_2 n,mlab(error_2) mlabposition(12)) (connected error_1 n,mlab(error_1) mlabposition(12)),title("# random samples in 1000 trails that have acceptable error") legend(order(1 "Error<5 ties" "in 100 ties" 2 "Error<2 tie" "in 100 ties"))
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\Netcanvas-miss.tif",replace

*boxcox plot
label var mhat_rd "Density"
graph box mhat_rd, over(n) box(1, color(gray%70)) yline(0.442,lcolor(red)) ///
b1title("# randomly selected alters") 
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\Netcanvas.tif",replace
     
*histogram of netsize
use "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp\Netcanvas-participant-alter.dta",clear
keep if broughtforward == "TRUE" | broughtforward == "true" | stilldiscuss== "1" //drop alters from previous wave but not chose in this wave
bysort networkcanvasegouuid: egen netsize = count(networkcanvasuuid) //networkcanvasuuid: unique alterid
duplicates drop networkcanvasegouuid,force
hist netsize,freq w(1)
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\Netcanvas-histogram.tif",replace
