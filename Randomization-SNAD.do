****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/07/27
****Version: 17
****Purpose: explore way to collect alter-alter tie data while reducing participant burden


***************************************************************
**# 1 calculate density for people (NETCANVAS)
***************************************************************

cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp"

*calculate netsize from alter level
use "Netcanvas-participant-alter.dta",clear
keep if broughtforward == "TRUE" | broughtforward == "true" | stilldiscuss== "1" //drop alters from previous wave but not chose in this wave
bysort networkcanvasegouuid: egen netsize = count(networkcanvasuuid) //networkcanvasuuid: unique alterid
gen npossties = netsize*(netsize-1)/2
*drop if netsize <= 12 //drop people with <= 12 alters

*creat proportion of often contact
destring alterfreqcon,replace
recode alterfreqcon (2 3=0) //1=often
bysort networkcanvasegouuid: egen pfreq=mean(alterfreqcon)
save "Netcanvas-participant-alter-12.dta",replace

duplicates drop networkcanvasegouuid,force  
keep networkcanvasegouuid npossties netsize pfreq

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

keep networkcanvasegouuid *density efctsize netsize npossties pfreq
rename *density *density_12
rename (efctsize netsize npossties pfreq) (efctsize_12 netsize_12 npossties_12 pfreq_12) 
duplicates drop networkcanvasegouuid, force //N=62
save "Netcanvas-participant-density-EGOAGG-12.dta",replace



***************************************************************
**# 2 calculate density for people  (ENSO)
***************************************************************
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\temp"

use "ENSO-participant-altertie-long.dta", clear
drop if missing(tievalue) //drop missing/inaccurate data

rename alter_a_name alter_name
bysort SUBID: egen nties=count(tievalue)
*drop if nties<=132 //drop people<= 12 alters: 90=2*(12 chose 2) 
merge m:1 SUBID using "ENSO-Participant-alter-EGOAGG-clean.dta",keepusing(netsize pfreq)
drop if _merge==2
drop _merge 
merge m:1 SUBID alter_name using "ENSO-Participant-alter-LONG-clean",keepusing(tfreq)
drop if _merge==2
drop _merge 
rename alter_name alter_a_name
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

keep SUBID *density efctsize netsize npossties pfreq
rename *density *density_12
rename (efctsize netsize npossties pfreq) (efctsize_12 netsize_12 npossties_12 pfreq_12) 
duplicates drop SUBID, force //n=66
save "ENSO-participant-density-EGOAGG-12.dta",replace

***************************************************************
**# 3 Randomization 
***************************************************************

