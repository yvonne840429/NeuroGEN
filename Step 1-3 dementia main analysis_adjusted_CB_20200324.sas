** CB March 10, 2020: Code adjusted so that new macro cpdata_macro_replacement.sas can be used, for this, enter study_end in Step 1(below libname)
** CB March 13, 2020: Enter last day of study instead of last year of study in %LET study_end =,
                      if exclude = 0 & age >=60 changed to if exclude = 0 & age_Germany >=60 based on
						    *calculate age age which person will turn in the calendar year
							DoB_year = year(DoB)
							age_Germany = enter_year-DoB_year
                      --> applies different age-definition for exclusion which is necessary to avoid persons <60 in SMR calculation;
** CB March 24, 2020: replace log from March 10: code changed so that original macro can be used but correct SMR-list is created: 
                         in code line "calendar_year = enter_year + survival_year1", survival_year1 instead of survival_year0 is used,
                         option 3.1.4 is added, which adjusts person-years based on year in which person enters or leaves cohort (which means that person contributes less person-time)


/* Read first: If your dataset include both dementia and non-dementia patients, please refer to "STEP 0 Data preparation.sas" first to prepare your dataset */
/* Last updated 02/06/2019 */

/********************************************************************************/
/********************************************************************************/
/* 																				*/
/*	Global trends of survival of people with clinical diagnosis of dementia     */
/*																				*/
/*           STEP 1:	 DATA SETUP											    */
/*		     STEP 2:	 ESIMATE SURVIVAL            							*/
/*		     STEP 3:  CALCULATE STANDARD MORTATLITY RATIO (SMR)                 */
/* 																				*/
/********************************************************************************/
/********************************************************************************/

********************************************************************************************************************************************************************************************************

/****************************************************************/
/*																*/
/* 				STEP 1:	DATA SETUP			                	*/
/*																*/
/****************************************************************/;

libname ha 'E:\HA\Dementia';  * PLEASE INPUT YOUR OWN PATH;
%LET study_end = '31DEC2010'd; * Enter last day of study here to be used in macro in Step 3.1 in the date format you use;

******************************************************************* *;
**                 IDENTIFY DEMENTIA CASES                         **
**               290 Dementias                                     **
**             (290.4 Vascular dementia)                           **
**             294.1 Dementia in conditions classified elsewhere   **
**             294.2 Dementia, unspecified                         **
**             331.0 Alzheimer's disease                           **
**             331.1 Frontotemporal dementia                       **
**             331.82 Dementia with lewy bodies                    **
*********************************************************************;

/* Step 1.0 Recode dementia by three major types */
/* Step 1.0 Recode dementia by three major types */

%let alzheimer = %str('331.0');
%let vascular = %str('290.4');
%let Lewy = %str('331.82');

data ha.final;
  set ha.dementia_full_data;
  array diag{15} DIAG_CD V11_A V12_A V13_A V14_A V15_A V16_A V17_A V18_A V19_A V20_A V21_A V22_A V23_A V24_A;
  ad = 0;
  do _n_ = 1 to 15 until(ad = 1);
   if diag{_n_} in: (&alzheimer) then ad = 1;
  end;
  vad = 0;
  do _n_ = 1 to 15 until(vad = 1);
   if diag{_n_} in: (&vascular) then vad = 1;
  end;
  ld = 0;
  do _n_ = 1 to 15 until(ld = 1);
   if diag{_n_} in: (&Lewy) then ld = 1;
  end;
  diag_sum = ad + vad + ld;
  run;

****************************************************************** *;
**                 SPECIFY TYPES OF DEMENTIA                       **
**                                                                 **
**             type = 0 all other types of dementia                **
**             type = 1 331.0 Alzheimer's disease                  **           
**             type = 2 290.4 Vascular dementia                    **          
**             type = 3 331.82 Dementia with lewy bodies           **
**                                                                 **
*********************************************************************;

