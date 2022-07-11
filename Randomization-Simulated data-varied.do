****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/10/28
****Version: 17
****Purpose: Data generation


***************************************************************
**# 1 Generate network data
***************************************************************
cd "/N/u/siypeng/Carbonate/Random ties/temp"
    * generate ego level data	
set seed 20210731
forvalues y=10(5)50 {
    clear
    sknor 500 20210731 `y' `y'*`y'/4 1.5 6 //gen skewed distribution of netsize: ssc install sknor
    gen netsize = round(skewnormal) //round to integer
    replace netsize=1 if netsize<1 //replace negative netsize as 1
    drop skewnormal
    gen egoid = _n
	
    * generate alter-alter tie level data based on # possible ties
    gen npossties = netsize*(netsize-1)/2
    expand npossties //generate observations

    * generate alterid
*In a case of netsize=10, gen fromid= 9 1s, 8 2s, 7 3s ... 1 9
    bysort egoid: gen fromid=1 if _n <= netsize-1 //generate 9 1s if netsie=10
    sum netsize
    local max_netsize=r(max)
    forvalues x=2/`max_netsize' {
	bysort egoid: replace fromid = `x' if _n <= `x'*netsize-`x'*(`x'+1)/2 & missing(fromid) //sum(1 to x) = x(x+1)/2
}
*In a case of netsize=10, gen toid= 2-10, 3-10, 4-10 ... 10
bysort egoid fromid: gen toid = _n+1 if fromid == 1 
forvalues x=2/`max_netsize' {
	bysort egoid fromid: replace toid = _n+`x' if fromid == `x' & missing(toid)
}

    * simulate alter-alter tie values
gen tie = runiform() < 0.5 //randomly missing half of ties in all ties

    * calculate density and effective size
bysort egoid: egen b1density=mean(tie)

bysort egoid: egen totnum1=total(tie)
gen efctsize=netsize-2*totnum1/netsize
gen efctsize_std = efctsize/netsize

rename (b1density efctsize efctsize_std) (b1density_full efctsize_full efctsize_std_full)
sum b1density_full efctsize_std_full

save "simulation_varied_`y'",replace	

    * generate r at ego level with .8 correlation with b1density_full
    duplicates drop egoid,force
    local corr=0.8
    quietly sum b1density_full
    local sz=r(sd)
    local mz=r(mean)
    local s2=`sz'^2*(1/`corr'^2-1)
    gen rb=b1density_full+sqrt(`s2')*invnorm(uniform())
    corr rb b1density_full    

keep egoid rb
save "corr_varied_`y'",replace	
}
	
***************************************************************
**# 2 Simulation of random selection 
***************************************************************
qui cd "/N/u/siypeng/Carbonate/Random ties/temp"

