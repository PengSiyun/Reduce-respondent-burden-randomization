****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/07/31
****Version: 17
****Purpose: Data generation


***************************************************************
**# 1 Generate network data
***************************************************************
cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization-alter-alter ties\Data\temp"
    * generate ego level data	
set seed 20210731
forvalues y=10(5)100 {
    clear
	set obs 100 //generate 100 ego data
    gen egoid = _n
	
    * generate alter-alter tie levels data based on # possible ties
    gen netsize = `y'
    gen npossties = netsize*(netsize-1)/2
    expand npossties //generate observations

    * generate alterid
*In a case of netsize=10, gen fromid= 9 1s, 8 2s, 7 3s ... 1 9
    bysort egoid: gen fromid=1 if _n <= netsize-1 //generate 9 1s if netsie=10
    forvalues x=2/`y' {
	bysort egoid: replace fromid = `x' if _n <= `x'*netsize-`x'*(`x'+1)/2 & missing(fromid) //sum(1 to x) = x(x+1)/2
}
*In a case of netsize=10, gen toid= 2-10, 3-10, 4-10 ... 10
bysort egoid fromid: gen toid = _n+1 if fromid == 1 
forvalues x=2/`y' {
	bysort egoid fromid: replace toid = _n+`x' if fromid == `x' & missing(toid)
}

    * simulate alter-alter tie values
gen tie = runiform() < 0.5 //randomly missing half of ties in all ties

    * calculate density and effective size
bysort egoid: egen b1density=mean(tie)

bysort egoid: egen totnum1=total(tie)
gen efctsize=netsize-2*totnum1/netsize

rename (b1density efctsize) (b1density_full efctsize_full)
sum b1density_full efctsize_full

save "simulation_`y'",replace	
}
	
***************************************************************
**# 2 Simulation of random selection (stopped here)
***************************************************************
qui cd "C:\Users\bluep\Dropbox\peng\Academia\Work with Brea\SNAD\SNAD data\Peng\Randomization-alter-alter ties\Data\temp"

set seed 20210731
forvalues y=10(5)100 {
forvalues x=5/12 {
	qui postutil clear
	qui postfile buffer b1density_full b1density_rd efctsize_full efctsize_rd using mcs, replace //creates a place in memory called buffer in which I can store the results that will eventually be written out to a dataset. mhat is the name of the variable that will hold the estimates in the new dataset called mcs.dta. 

forvalues i=1/1000 {
	
	/*randomly select n alters per FOCAL*/
    qui use "simulation_`y'.dta",clear
	qui bysort egoid: gen id = _n if _n <= netsize //gen id for each ego
	qui drop if missing(id) 
	qui sample `x',count by(egoid) //random sample x IDs per FOCAL
	qui keep egoid id
	qui gen fromid=id
	qui rename id toid
	qui save "simulation_randommatch.dta",replace

	*match x randomly selected alters
	qui use "simulation_`y'.dta",clear
	qui merge m:1 egoid fromid using "simulation_randommatch.dta",keepusing(fromid)
	qui keep if _merge==3 //keep x selected alters for fromid
	qui drop _merge
	qui merge m:1 egoid toid using "simulation_randommatch.dta",keepusing(toid)
	qui keep if _merge==3 //keep x selected alters for networkcanvassourceuuid

	*clean density
	qui drop _merge 
	qui rename (netsize npossties totnum1) (netsize_full npossties_full totnum1_full) //drop density measures based on full data
    
	qui gen npossties_rd = `x'*(`x'-1)/2
	qui bysort egoid: egen b1density_rd=mean(tie)
    qui bysort egoid: egen totnum1_rd=total(tie)
	qui gen efctsize_rd=netsize_full - 2*totnum1_rd*(npossties_full/npossties_rd)/netsize_full //adjust totnum1_rd proportionaly to npossties_12/npossties_rd
    
	qui duplicates drop egoid, force //N=100

    *difference between random vs. full
    qui ttest b1density_full=b1density_rd
	qui local b1d_full = r(mu_1)
	qui local b1d_rd = r(mu_2)
	
	qui ttest efctsize_full=efctsize_rd
	
    qui post buffer (`b1d_full') (`b1d_rd') (r(mu_1)) (r(mu_2)) //stores the estimated mean for the current draw in buffer for what will be the next observation on mhat.
}
postclose buffer //writes the stuff stored in buffer to the file mcs.dta
use mcs, clear
gen n = `x'
save "random_`y'_`x'",replace
display "Randomly selected:" `x'
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
ttest b1density_full=b1density_rd 
ttest efctsize_full=efctsize_rd 
}
}
	
	
	
