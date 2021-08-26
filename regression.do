****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/07/27
****Version: 17
****Purpose: regression using random sample n=5 with netsize>5

***************************************************************
**# 1 calculate density (NETCANVAS)
***************************************************************

cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp"

*calculate netsize from alter level
use "Netcanvas-participant-alter.dta",clear
keep if broughtforward == "TRUE" | broughtforward == "true" | stilldiscuss== "1" //drop alters from previous wave but not chose in this wave
bysort networkcanvasegouuid: egen netsize = count(networkcanvasuuid) //networkcanvasuuid: unique alterid
gen npossties = netsize*(netsize-1)/2
drop if netsize <= 5 //drop people with <= 5 alters
save "Netcanvas-participant-alter-5.dta",replace

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
rename *density *density_5
rename (efctsize netsize npossties) (efctsize_5 netsize_5 npossties_5) 
duplicates drop networkcanvasegouuid, force //N=57

*get SUBID
merge 1:1 networkcanvasegouuid using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp\Netcanvas-participant-ego",keepusing(ccid)
keep if _merge==3
destring ccid,gen(SUBID)
drop _merge ccid

save "Netcanvas-participant-density-EGOAGG-5.dta",replace



***************************************************************
**# 2 calculate density for people > 5 alters (ENSO)
***************************************************************
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\temp"

use "ENSO-participant-altertie-long.dta", clear
drop if missing(tievalue) //drop missing/inaccurate data
bysort SUBID: egen nties=count(tievalue)
drop if nties<=10 //drop people<= 5 alters: 10=2*(5 chose 2) 
merge m:1 SUBID using "ENSO-Participant-alter-EGOAGG-clean.dta",keepusing(netsize)
keep if _merge==3
drop _merge 

save "ENSO-participant-altertie-5.dta",replace

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
rename *density *density_5
rename (efctsize netsize npossties) (efctsize_5 netsize_5 npossties_5) 
duplicates drop SUBID, force //n=66
save "ENSO-participant-density-EGOAGG-5.dta",replace



***************************************************************
**# 4 Randomization 
***************************************************************

	set seed 20210728
	/*randomly select 5 alters per FOCAL (Netcanvas)*/
    qui cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Netcanvas\temp"
    qui use "Netcanvas-participant-alter-5.dta",clear
	qui gen networkcanvassourceuuid = networkcanvasuuid 
    qui gen networkcanvastargetuuid = networkcanvasuuid
    qui keep networkcanvasegouuid networkcanvassourceuuid networkcanvastargetuuid 
	qui sample 5,count by(networkcanvasegouuid) //random sample 5 IDs per FOCAL
	qui save "Netcanvas-participant-alter-randommatch.dta",replace

	*calculate density based on the x randomly selected alters
	qui use "Netcanvas-participant-altertie-long.dta",clear
	qui merge m:1 networkcanvasegouuid networkcanvassourceuuid using "Netcanvas-participant-alter-randommatch.dta",keepusing(networkcanvassourceuuid)
	qui keep if _merge==3 //keep 5 selected alters for networkcanvassourceuuid
	qui drop _merge
	qui merge m:1 networkcanvasegouuid networkcanvastargetuuid using "Netcanvas-participant-alter-randommatch.dta",keepusing(networkcanvastargetuuid)
	qui keep if _merge==3 //keep x selected alters for networkcanvassourceuuid

	*clean density
	qui drop _merge totval tievalue totnum newtievalue totnum1 //drop density measures based on full data
    qui gen npossties = 5*(5-1)/2

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
	
    qui duplicates drop networkcanvasegouuid, force 

	qui merge 1:1 networkcanvasegouuid using "Netcanvas-participant-density-EGOAGG-5.dta"
	qui gen efctsize_rd=netsize_5 - 2*totnum1_rd*(npossties_5/npossties_rd)/netsize_5 //adjust totnum1_rd proportionaly to npossties_12/npossties_rd

	qui replace b1density_rd=0 if _merge==2 //if missing from master, then all x selected alters are 0 in alter-alter ties
	qui replace density_rd=0 if _merge==2 
	qui replace efctsize_rd=netsize_5 if _merge==2 

	qui save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Netcanvas-density-5",replace

	
	/*randomly select 5 alters per FOCAL (ENSO)*/
	qui cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\ENSO clean\temp"
	qui use "ENSO-participant-altertie-5.dta", clear
	qui drop dup pickone
	 
	qui duplicates drop SUBID alter_a_id,force
	qui sample 5,count by(SUBID) //random sample x IDs per FOCAL
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

    qui merge 1:1 SUBID using "ENSO-participant-density-EGOAGG-5.dta" //all matched
	qui gen efctsize_rd=netsize_5 - 2*totnum1_rd*(npossties_5/npossties_rd)/netsize_5 //adjust totnum1_rd proportionaly to npossties_12/npossties_rd


	qui save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\ENSO-density-5",replace
	
	
	/*append NETCANVAS and ENSO*/
	qui append using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\Netcanvas-density-5",gen(source)
    gsort -source //- descending
    duplicates drop SUBID,force //keep 1st occurance, which means keep NC
	drop _merge


***************************************************************
**# 4 Merge with IADRC
***************************************************************

*Cognitive data
merge 1:m SUBID using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\IADC-Long-CleanA.dta" //9 cases not found in IADRC
drop if _merge==2
gsort -visitdate //- descending
duplicates drop SUBID,force //keep 1st occurance, which means keep most recent date
rename age age_i
rename ageatvisit ageiadc //only 23 have moca
drop _merge

*create variable for AD
gen ad=primarysubtype
replace ad= "Alzheimers disease" if contributel=="Alzheimers disease" //code as AD if other condition says AD even primary subtype is not AD 
gen adtype=1 if ad== "Alzheimers disease"	  
replace	adtype=0 if !missing(ad) & adtype!=1	   
label define ad 0 "Non AD" 1 "AD"
label values adtype ad
*create diagnosis variable + data clean
encode diag,gen(diagnosis) //convert string to numeric
recode diagnosis (4 7 8=1) (1 2 5 6 =2) (3=3)
lab def diagnosisnew 1 "Normal" 2 "MCI" 3 "Dementia"
lab val diagnosis diagnosisnew
lab var diagnosis "Normal, MCI, or dementia"

*demo data
merge 1:1 SUBID using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Demographics.dta"
drop if _merge==2
drop _merge

*merge with Redcap
merge 1:m SUBID using "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\codes\Redcap R01-old\Cleaned\REDcap-old-R01-participant.dta",force
drop if _merge==2


save "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\regression-5",replace

***************************************************************
**# 5 Regression
***************************************************************
use "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization\Data\regression-5",clear
rename self srh
pwcorr b1density_5 b1density_rd grade gds15 srh,sig