set seed 20210731
forvalues y=10(5)50 {
forvalues x=6(2)20 {
	qui postutil clear
	qui postfile buffer mae_b1d rb mae_rb using mcs, replace //creates a place in memory called buffer in which I can store the results that will eventually be written out to a dataset. mhat is the name of the variable that will hold the estimates in the new dataset called mcs.dta. 

forvalues i=1/1000 {
	
	/*randomly select n alters per FOCAL*/
    qui use "simulation_varied_`y'.dta",clear
	qui bysort egoid: gen id = _n if _n <= netsize //gen id for each ego
	qui drop if missing(id) 
	qui sample `x',count by(egoid) //random sample x IDs per FOCAL
	qui keep egoid id
	qui gen fromid=id
	qui rename id toid
	qui save "simulation_varied_randommatch.dta",replace

	*match x randomly selected alters
	qui use "simulation_varied_`y'.dta",clear
	qui merge m:1 egoid fromid using "simulation_varied_randommatch.dta",keepusing(fromid)
	qui keep if _merge==3 //keep x selected alters for fromid
	qui drop _merge
	qui merge m:1 egoid toid using "simulation_varied_randommatch.dta",keepusing(toid)
	qui keep if _merge==3 //keep x selected alters for networkcanvassourceuuid

	*clean density
	qui drop _merge 
	qui rename (netsize npossties totnum1) (netsize_full npossties_full totnum1_full) //drop density measures based on full data
    
	qui bysort egoid: egen npossties_rd = count(tie)
	qui bysort egoid: egen b1density_rd=mean(tie)
    qui bysort egoid: egen totnum1_rd=total(tie)
	qui gen efctsize_rd=netsize_full - 2*totnum1_rd*(npossties_full/npossties_rd)/netsize_full //adjust totnum1_rd proportionaly to npossties_full/npossties_rd
	qui gen efctsize_std_rd=efctsize_rd/netsize_full

    *merge with egolevel variable
    qui duplicates drop egoid, force //N=100
    qui merge 1:1 egoid using "corr_varied_`y'",nogen
  
    *difference between random vs. full
	qui gen mae_b1d = abs(b1density_full-b1density_rd)
	qui sum mae_b1d
	qui local mae_b1d = r(mean)

	qui pwcorr b1density_full b1density_rd,sig
	qui local rb = r(C)[2,1]

	qui pwcorr b1density_full b1density_rd rb,sig
	qui gen mae_rb = abs(r(C)[3,1]-r(C)[3,2])
	qui sum mae_rb

	qui post buffer (`mae_b1d') (`rb') (r(mean)) //stores the estimated mean for the current draw in buffer for what will be the next observation on mhat.
}
postclose buffer //writes the stuff stored in buffer to the file mcs.dta
use mcs, clear
gen rd = `x'
gen n = `y'
save "random_varied_`y'_`x'",replace
display "Randomly selected:" `x'
sum mae_b1d rb mae_rb 
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
}
}
	
*append data by randomly chose alter size
cd "/N/u/siypeng/Carbonate/Random ties/temp"
foreach x of numlist 6(2)20 {
    use "random_varied_10_`x'",clear

    forvalues y=15(5)50 {
    append using "random_varied_`y'_`x'"
}
save "Analysis_Sim_varied_`x'",replace
}

*append all together
use "Analysis_Sim_varied_6",clear
forvalues x=8(2)20 {
    append using "Analysis_Sim_varied_`x'"
}
save "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all_varied",replace

	
***************************************************************
**# 3 Figures 
***************************************************************

cd "/N/u/siypeng/Carbonate/Random ties/temp"
tempfile mae_b1d mae_rb m_rb b_b1d b_rb 

/*b1density*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all_varied",clear

*Plot Mean MAE 
bysort rd n: egen m_density=mean(mae_b1d)
label var m_density "Mean MAE-Density"
sum m_density if rd==10 & n==20

twoway (connected m_density n, xlab(10 (5) 50,angle(45)) ylab(0 (.05) .2,angle(h))),by(rd,note("") rows(1)) subtitle(,pos(6)) xtitle("") saving(`mae_b1d')

*boxcox plot
label var mae_b1d "MAE-Density"
graph box mae_b1d, over(n,lab(nolabel)) over(rd) box(1, color(gray%70)) ylab(0 (.05) .2) saving(`b_b1d')



/*
/*effective size*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all",clear

*Plot 5% error
label var n "Network size"
bysort rd n: egen p95_efctsize=pctile(abs(efctsize_full-efctsize_rd)),p(95)
label var p95_efctsize "Max error for 95% of 1000 random samples (Effective size)"

twoway (connected p95_efctsize n, xlab(10(10)100,angle(45)) ylab(,angle(h))),by(rd,note("")) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-error-p95.tif",replace

*Plot MAE 
label var n "# randonly selected alters by network size"
bysort rd n: egen m_efctsize=mean(abs(efctsize_full-efctsize_rd))
label var m_efctsize "MAE (Effective size)"

twoway (connected m_efctsize n, xlab(10 55 100) ylab(,angle(h))),by(rd,note("") rows(1)) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-MAE.tif",replace

*boxcox plot
gen error_efctsize = efctsize_rd-efctsize_full
label var error_efctsize "Error (Effective size)"
graph box error_efctsize, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) yline(0,lcolor(red)) 
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-boxplot.tif",replace


/*effective size (standardized by netsize)*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all",clear

*Plot Mean MAE 
label var n "# randomly selected alters by network size"
bysort rd n: egen m_efctsize_std=mean(mae_estd)
label var m_efctsize_std "Mean MAE (Effective size)"


twoway (connected m_efctsize_std n, xlab(10 55 100) ylab(,angle(h))),by(rd,note("") rows(1)) subtitle(,pos(6)) xtitle(,size(medlarge)) saving(`mae_estd')
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize_std-MAE.tif",replace

*boxcox plot
label var mae_estd "MAE (Effective size)"
graph box mae_estd, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) yline(.05,lcolor(red)) saving(`b_estd')
graph export "/N/u/siypeng/Carbonate/Random ties/results/efctsize-std-boxplot.tif",replace
*/

/*correlation-density*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_all_varied",clear

*Plot Mean MAE 
bysort rd n: egen m_rb=mean(rb)
label var m_rb "Mean-Corr(Density)"
sum m_rb if rd==5 & n==15

twoway (connected m_rb n, xlab(10 (5) 50,angle(45)) ylab(0 (.2) 1,angle(h))),by(rd,note("") rows(1)) subtitle(,pos(6)) xtitle("") saving(`m_rb')

*boxcox plot
label var rb "Corr(Density)"
graph box rb, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) ylab(0 (.2) 1) saving(`b_rb')


/*Combined*/

graph combine "`mae_b1d'" "mae_g_varied", rows(2) imargin(0 0 0 0) saving(f1_varied,replace)
*graph export "/N/u/siypeng/Carbonate/Random ties/results/varied_Boxplot.tif", replace

graph combine "`m_rb'" "m_rg_varied", rows(2) imargin(0 0 0 0) saving(f2_varied,replace)
*graph export "/N/u/siypeng/Carbonate/Random ties/results/varied_MAE.tif", replace

graph combine  "f1_varied" "f2_varied", rows(2) imargin(0 0 0 0) note("# randomly selected alters by network size",pos(6))
graph export "/N/u/siypeng/Carbonate/Random ties/results/simulate-varied.tif", replace //svg for high dpi

graph combine "`b_b1d'" "b_g_varied" "`b_rb'" "b_rg_varied",imargin(0 0 0 0) note("# randomly selected alters by network size",pos(6))
graph export "/N/u/siypeng/Carbonate/Random ties/results/simulate_varied_boxplot.tif", replace //svg for high dpi
