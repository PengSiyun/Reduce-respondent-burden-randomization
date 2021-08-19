****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/07/31
****Version: 17
****Purpose: Data generation


***************************************************************
**# 1 Generate network data
***************************************************************
cd "/N/u/siypeng/Carbonate/Random ties/temp"
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
**# 2 Simulation of random selection 
***************************************************************
qui cd "/N/u/siypeng/Carbonate/Random ties/temp"

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
gen rd = `x'
gen n = `y'
save "random_`y'_`x'",replace
display "Randomly selected:" `x'
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
ttest b1density_full=b1density_rd 
ttest efctsize_full=efctsize_rd 
}
}
	
	
*append data by randomly chose alter size
cd "/N/u/siypeng/Carbonate/Random ties/temp"
foreach x of numlist 5/12 {
    use "random_10_`x'",clear

    forvalues y=15(5)100 {
    append using "random_`y'_`x'"
}
save "Analysis_Sim_`x'",replace
}

*append all together
use "Analysis_Sim_5",clear
forvalues x=6/12 {
    append using "Analysis_Sim_`x'"
}
replace efctsize_rd=efctsize_full if rd > n //correct the proportion when rd>n
save "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all",replace
	
***************************************************************
**# 3 Figures 
***************************************************************


/*b1density*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all",clear

*Plot 5% error 
label var n "Network size"
bysort rd n: egen p95_density=pctile(abs(b1density_full-b1density_rd)),p(95)
label var p95_density "5% Density error"

twoway (connected p95_density n, yline(950) xlab(10(10)100,angle(45)) ylab(,angle(h))),by(rd,note("")) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/b1density-error-p95.tif",replace

*boxcox plot
gen error = b1density_rd-b1density_full
label var error "Density error"
graph box error, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) yline(0,lcolor(red)) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/b1density-boxplot.tif",replace




/*effective size*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all",clear

*Plot 5% error
label var n "Network size"
bysort rd n: egen p95_efctsize=pctile(abs(efctsize_full-efctsize_rd)),p(95)
label var p95_efctsize "5% Effective Size error"

twoway (connected p95_efctsize n, yline(950) xlab(10(10)100,angle(45)) ylab(,angle(h))),by(rd,note("")) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-error-p95.tif",replace

*boxcox plot
gen error_efctsize = efctsize_rd-efctsize_full
label var error_efctsize "Effective size error"
graph box error_efctsize, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) yline(0,lcolor(red)) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-boxplot.tif",replace


/*effective size (standardized by netsize)*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all",clear
gen efctsize_std_full = efctsize_full/n
gen efctsize_std_rd = efctsize_rd/n 

*Plot 5% error
label var n "Network size"
bysort rd n: egen p95_efctsize_std=pctile(abs(efctsize_std_full-efctsize_std_rd)),p(95)
label var p95_efctsize_std "5% Effective Size (std) error"

twoway (connected p95_efctsize_std n, yline(950) xlab(10(10)100,angle(45)) ylab(,angle(h))),by(rd,note("")) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-std-error-p95.tif",replace

*boxcox plot
gen error_efctsize_std = efctsize_std_rd-efctsize_std_full
label var error_efctsize_std "Effective size (std) error"
graph box error_efctsize_std, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) yline(0,lcolor(red))
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-std-boxplot.tif",replace

	 