set seed 20210728
forvalues x=6(2)20 {
	qui postutil clear
	qui postfile buffer mae_b1d mae_f rd rf d_grade_full d_grade_rd f_grade_full f_grade_rd using mcs, replace //creates a place in memory called buffer in which I can store the results that will eventually be written out to a dataset. mhat is the name of the variable that will hold the estimates in the new dataset called mcs.dta. 

forvalues i=1/1000 {
	/*randomly select 12 alters per FOCAL (Netcanvas)*/
    qui cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp"
    qui use "Netcanvas-participant-alter-12.dta",clear
	qui gen networkcanvassourceuuid = networkcanvasuuid 
    qui gen networkcanvastargetuuid = networkcanvasuuid
	qui sample `x',count by(networkcanvasegouuid) //random sample x IDs per FOCAL
	
	*clean alter level data
	qui bysort networkcanvasegouuid: egen pfreq_rd=mean(alterfreqcon)
	qui keep networkcanvasegouuid networkcanvassourceuuid networkcanvastargetuuid netsize pfreq_rd
	qui save "Netcanvas-participant-alter-randommatch.dta",replace

	*calculate density based on the x randomly selected alters
	qui use "Netcanvas-participant-altertie-long.dta",clear
	qui merge m:1 networkcanvasegouuid networkcanvassourceuuid using "Netcanvas-participant-alter-randommatch.dta",keepusing(networkcanvassourceuuid netsize pfreq_rd)
	qui keep if _merge==3 //keep x selected alters for networkcanvassourceuuid
	qui drop _merge
	qui merge m:1 networkcanvasegouuid networkcanvastargetuuid using "Netcanvas-participant-alter-randommatch.dta",keepusing(networkcanvastargetuuid netsize pfreq_rd)
	qui keep if _merge==3 //keep x selected alters for networkcanvassourceuuid

	*clean density
	qui drop _merge totval tievalue totnum newtievalue totnum1 //drop density measures based on full data
    qui gen npossties = `x'*(`x'-1)/2 
	qui replace npossties = netsize*(netsize-1)/2 if `x'>netsize

    qui bysort networkcanvasegouuid: egen totval=total(alteralterclose),mi //for value density
	qui gen density = totval/npossties

    qui recode alteralterclose (2/3=1) (1=0),gen(tievalue)
    qui bysort networkcanvasegouuid: egen totnum=total(tievalue),mi //for Binary density
    qui gen bdensity = totnum/npossties

    qui recode alteralterclose (1/3=1),gen(newtievalue)
    qui bysort networkcanvasegouuid: egen totnum1=total(newtievalue),mi // for Density of networks know each other
    qui gen b1density = totnum1/npossties
	
    qui keep networkcanvasegouuid *density totnum1 npossties pfreq_rd
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
	 
	qui duplicates drop SUBID alter_a_name,force
	qui sample `x',count by(SUBID) //random sample x IDs per FOCAL
	
	*clean alter level data
	qui bysort SUBID: egen pfreq_rd=mean(tfreq)
	qui keep SUBID alter_a_name pfreq_rd
	qui gen alter_b_name=alter_a_name //copy x IDs for alter_b_id
	qui save "ENSO-participant-altertie-long-random-alter.dta",replace
	
	*calculate density based on the x randomly selected alters
	qui use "ENSO-participant-altertie-long.dta",clear
	qui merge m:1 SUBID alter_a_name using "ENSO-participant-altertie-long-random-alter.dta",keepusing(alter_a_name pfreq_rd)
	qui keep if _merge==3 //keep x selected alters for alter_a_id
	qui drop _merge
	qui merge m:1 SUBID alter_b_name using "ENSO-participant-altertie-long-random-alter.dta",keepusing(alter_b_name pfreq_rd)
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
	
    qui keep SUBID *density totnum1 npossties pfreq_rd
    qui rename *density *density_rd
	qui rename (totnum1 npossties) (totnum1_rd npossties_rd)
    qui duplicates drop SUBID, force

    qui merge 1:1 SUBID using "ENSO-participant-density-EGOAGG-12.dta",nogen //all matched
	qui gen efctsize_rd=netsize_12 - 2*totnum1_rd*(npossties_12/npossties_rd)/netsize_12 //adjust totnum1_rd proportionaly to npossties_12/npossties_rd


	qui save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\ENSO-density-12",replace
	
	
	/*append NETCANVAS and ENSO*/
	qui append using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Netcanvas-density-12"
	
	/*Merge with education*/
	qui drop _merge
    qui merge m:1 SUBID using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Demographics.dta",keepusing(grade)
    qui drop if _merge==2
    qui drop _merge


	/*save MAE estimates*/
	qui gen mae_b1d = abs(b1density_12-b1density_rd)
	qui sum mae_b1d
	qui local mae_b1d = r(mean)
	
/*	qui gen efctsize_std_12 = efctsize_12/netsize_12
	qui gen efctsize_std_rd = efctsize_rd/netsize_12
	qui gen mae_estd = abs(efctsize_std_12-efctsize_std_rd)
	qui sum mae_estd
	qui local mae_estd = r(mean)
*/
	
	qui gen mae_pfreq = abs(pfreq_12-pfreq_rd)
	qui sum mae_pfreq 
	qui local mae_pfreq = r(mean)
	
	qui pwcorr b1density_12 b1density_rd,sig
	qui local rd = r(C)[2,1]
	
	qui pwcorr pfreq_12 pfreq_rd,sig
	qui local rf = r(C)[2,1]

	qui pwcorr b1density_12 b1density_rd pfreq_12 pfreq_rd grade,sig
	qui local d_grade_full = r(C)[5,1]
	qui local d_grade_rd = r(C)[5,2]

	qui pwcorr b1density_12 b1density_rd pfreq_12 pfreq_rd grade,sig
	qui local f_grade_full = r(C)[5,3]
	qui local f_grade_rd = r(C)[5,4]

	qui post buffer (`mae_b1d') (`mae_pfreq') (`rd') (`rf') (`d_grade_full') (`d_grade_rd') (`f_grade_full') (`f_grade_rd') //stores the estimated mean for the current draw in buffer for what will be the next observation on mhat.
}
postclose buffer //writes the stuff stored in buffer to the file mcs.dta
use mcs, clear
gen n = `x'
save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\All_random_12_`x'",replace
display "Randomly selected:" `x'
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
sum *
}

*append data
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data"
use "All_random_12_6",clear
foreach i of numlist 8(2)20 {
	append using "All_random_12_`i'"
}
save "Analysis_SNAD_12",replace