proc format;
  value demen_type 0 = "all other"
                   1 = "Alzheimer's"
				   2 = "Vascular"
				   3 = "Lewy bodies"; 
run;

data ha.hk_dementia;
  set ha.final;
  type = 0;
  if (ad = 1) and (vad = 0) and (ld = 0) then type = 1;                                                                 
  if (ad = 0) and (vad = 1) and (ld = 0) then type = 2;
  if (ad = 0) and (vad = 0) and (ld = 1) then type = 3;
  keep patid sex dob type entry_date exit_date vital_d;
  format type demen_type;
run;

/* Step 1.1 Case identification - apply exclusion criteria and document number of cases removed from the study */
/* Step 1.1 Case identification - apply exclusion criteria and document number of cases removed from the study */

/* Prepare the main dataset "mydementia" for the main analysis */
/* Recode variables for applying exclusion criteria*/
data ha.mydementia_total;
  set ha.hk_dementia;
  lenfol = exit_date - entry_date;
  age = round((input('31DEC2016', date9.) - dob)/365.25);
  enter_age = round((entry_date - dob)/365.25);
  enter_year = year(entry_date);
  survival_year = year(exit_date) - year(entry_date);
  age_group = 0;
   if (enter_age >=60) and (enter_age < 65) then age_group = 1;
   if (enter_age >=65) and (enter_age < 70) then age_group = 2;
   if (enter_age >=70) and (enter_age < 75) then age_group = 3;
   if (enter_age >=75) and (enter_age < 80) then age_group = 4;
   if (enter_age >=80) and (enter_age < 85) then age_group = 5;
   if (enter_age >=85) then age_group = 6;
  /* add flag on cases to be excluded */
  exclude = 0;
   if entry_date =< input('31DEC2000', date9.) then exclude = 1;
   if entry_date >= input('01JUL2010', date9.) then exclude = 2;
  * added March 13, 2020, by CB: calculate age age which person will turn in the calendar year;
	DoB_year = year(DoB);
	age_Germany = enter_year-DoB_year;
run;

/* Document number of cases to be excluded */
proc freq data = ha.mydementia_total;
  tables exclude;
run;

/* Exclude patients whose diagnosis in the first year after the study period; */
/* Exclude patients with less than six months data from entering the study to the last day of the study; */
/* Exclude patients who were younger than 60 at entering; */

data ha.mydementia;
  set ha.mydementia_total;
   if exclude = 0 & age_Germany >=60; * enter_age changed to age_Germany on March 13, 2020;
run;

* Check patterns of missing values (if applicable);
* proc means data = ha.mydementia n nmiss;
*  var _numeric_;
* run;

* proc mi data = ha.mydementia;
*   ods select misspateern;
* run;

/* Step 1.2 GENERATE DESCRIPTIVE SATATISTICS */
/* Step 1.2 GENERATE DESCRIPTIVE SATATISTICS */

PROC FREQ DATA = ha.mydementia;
  TABLES type sex age_group vital_d;
RUN;

PROC FREQ DATA = ha.mydementia;
  TABLES enter_year*age_group;
RUN;

PROC FREQ DATA = ha.mydementia;
  TABLES enter_year*sex;
RUN;



/****************************************************************/
/*																*/
/* 				STEP 2:	ESTIMTE SURVIVAL		               	*/
/*																*/
/****************************************************************/

* Calculate the median survival time and plot the Kaplan-Meier estimate;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
run;

* Calculate median survival time by dementia type;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
  strata type;
  *ods select Quartiles;
run;

* By gender;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
  strata sex;
  *ods select Quartiles;
run;

* By age group;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
  strata age_group;
  * ods select Quartiles;
run;

* Cox proportional hazards regression;
proc phreg data = ha.mydementia;
class sex (ref = "M") age_group (ref = "1") type (ref = "0");
model lenfol*vital_d(0) =  sex age_group type;
run;



/****************************************************************/
/*																*/
/* 	 STEP 3:  CALCULATE STANDARD MORTATLITY RATIO (SMR)     	*/
/*																*/
/****************************************************************/

