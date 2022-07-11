****Priject: SNAD
****Author:  Siyun Peng
****Date:    2021/10/29
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
	
    * generate alter level data 
    expand netsize
    gen gender = runiform() < 0.5 //randomly missing half of gender
    bysort egoid: egen pgender=mean(gender)
    rename (pgender) (pgender_full)
    save "alter_varied_`y'",replace

    * generate r with .8 correlation with pgender
    duplicates drop egoid,force
    local corr=0.8
    quietly sum pgender_full
    local sz=r(sd)
    local mz=r(mean)
    local s2=`sz'^2*(1/`corr'^2-1)
    gen rg=pgender_full+sqrt(`s2')*invnorm(uniform())
    corr rg pgender_full    
keep egoid rg
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
	qui postfile buffer mae_g rg mae_rg using mcs, replace //creates a place in memory called buffer in which I can store the results that will eventually be written out to a dataset. mhat is the name of the variable that will hold the estimates in the new dataset called mcs.dta. 

forvalues i=1/1000 {
	
	/*randomly select n alters per FOCAL*/
        qui use "alter_varied_`y'.dta",clear
	qui sample `x',count by(egoid) //random sample x IDs per FOCAL

	*clean pgender
	qui bysort egoid: egen pgender_rd=mean(gender)
    
	qui duplicates drop egoid, force //N=100

    *merge with egolevel variable
    qui merge 1:1 egoid using "corr_varied_`y'",nogen
  
    *difference between random vs. full
	qui gen mae_g = abs(pgender_full-pgender_rd)
	qui sum mae_g
	qui local mae_g = r(mean)
	
	qui pwcorr pgender_full pgender_rd,sig
	qui local rg = r(C)[2,1]
	
	qui pwcorr pgender_full pgender_rd rg,sig
	qui gen mae_rg = abs(r(C)[3,1]-r(C)[3,2])
	qui sum mae_rg
	
	qui post buffer (`mae_g') (`rg') (r(mean)) //stores the estimated mean for the current draw in buffer for what will be the next observation on mhat.
}
postclose buffer //writes the stuff stored in buffer to the file mcs.dta
use mcs, clear
gen rd = `x'
gen n = `y'
save "random_alter_varied_`y'_`x'",replace
display "Randomly selected:" `x'
sum mae_g rg mae_rg
*hist mhat_rd, percent xline(0.475,lwidth(1pt) lcolor(red)) color(gray%50)
}
}
	
*append data by randomly chose alter size
cd "/N/u/siypeng/Carbonate/Random ties/temp"
foreach x of numlist 6(2)20 {
    use "random_alter_varied_10_`x'",clear

    forvalues y=15(5)50 {
    append using "random_alter_varied_`y'_`x'"
}
save "Analysis_Sim_alter_varied_`x'",replace
}

*append all together
use "Analysis_Sim_alter_varied_6",clear
forvalues x=8(2)20 {
    append using "Analysis_Sim_alter_varied_`x'"
}
save "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_alter_all_varied",replace

	
***************************************************************
**# 3 Figures 
***************************************************************

cd "/N/u/siypeng/Carbonate/Random ties/temp"

/*pgender*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_alter_all_varied",clear

*Plot Mean MAE 
bysort rd n: egen m_g=mean(mae_g)
label var m_g "Mean MAE-Prop. often"
sum m_g if rd==20 & n==50

twoway (connected m_g n, xlab(10 (5) 50,angle(45)) ylab(0 (.05) .2,angle(h))),by(rd,note("") rows(1)) subtitle(,pos(6)) xtitle("") saving(mae_g_varied,replace)

*boxcox plot
label var mae_g "MAE-Prop. often"
graph box mae_g, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) saving(b_g_varied,replace)

/*correlation-pgender*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_alter_all_varied",clear

*Plot Mean MAE 
bysort rd n: egen m_rg=mean(rg)
label var m_rg "Mean Corr(Prop. often)"
sum m_rg if rd==6 & n==20


twoway (connected m_rg n, xlab(10 (5) 50,angle(45)) ylab(0 (.2) 1,angle(h))),by(rd,note("") rows(1)) subtitle(,pos(6)) xtitle("") saving(m_rg_varied,replace)

*boxcox plot
label var rg "Corr(Prop. often)"
graph box rg, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) ylab(0 (.2) 1) saving(b_rg_varied,replace)

/*correlation error-pgender*/
use "/N/u/siypeng/Carbonate/Random ties/clean data/Analysis_Sim_alter_all_varied",clear

*Plot Mean MAE 
label var n "# randomly selected alters by network size"
bysort rd n: egen m_rg=mean(mae_rg)
label var m_rg "Mean MAE-Corr(Prop. often)"
twoway (connected m_rg n, xlab(10 (5) 50,angle(45)) ylab(,angle(h))),by(rd,note("") rows(1)) subtitle(,pos(6)) xtitle(,size(medlarge)) saving(mae_rg_varied,replace)

*boxcox plot
label var mae_rg "MAE-Corr(Prop. often)"
graph box mae_rg, over(n,lab(nolab)) over(rd) box(1, color(gray%70)) saving(b_mae_rg_varied,replace)