***************************************************************
**# 4 Figures (N=128)
***************************************************************


/*b1density*/
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data"

use "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Analysis_SNAD_12",clear
tempfile mae_b1d mae_f m_rd m_rf b_rd b_rf mae_d_grade mae_f_grade b_b1d b_f b_d_grade b_f_grade

*plot average mae
bysort n: egen m_b1density=mean(mae_b1d)
label var m_b1density "Mean MAE-Density"
label var n "# randomly selected alters"
gen m_b1density_round = round(m_b1density,0.001)
twoway (connected m_b1density n, mlab(m_b1density_round) mlabposition(12) xlab(6 (2)20)), saving(`mae_b1d') 
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\b1density-error-p95-ap.tif",replace

*boxcox plot
label var mae_b1d "MAE-Density"
graph box mae_b1d, over(n) box(1, color(gray%70)) ///
b1title("# randomly selected alters") saving(`b_b1d')
*graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\b1density.tif",replace


/*correlation:density-full vs. random*/
use "Analysis_SNAD_12",clear

*plot mean MAE
bysort n: egen m_rd=mean(rd)
label var m_rd "Mean Corr(Density)"
label var n "# randomly selected alters"
gen m_rd_round = round(m_rd,0.001)
twoway (connected m_rd n, mlab(m_rd_round) mlabposition(12) xlab(6 (2)20)), saving(`m_rd') 

*boxcox plot
label var rd "Corr(Density)"

graph box rd, over(n) box(1, color(gray%70)) b1title("# randomly selected alters") saving(`b_rd')
/*
/*correlation error: density-grade*/
use "Analysis_SNAD_12",clear

*plot mean MAE
bysort n: egen m_grade=mean(abs(d_grade_rd-d_grade_full))
label var m_grade "Mean MAE Corr(density,edu)"
label var n "# randomly selected alters"
gen m_grade_round = round(m_grade,0.001)
twoway (connected m_grade n, mlab(m_grade_round) mlabposition(12) xlab(5 (1)12)), saving(`m_d_grade') // full sample correlation=-2.66

*boxcox plot
bysort n: gen b_grade=abs(d_grade_rd-d_grade_full)
label var b_grade "MAE Corr(density,edu)"

graph box b_grade, over(n) box(1, color(gray%70)) b1title("# randomly selected alters") saving(`b_d_grade')
*/

/*prop. of often contact*/
use "Analysis_SNAD_12",clear

*plot mean MAE
bysort n: egen m_f=mean(mae_f)
label var m_f "Mean MAE-Prop. often"
label var n "# randomly selected alters"
gen m_f_round = round(m_f,0.001)
twoway (connected m_f n, mlab(m_f_round) mlabposition(12) xlab(6 (2)20)), saving(`mae_f') 

*boxcox plot
label var mae_f "MAE-Prop. often"
graph box mae_f, over(n) box(1, color(gray%70)) b1title("# randomly selected alters") saving(`b_f')


/*correlation:prop. close-full vs. random*/
use "Analysis_SNAD_12",clear

*plot mean MAE
bysort n: egen m_rf=mean(rf)
label var m_rf "Mean Corr(Prop. often)"
label var n "# randomly selected alters"
gen m_rf_round = round(m_rf,0.001)
twoway (connected m_rf n, mlab(m_rf_round) mlabposition(12) xlab(6 (2)20)), saving(`m_rf') 

*boxcox plot
label var rf "Corr(Prop. often)"

graph box rf, over(n) box(1, color(gray%70)) b1title("# randomly selected alters") saving(`b_rf')

graph combine "`mae_b1d'" "`mae_f'" "`m_rd'" "`m_rf'", imargin(0 0 0 0) 
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\SNAD-full.tif", replace //svg for high dpi

graph combine "`b_b1d'" "`b_f'" "`b_rd'" "`b_rf'", imargin(0 0 0 0) 
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\SNAD-boxplot.tif", replace //svg for high dpi


*histogram of netsize

*Netcanvas
use "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp\Netcanvas-participant-density-EGOAGG-12.dta",clear

*ENSO merge
append using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\temp\ENSO-participant-density-EGOAGG-12.dta"
sum netsize_12,detail
hist netsize_12,freq w(1) xtitle("Network size") note("Mean=12.9, SD=6.5, skewness=1.3, kurtosis=5.7")
graph export "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Results\All-histogram.tif",replace