/* Step 3.1 Prepare the aggregated table for the dementia population */
/* Step 3.1 Prepare the aggregated table for the dementia population */

/* Expand the data from one record-per-patient to on record-per-interval between each event time, per patient */
/* The SAS macro "cpdate" need to be used */
** CB March 9, 2020: Code adjusted so that new macro cpdata_macro_replacement.sas can be used;
%let FILEPATH = E:\Dropbox\AA2. LEAD AUTHOR PAPERS\Global dementia survival\Data and Syntax\;     * Please specify your own path; 
%include "&FILEPATH.cpdata.sas";
%cpdata(data=ha.mydementia, time = survival_year, event = vital_d(0), outdata = ha.mydementia2);

data ha.smr1;
  set ha.mydementia2;
  age2 = age + survival_year0;
  calendar_year = enter_year + survival_year0;
  /*age_group2  = '60-64';
  if (enter_age >=65) and (enter_age < 70) then age_group2 = '65-69';
  if (enter_age >=70) and (enter_age < 75) then age_group2 = '70-74';
  if (enter_age >=75) and (enter_age < 80) then age_group2 = '75-79';
  if (enter_age >=80) and (enter_age < 85) then age_group2 = '80-84';
  if (enter_age >=85) then age_group2 = '85+';*/
  	exit_year = year(exit_date);
* calculate age in calendar year and create age groups --> age which person will turn in the calendar year;
	DoB_year = year(DoB);
	age_calendaryear = calendar_year-DoB_year;
	  age_group2  = '60-64';
  if (age_calendaryear >=65) and (age_calendaryear < 70) then age_group2 = '65-69';
  if (age_calendaryear >=70) and (age_calendaryear < 75) then age_group2 = '70-74';
  if (age_calendaryear >=75) and (age_calendaryear < 80) then age_group2 = '75-79';
  if (age_calendaryear >=80) and (age_calendaryear < 85) then age_group2 = '80-84';
  if (age_calendaryear >=85) then age_group2 = '85+';
run;

/* 3.1.1. Create table with population count for each stratum of sex, age group, calendar year;*/
proc freq data = ha.smr1;
  tables sex age_group2 calendar_year sex*age_group2*calendar_year / out = FreqCount;
  title 'aggregate table';
run;

data smr_dementia;    
  set FreqCount;
  drop percent;
  rename age_group2 = age
         calendar_year = year;
run;

proc sort data = smr_dementia;
  by year sex age;
run;

/* 3.1.2. Create table with death count for each stratum of sex, age group, calendar year */
proc tabulate data = ha.smr1 out = DeathCount;
  Title 'Number of deaths by sex age and calendar year';
  var vital_d;
  class sex age_group2 calendar_year;
  table sex*age_group2*calendar_year*vital_d*SUM; 
run;

data DeathCount;
  set DeathCount;
drop _type_ _page_ _table_;
rename age_group2 = age
       calendar_year = year;
run;

proc sort data = DeathCount;
  by year sex age;
run;

/* 3.1.3 Merge tables to create table which is basis for SMR calculation */
data ha.smr_dementia;
  merge smr_dementia DeathCount; * CB smr_dementia: wie oft gab es die sex-age_group-year-Kombinationen im Datensatz (jede Person mehrfach drin für Jahre 2004-(max)2015), age_group2 = entry_age, wird nicht variiert!#), DeathCount: wie oft gab es ein Todesfall für jede dieser Kombinationen?;
  by year sex age;
  rename vital_d_Sum = deaths
         count = population;
run;

PROC SORT DATA = ha.smr_dementia; BY year sex age; RUN;
PROC PRINT DATA = ha.smr_dementia; TITLE 'Dementia population for SMR calculation without adjustment of person-years'; RUN;

/* 3.1.4 Option to adjust person-time under risk: subtract 1/2 year in each calendar year for each person with the initial dementia diagnosis in this calendar year
       and subtract 1/2 year in the calendar year a person exited (due to death or other reasons) if the calendar year was not the last year of the study,
	   subtract 3/4 year in calendar year if person entered and exited the cohort in the same year,
       Reasoning: a person diagnosed in October 2005 contributes only 1/4 year time at risk for dying for 2005, we assume mid-year as average time of diagnosis
       --> code replaces the dataset ha.smr_dementia created in 1.4. */
DATA test;
	SET ha.smr1;
	IF enter_year = calendar_year THEN subtract = 0.5; *for calendar year of diagnosis;
	IF (exit_year = calendar_year) AND exit_date ne &study_end THEN subtract = 0.5;* for persons who exited before 2016 in calendar year of exit;
	IF (enter_year = calendar_year) AND ((exit_year = calendar_year) AND exit_date ne &study_end) THEN subtract = 0.75; *for persons who entered and exited in same calendar year if year was before 2016;
RUN;
PROC FREQ DATA = test;
	TABLES subtract*calendar_year / missing;
	*TABLES substract*sex*age_cal_group*calendar_year / list missing;
RUN;

proc tabulate data = test out = subtracting_sum;
  Title 'Number of deaths by sex age and calendar year';
  var subtract;
  class sex age_group2 calendar_year;
  table sex*age_group2*calendar_year*subtract*SUM; 
run;

data subtracting_sum;
  set subtracting_sum;
drop _type_ _page_ _table_;
rename age_group2 = age
       calendar_year = year;
run;

* Test one stratum;
DATA test_stratum;
	SET test;
	IF sex = 'F' AND age_group2 = '80-84' AND calendar_year = 2007;
RUN;
PROC MEANS DATA = test_stratum n nmiss sum;
	VAR subtract;
	TITLE 'To test if subtraction of person-time works, check if sum equals subtract_sum in dataset subtracting_sum, stratum F, 80-84, 2007';
RUN;
PROC PRINT DATA = subtracting_sum;
	TITLE 'dataset subtracting_sum, stratum F, 80, 84, 2007';
	WHERE sex = 'F' AND age = '80-84' AND year = 2007;
RUN;


PROC SORT DATA = subtracting_sum; BY sex year age; RUN;
PROC SORT DATA = ha.smr_dementia; BY sex year age; RUN;
DATA smr_minus;
	MERGE subtracting_sum  ha.smr_dementia;
	BY sex year age;
RUN;
DATA ha.smr_dementia (drop=population);
	SET smr_minus;
	new_count = population - subtract_sum;
RUN;
DATA ha.smr_dementia (drop=subtract_sum);
	SET ha.smr_dementia;
	RENAME new_count = population;
RUN;

PROC SORT DATA = ha.smr_dementia; BY year sex age; RUN;
PROC PRINT DATA = ha.smr_dementia; TITLE 'Dementia population for SMR calculation with person-years adjusted according to option 3.1.4'; RUN;


/* Step 3.2 Prepare the aggregated table for the general population */
/* Step 3.2 Prepare the aggregated table for the general population */

/* Import the general population data */

PROC IMPORT OUT= ha.smr_population 
            DATAFILE= "E:\HA\SMR\population_5years.csv"  /* Please change to your own path */
            DBMS=CSV REPLACE;                            /* Subject to change according to your own data type */
     GETNAMES=YES;
     DATAROW=2; 
RUN;

proc sort data = ha.smr_population;
  by year sex age;
run;

/* Step 3.3 Compute SMR and its 95% CI stratified by age and calendar year */
/* Step 3.3 Compute SMR and its 95% CI stratified by age and calendar year */

ods graphics on;
ods select StdInfo StrataSmrPlot Smr;
proc stdrate data = ha.smr_dementia refdata = ha.smr_population
             stat = rate
			 method = indirect
			 plots = smr
             ;
	 population event = deaths total = population;
	 reference  event = deaths total = population;
	 strata age;
	 by year;
 ods output smr = ha.smr_hk;
 run;

/* All analysis completed */

