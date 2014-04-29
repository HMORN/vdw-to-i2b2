/*
Program: vdw_to_i2b2_step1_vdw_extraction.sas
Date: 9/24/2010
Author: David Eastman, Group Health Research Institute
Purpose: Extract data from the VDW V2 data structures and make
         a SAS dataset for transfer into the i2b2 database.

This program is step one of the "put VDW V2 data into i2b2"
sequence of SAS programs.  Simply put, it extracts data from
the VDW V2 data structures and outputs a SAS dataset (named
for_i2b2_load) into a directory.  This dataset will be exported
to CSV by the next SAS program in the sequence.

Edit the site-specific macro variables between "BEGIN EDIT SECTION"
and "END EDIT SECTION" and then do a test run against one year of
data (make the ute_start_year and ute_end_year values equal).

After a successful test run of one year, change the utilization time
period to whatever you want (if more than the one year) and run this
program again.

This program IS extendable (i.e., you can create your own site-specific facts
as part of this extraction process) by adding code to the
vdw_to_i2b2_step1_plugin_code.sas file that lives in the same directory as this
program.  See comments and sample code in that file for details.
*/

/******************************************************************************
*******************************************************************************
    BEGIN EDIT SECTION
*******************************************************************************
******************************************************************************/
*If you do a remote submit to a SAS server, rsubmit/signon code goes here;
*Comment this next %include line out if you do NOT rsubmit to a SAS server.;





*%make_spm_comment(I2B2 VDW Fact Abstraction Step One );


*Change the next line to point to your site StdVars.sas file.;
%include 'StdVars.sas';

*Change the next line to point to a directory where the SAS output should be directed.;
%let sasout=d:\;

/* \\ghrisas\warehouse\management\offlinedata\i2b2;*/


*This program loads utilization for a range of years.;
*Change the next two lines to indicate the lower and upper bounds;
*Note that demographics (person-level i2b2 facts) will fall outside this range;
%let ute_start_year=2000;
%let ute_end_year=2011;

*Edit this series macro variable flags to either 1 or 0 to load or NOT load the;
*indicated type of data.  Unless your site has incomplete data, go ahead and load it.;
%let age_load_flag   =1; *Load age data (1) or do NOT load it;
%let race_load_flag =1;
%let gender_load_flag=1; *Load gender/sex data (1) or do NOT load it (0);
%let vitals_load_flag=1; *Load vital status (alive or dead) data (1) or do NOT load it (0);
%let dx_load_flag    =1; *Load diagnosis data (1) or do NOT load it (0);
%let px_load_flag    =1; *Load procedure data (1) or do NOT load it (0);
%let rx_load_flag    =1; *Load pharmacy data (1) or do NOT load it (0);
%let bmi_load_flag   =1; *Load body mass index (BMI) data (1) or do NOT load it (0);
%let tumor_load_flag =1; *Load tumor/cancer data (1) or do NOT load it (0);
%let lab_load_flag =1; *Load lab data (1) or do NOT load it (0);

*There will inevitably be tons of people in the demographic file that will NOT be in;
*any of the utilization files (dx, px, rx, etc), so set this next flag to 1 to remove;
*the dem-only people from the final file.  Set to 0 to leave them in.  Default=1.;
%let remove_people_with_dem_only=1; *Set to 0 to include people with only demographic facts;

*Pharmacy data is loaded into i2b2 using the RXCUI not NDC coding system;
*To load pharmacy data, an NDC-to-RXCUI lookup table is required with variables;
*NDC and RXCUI.  NDC is more granular than RXCUI.  Change the next two lines to;
*point to your RXCUI library and dataset;
%let rxcui_lib=\CRN_VDW; *Trailing slash required;
%let rxcui_data=unifiedndc; *Name of RXCUI SAS data file;

*In order to allow ad hoc site-specific custom facts to be generated, a generic;
*"plugin" file is included in this.  It must be included in this program to take;
*advantage of the only-alive-during-this-program-run patient number lookup file.;
*The plugin file (called vdw_to_i2b2_step1_plugin_code.sas and contained in the;
*same directory as this program) initially is all commented out, but has comments;
*and sample (enrollment) code to illustrate how to generate site specific facts;
*not part of this base program.;
*Tweak the program_directory value to point to the directory containing this;
*program and the plugin program.  Trailing (back)slash is required.;
%let program_directory=\i2b2\standardized\;
/******************************************************************************
*******************************************************************************
    END EDIT SECTION
*******************************************************************************
*******************************************************************************
    DO NOT EDIT BELOW HERE
*******************************************************************************
******************************************************************************/

/******************************************************************************
*******************************************************************************
    CREATE OUTPUT TABLE SHELL, DEFINE MACROS, LIBREFS ETC...
*******************************************************************************
******************************************************************************/
options nocenter msglevel=i mprint errorabend;

*Declare libref to point to semi-temporary SAS dataset location;
libname sasout "&sasout";

*Create output SAS table shell. CONCEPT_CD is length 50 in i2b2, but 30 is;
*plenty for the SAS work.;

%let for_load=sasout.for_i2b2_load;
proc sql;
    create table &for_load (compress=yes) (
         PATIENT_NUM  NUM  length=8
		 ,ENCOUNTER_NUM num length=8
        ,CONCEPT_CD CHAR length=30
        ,START_DATE   NUM  length=4 format=mmddyy10.
		,Nval_Num Num length=4                  /* Changes here to incorporate XML ontologies */
		,Tval_Char CHAR length=1
		,ValType_Cd Char length=1

    );
    describe table &for_load;
quit;


*Declare libref to point to RXCUI library and declare a macro variable that fully names the SAS file;
libname rxcui "&rxcui_lib" access=readonly;
%let _vdw_rxcui=rxcui.&rxcui_data;

*Declare a macro that calculates age given birth date variable and an index/reference date.;
%macro calc_age( index_date=
                ,birth_date=);
    %*Note: if a persons birthday is leap day (February 29), then it is counted as March 1;
    %*on non-leap years.;
    floor ((intck('month',&birth_date,&index_date) - (day(&index_date) < day(&birth_date))) / 12)
%mend calc_age;

*Define a macro that replaces an unfuzzed date var with a fuzzed date var on a dataset.;
*Every date loaded into i2b2 will be adjusted by a person-specific random number between -60 and 60;
*excluding zero (i.e., no non-fuzzy fuzz factors are allowed).  Also, swap out MRN and replace it;
*with PATIENT_NUM, the fake patient-level identifer.;
%macro fuzz_date_var(inds=
                    ,outds=
                    ,unfuzzedDateVarName=ADATE
                    ,fuzzedDateVarName=FUZZED_ADATE
                    ,dropInputTable=1);
    proc sql;
        create table &outds (drop=&unfuzzedDateVarName MRN) as
            select a.*,
                   (a.&unfuzzedDateVarName + b.date_fuzz_factor) as &fuzzedDateVarName format=mmddyy10. length=4,
                   b.PATIENT_NUM
            from &inds a inner join patient_mapping b
            on a.MRN=b.MRN;

        %if &dropInputTable EQ 1 %then %do;
            drop table &inds;
        %end;
    quit;
%mend fuzz_date_var;

/******************************************************************************
*******************************************************************************
    PREPARE FAKE PATIENT-LEVEL IDENFIER/DATE FUZZ TABLE
*******************************************************************************
******************************************************************************/
*The i2b2 database contains individual level data, but the patient identifing variable;
*in the i2b2 database is a made-up random value for each person and the lookup table that;
*converts between it and the VDW MRN values is NOT kept after data has finished loading;
*into i2b2.  This macro creates the patient_mapping table that contains the randomly;
*generated made-up patient-specific "identifiers" that gets used when each type of data;
*gets prepped for loading into the i2b2 database.;

*Generate a sequential numeric patient identifer (PATIENT_NUM) for all demog MRN;
*values in random sorted order MRN will NOT be loaded into i2b2, only PATIENT_NUM,;
*plus the patient_mapping file is not retained so PATIENT_NUM cannot be reverse;
*engineered to produce MRN.  The patient mapping table only lives for the duration;
*of this program.;
%macro make_fake_patient_ids;
    %*Get all MRNs from the demographic table, sort randomly, and assign sequential;
    %*patient numbers.  MRN on each fact record will be converted to PATIENT_NUM;
    %*using this lookup table.  In addition, all dates will be fuzzed plus or minus;
    %*60 days (with no zero offset fuzzes) with the date fuzz factor being constant;
    %*for each patient for the duration of this program.;
    data patient_mapping;
        set &_vdw_demographic (keep=MRN);
        random_number = ranuni(-1);
    run;
    proc sort;
        by random_number;
    run;
    data patient_mapping (index=(MRN PATIENT_NUM)
                          label='Temporary file of artificial person identifiers for the i2b2 data');
        set patient_mapping (drop=random_number);
        length PATIENT_NUM 8. date_fuzz_factor 3.;
        PATIENT_NUM = _N_;
        label PATIENT_NUM='Fake patient-level identifier to de-identify data in i2b2 (cannot be reverse engineered)'
              MRN='Real patient-identifer, not to be used in i2b2'
              date_fuzz_factor='Per-patient adjustment to be made to all dates before loading into i2b2 to anonymize data';
        date_fuzz_factor=0;
        do until(date_fuzz_factor NE 0);
            date_fuzz_factor = int(ranuni(-1) * 121) - 60; *Creates distribution of +/- 60 with no zero output values;
        end;
    run;
    title 'PATIENT_MAPPING TABLE';
    proc sql;
        select count(*) as NOBS from patient_mapping;
    quit;
    proc freq;
        tables date_fuzz_factor;
    run;
    title;
%mend make_fake_patient_ids;
%make_fake_patient_ids; *Execute the macro;

/******************************************************************************
*******************************************************************************
    PREPARE PATIENT-LEVEL DATA ELEMENTS FOR LOADING
*******************************************************************************
******************************************************************************/
*This macro generates demographic i2b2 fact records (age, sex, vital status);
*if requested.;
%macro patient_level_data;
    %if (&age_load_flag EQ 1) OR (&gender_load_flag EQ 1) OR (&vitals_load_flag EQ 1) OR (&race_load_flag EQ 1) %then %do;
        %*Get birth date, sex, and death date for all patients (with non-null birth;
        %*from the VDW demographic and death tables.  Discard death dates of poor confidence.;
        %*The birth and death dates do NOT need to be fuzzed because we are going to only use;
        %*year of birth and year of death.;
        proc sql;
            create table demographics1 (label='Dates of birth and death and sex code') as
                select a.MRN,
                       a.Birth_Date format=mmddyy10.,
                       lowcase(coalesce(a.Gender,'u')) as Sex,
					   a.race1,
					   a.race2,
					   a.race3,
					   a.hispanic,
                       b.DeathDt as Death_Date format=mmddyy10.
                from &_vdw_demographic a left join &_vdw_death (where=(confidence NE 'P')) b
                on a.MRN=b.MRN
                where a.Birth_Date NE .;
 

        quit;

        %*Swap out MRN for PATIENT_NUM.  Also filter out people that were born after ute time period ends;
        %*and folks that died prior to the start of the ute time period.;
        proc sql;
            create table demographics2 as
                select b.PATIENT_NUM, a.Birth_Date, a.Sex, a.Death_Date,
				a.race1, a.race2, a.race3, a.hispanic
                from demographics1 a inner join patient_mapping  b
                on a.MRN=b.MRN
                where a.Birth_Date <= "31dec&ute_end_year"d and
                      (a.Death_Date is null OR a.Death_Date >="01jan&ute_start_year"d);

            drop table demographics1;
        quit;

        %if &age_load_flag EQ 1 %then %do;
            %*Output age data for loading into i2b2 if requested.;
            %*Create an age as of year X for all years in the specified ute time period;
            %*up until the year the person died (if dead) and after they were born (had to be;
            %*born during the calendar year, not necessarily on Jan 1).  Age as of yyyy is ;
            %*age on Jan 1 of the year yyyy. Age is capped at 90, so any age > 91 is recoded;
            %*to 90.;

		/*Adding New Insert for SHRINE here.  Using the index date of Feb 12, 2010 because that is 
			when KPNC loaded their fact table.  */

           proc sql;
		      insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
			   select PATIENT_NUM,
			                 0,
                           compress("DEM|AGE:" ||
                                    put((case when %calc_age(index_date="12feb2010"d,birth_date=Birth_Date) between 0 and 90
                                                  then %calc_age(index_date="12feb2010"d,birth_date=Birth_Date)
                                              when %calc_age(index_date="12feb2010"d,birth_date=Birth_Date)<0 then 0 /*Handles cases of age -1*/
                                              else 90 end),3.)),
                           "12feb2010"d
                    from demographics2
                 ;

                quit;
		  
            %do yyyy=&ute_start_year %to &ute_end_year;
                proc sql;
                    insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
                    select PATIENT_NUM,
					      0,
                           compress("DEM|AGEASOF|&yyyy:" ||
                                    put((case when %calc_age(index_date="01jan&yyyy"d,birth_date=Birth_Date) between 0 and 90
                                                  then %calc_age(index_date="01jan&yyyy"d,birth_date=Birth_Date)
                                              when %calc_age(index_date="01jan&yyyy"d,birth_date=Birth_Date)<0 then 0 /*Handles cases of age -1*/
                                              else 90 end),3.)),
                           "01jan&yyyy"d
                    from demographics2
                    where year(Birth_Date)<=&yyyy and (Death_Date is null OR year(Death_Date)>=&yyyy);
		
                quit;
            %end;
        %end;

        %if &gender_load_flag EQ 1 %then %do;
            %*Output sex data for loading into i2b2 if requested.  The date attached to sex ;
            %*will be the 1st day of the current (loading) year unless the person has died;
            %*in which case it will be Jan 1st of the year of death.;
            proc sql;
                insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
                select PATIENT_NUM,
				        0,
                       compress('DEM|SEX:' || Sex),
                       (case when Death_Date is not null then mdy(1,1,year(Death_Date))
                             else                             mdy(1,1,year("&sysdate"d)) end)
                from demographics2;
            quit;
        %end;

		 %if &race_load_flag EQ 1 %then %do;
            %*Output sex data for loading into i2b2 if requested.  The date attached to sex ;
            %*will be the 1st day of the current (loading) year unless the person has died;
            %*in which case it will be Jan 1st of the year of death.;
            proc sql;
                insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
                select PATIENT_NUM,
				       0,
                       compress('DEM|RACE1:' || race1),
                       (case when Death_Date is not null then mdy(1,1,year(Death_Date))
                             else                             mdy(1,1,year("&sysdate"d)) end)
                from demographics2;
            quit;

			proc sql;
                insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
                select PATIENT_NUM,
				        0,
                       compress('DEM|RACE2:' || race2),
                       (case when Death_Date is not null then mdy(1,1,year(Death_Date))
                             else                             mdy(1,1,year("&sysdate"d)) end)
                from demographics2;
            quit;

			proc sql;
                insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
                select PATIENT_NUM,
				        0,
                       compress('DEM|RACE3:' || race3),
                       (case when Death_Date is not null then mdy(1,1,year(Death_Date))
                             else                             mdy(1,1,year("&sysdate"d)) end)
                from demographics2;
            quit;

			proc sql;
                insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
                select PATIENT_NUM,
				       0,
                       compress('DEM|HISPANIC:' || hispanic),
                       (case when Death_Date is not null then mdy(1,1,year(Death_Date))
                             else                             mdy(1,1,year("&sysdate"d)) end)
                from demographics2;
            quit;


        %end;

        %if &vitals_load_flag EQ 1 %then %do;
            %*Output vital status data for loading into i2b2 if requested.;
            %*Create a vital status as of year X for all years in the specified ute time period;
            %*when the person was alive (born and not dead yet).  The date attached will be Jan 1;
            %*of the loop year. Vital status=y means dead and vital status=n means alive.;
            %do yyyy=&ute_start_year %to &ute_end_year;
                proc sql;
                    insert into &for_load (PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
                    select PATIENT_NUM,
					        0,
                           compress("DEM|VITALASOF|&yyyy:" || (case when Death_Date is null      then 'n'
                                                                    when year(Death_Date)>=&yyyy then 'n'
                                                                                                 else 'y' end)),
                           "01jan&yyyy"d
                    from demographics2
                    where year(Birth_Date)<=&yyyy and (Death_Date is null OR year(Death_Date)>=&yyyy);
                quit;
            %end;
        %end;
    %end;
%mend;
%patient_level_data; *Execute the macro;

/******************************************************************************
*******************************************************************************
    PREPARE DIAGNOSIS UTILIZATION DATA FOR LOADING
*******************************************************************************
******************************************************************************/

%macro assign_encs;


%if &dx_load_flag EQ 1 or &px_load_flag Eq 1 %then %do;

data getencs(keep=enc_id);
set &_vdw_utilization;
run;

proc sort data=getencs out=sortedencid nodupkey; by enc_id; run;

data numberthem;
set sortedencid;
encounter_num=_n_+1000000;
run;
%end;

%mend;


%assign_encs;






%macro dx_data;
    %if &dx_load_flag EQ 1 %then %do;
        proc sql;
            create table dx_temp1 (label='A record per dx code per date per person') as
                select distinct MRN, DX, ADATE, enc_id
                from &_vdw_dx
                where ADATE between "01jan&ute_start_year"d and "31dec&ute_end_year"d;
        quit;

		proc sort data=dx_temp1; by enc_id; run;

		data dx_temp2(keep=mrn dx adate encounter_num );
		merge dx_temp1(in=a) numberthem(in=b);
		by enc_id;
		if a;
		run;



        %fuzz_date_var(inds=dx_temp2,
                       outds=dx_fuzzed);

        proc sql; %*There are only ICD-9 diagnosis codes so far;
            insert into &for_load(PATIENT_NUM, encounter_num, CONCEPT_CD, START_DATE)
            select PATIENT_NUM,
			       encounter_num,
                   compress('DXICD09:' || DX),
                   FUZZED_ADATE
            from dx_fuzzed;

            drop table dx_fuzzed;
        quit;
    %end;
%mend dx_data;
%dx_data;

/******************************************************************************
*******************************************************************************
    PREPARE CPT/HCPC PROCEDURE UTILIZATION DATA FOR LOADING
*******************************************************************************
******************************************************************************/
%macro px_data;
    %if &px_load_flag EQ 1 %then %do;
        proc sql;
            create table px_temp1 (label='A record per px per codetype per date per person') as
                select distinct MRN, PX, ADATE, px_CodeType, enc_id
                from &_vdw_px
                where ADATE between "01jan&ute_start_year"d and "31dec&ute_end_year"d;
        quit;

		proc sort data=px_temp1; by enc_id; run;

		data px_temp2(keep=patient_num encounter_num px px_CodeType adate mrn);
		merge px_temp1(in=a) numberthem(in=b);
		by enc_id;
		if a;
		run;

        %fuzz_date_var(inds=px_temp2,
                       outds=px_fuzzed);

        proc sql; %*Four types of procedures per V2 spec;
            insert into &for_load(PATIENT_NUM, encounter_num, CONCEPT_CD, START_DATE)
            select PATIENT_NUM,
			       encounter_num,
                   (case px_CodeType
                        when 'C4' then compress('PXCPT4:' || PX)
                        when 'H4' then compress('PXHCPC4:' || PX)
                        when 'RV' then compress('PXREV:' || PX)
                        when 'LO' then compress('PXLOC:' || PX)
                        when '09' then compress('PXICD09:' || PX)
                        else compress('??CodeType=' || px_CodeType || ':' || PX)
                    end),
                   FUZZED_ADATE
            from px_fuzzed;

            drop table px_fuzzed;
        quit;
    %end;
%mend px_data;
%px_data;

/*****************************************************************************************
******************************************************************************************
PREPARE LABS DATA FOR LOADING 
*******************************************************************************************
******************************************************************************************/

%macro lab_data;
    %if &lab_load_flag EQ 1 %then %do;
        proc sql;
            create table lab_temp1 (label='A record per lab test code per date per person') as
                select distinct MRN, test_type, abn_ind, coalesce(result_dt,lab_dt) as adate
                from &_vdw_lab
                where lab_dt between "01jan&ute_start_year"d and "31dec&ute_end_year"d;
        quit;

        %fuzz_date_var(inds=lab_temp1,
                       outds=lab_fuzzed);

        proc sql; %*There are only ICD-9 diagnosis codes so far;
            insert into &for_load(PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
            select PATIENT_NUM,
			        0,
                   compress('LAB:'||test_type||':'||abn_ind ),
                   FUZZED_ADATE
            from lab_fuzzed;

            drop table dx_fuzzed;
        quit;
    %end;
%mend lab_data;

%lab_data;

/******************************************************************************
*******************************************************************************
    PREPARE PHARMACY UTILIZATION DATA FOR LOADING
*******************************************************************************
******************************************************************************/
%macro rx_data;
    %if &rx_load_flag EQ 1 %then %do;
        proc sql;
            create table rx_temp1 (label='A record per NDC per date per person') as
                select distinct MRN, NDC, RXDATE as ADATE
                from &_vdw_rx
                where RXDATE between "01jan&ute_start_year"d and "31dec&ute_end_year"d;

            create table rx_temp2 (label='A record per RXCUI per date per person') as
                select distinct a.MRN, b.rxn_RXCUI as RXCUI, a.ADATE
                from rx_temp1 a inner join &_vdw_rxcui b
                on a.NDC=b.NDC
                where b.rxn_RXCUI NE ''; %*May lose records here if no NDC in RXCUI lookup table;

            drop table rx_temp1;
        quit;

        %fuzz_date_var(inds=rx_temp2,
                       outds=rx_fuzzed);

        proc sql; %*One type of concept code for pharmacy;
            insert into &for_load(PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
            select PATIENT_NUM,
			        0,
                   compress('RXCUI:' || RXCUI),
                   FUZZED_ADATE
            from rx_fuzzed;

            drop table rx_fuzzed;
        quit;
    %end;
%mend rx_data;
%rx_data;

/******************************************************************************
*******************************************************************************
    PREPARE BODY MASS INDEX (BMI) DATA FOR LOADING
*******************************************************************************
******************************************************************************/
%macro bmi_data;
    %if &bmi_load_flag EQ 1 %then %do;
        proc format;
            value bmicdf   0-16.4='<16.5'
                        16.5-18.4='16.5-18.4'
                        18.5-24.9='18.5-24.9'
                        25.0-30.0='25-30'
                        30.1-34.9='30.1-34.9'
                        35.0-40.0='35-40'
                        40.1-high='>40';
        run;

        proc sql;
            create table bmi_temp1 (label='A record per BMI code per date per person') as
                select distinct MRN, put(BMI,bmicdf.) as bmi_code length=15, measure_date as ADATE
                from &_vdw_vitalsigns
                where measure_date between "01jan&ute_start_year"d and "31dec&ute_end_year"d
                      and BMI NE .;
        quit;

        %fuzz_date_var(inds=bmi_temp1,
                       outds=bmi_fuzzed);

        proc sql; %*One type of concept code for BMI.;
            insert into &for_load(PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
            select PATIENT_NUM,
			       0,
                   compress('BMI:' || bmi_code),
                   FUZZED_ADATE
            from bmi_fuzzed;

            drop table bmi_fuzzed;
        quit;
    %end;
%mend bmi_data;
%bmi_data;

/******************************************************************************
*******************************************************************************
    PREPARE TUMOR/CANCER DATA FOR LOADING
*******************************************************************************
******************************************************************************/





%macro tumor_data;
    %if &tumor_load_flag EQ 1 %then %do;
        proc format;
            value $F400D
              'C000' - 'C009' = "C000-C009 Lip"
              'C010' - 'C019' = "C010-C019 Base of tongue"
              'C020' - 'C029' = "C020-C029 Other parts of tongue"
              'C030' - 'C039' = "C030-C039 Gum"
              'C040' - 'C049' = "C040-C049 Floor of mouth"
              'C050' - 'C059' = "C050-C059 Palate"
              'C060' - 'C069' = "C060-C069 Other parts of mouth"
              'C070' - 'C079' = "C070-C079 Parotid gland"
              'C080' - 'C089' = "C080-C089 Other salivary glands"
              'C090' - 'C099' = "C090-C099 Tonsil"
              'C100' - 'C109' = "C100-C109 Oropharynx"
              'C110' - 'C119' = "C110-C119 Nasopharynx"
              'C120' - 'C129' = "C120-C129 Pyriform sinus"
              'C130' - 'C139' = "C130-C139 Hypopharynx"
              'C140' - 'C149' = "C140-C149 Other lip, oral cavity and pharynx"
              'C150' - 'C159' = "C150-C159 Oesophagus"
              'C160' - 'C169' = "C160-C169 Stomach"
              'C170' - 'C179' = "C170-C179 Small intestine"
              'C180' - 'C189' = "C180-C189 Colon"
              'C190' - 'C199' = "C190-C199 Rectosigmoid junction"
              'C200' - 'C209' = "C200-C209 Rectum"
              'C210' - 'C219' = "C210-C219 Anus and anal canal"
              'C220' - 'C229' = "C220-C229 Liver and intrahepatic bile ducts"
              'C230' - 'C239' = "C230-C239 Gallbladder"
              'C240' - 'C249' = "C240-C249 Other biliary tract"
              'C250' - 'C259' = "C250-C259 Pancreas"
              'C260' - 'C269' = "C260-C269 Other digestive organs"
              'C300' - 'C309' = "C300-C309 Nasal cavity and middle ear"
              'C310' - 'C319' = "C310-C319 Accessory sinuses"
              'C320' - 'C329' = "C320-C329 Larynx"
              'C330' - 'C339' = "C330-C339 Trachea"
              'C340' - 'C349' = "C340-C349 Bronchus and lung"
              'C370' - 'C379' = "C370-C379 Thymus"
              'C380' - 'C389' = "C380-C389 Heart, mediastinum and pleura"
              'C390' - 'C399' = "C390-C399 Other respiratory and intrathoracic organs"
              'C400' - 'C409' = "C400-C409 Bone and articular cartilage of limbs"
              'C410' - 'C419' = "C410-C419 Other bone and articular cartilage"
              'C420' - 'C429' = "C420-C429 Hematopoietic and reticuloendothelial systems"
              'C440' - 'C449' = "C440-C449 Other malignant neoplasms of skin"
              'C470' - 'C479' = "C470-C479 Peripheral nerves and autonomic nervous system"
              'C480' - 'C489' = "C480-C489 Retroperitoneum and peritoneum"
              'C490' - 'C499' = "C490-C499 Other connective and soft tissue"
              'C500' - 'C509' = "C500-C509 Breast"
              'C510' - 'C519' = "C510-C519 Vulva"
              'C520' - 'C529' = "C520-C529 Vagina"
              'C530' - 'C539' = "C530-C539 Cervix uteri"
              'C540' - 'C549' = "C540-C549 Corpus uteri"
              'C550' - 'C559' = "C550-C559 Uterus, part unspecified"
              'C560' - 'C569' = "C560-C569 Ovary"
              'C570' - 'C579' = "C570-C579 Other and unspecified female genital organs"
              'C580' - 'C589' = "C580-C589 Placenta"
              'C600' - 'C609' = "C600-C609 Penis"
              'C610' - 'C619' = "C610-C619 Prostate"
              'C620' - 'C629' = "C620-C629 Testis"
              'C630' - 'C639' = "C630-C639 Other and unspecified male genital organs"
              'C640' - 'C649' = "C640-C649 Kidney, except renal pelvis"
              'C650' - 'C659' = "C650-C659 Renal pelvis"
              'C660' - 'C669' = "C660-C669 Ureter"
              'C670' - 'C679' = "C670-C679 Bladder"
              'C680' - 'C689' = "C680-C689 Other and unspecified urinary organs"
              'C690' - 'C699' = "C690-C699 Eye and adnexa"
              'C700' - 'C709' = "C700-C709 Meninges"
              'C710' - 'C719' = "C710-C719 Brain"
              'C720' - 'C729' = "C720-C729 Spinal cord, cranial nerves and other CNS"
              'C730' - 'C739' = "C730-C739 Thyroid gland"
              'C740' - 'C749' = "C740-C749 Adrenal gland"
              'C750' - 'C759' = "C750-C759 Other endocrine glands and related structures"
              'C760' - 'C769' = "C760-C769 Other and ill-defined sites"
              'C770' - 'C779' = "C770-C779 Secondary neoplasm of lymph nodes"
              'C800' - 'C809' = "C800-C809 Neoplasm without specification of site"
              ;
            run;

        proc sql;
            create table tumor_temp1 (label='A record per formatted site/stage per date per person') as
                select distinct MRN, trim(compress((scan(put(icdosite, $F400D.),1,'-')||"S"||stageaj))) as tumor_code, dxdate as ADATE 
                from &_vdw_tumor
                where dxdate between "01jan&ute_start_year"d and "31dec&ute_end_year"d;
        quit;





        %fuzz_date_var(inds=tumor_temp1,
                       outds=tumor_fuzzed);



        proc sql; %*One type of concept code for tumors;
            insert into &for_load(PATIENT_NUM,encounter_num, CONCEPT_CD, START_DATE)
            select PATIENT_NUM,
			       0,
                   compress('TUMOR:' || tumor_code),
                   FUZZED_ADATE
            from tumor_fuzzed;

            drop table tumor_fuzzed;
        quit;
    %end;
%mend tumor_data;
%tumor_data;

/******************************************************************************
*******************************************************************************
    INCLUDE THE PLUGIN FILE WHICH CAUSES AD HOC CODE THERE TO EXECUTE
*******************************************************************************
******************************************************************************/
%include "&program_directory.vdw_to_i2b2_step1_plugin_code.sas" / source2;

/******************************************************************************
*******************************************************************************
    REMOVE PEOPLE WITH NO UTILIZATION FACTS (ONLY DEMOGRAPHIC)
*******************************************************************************
******************************************************************************/
%macro remove_no_ute_peeps;
    %if &remove_people_with_dem_only EQ 1 %then %do;
        proc sql;
            create table people_in_dem (label='List of people having demographic facts') as
                select distinct PATIENT_NUM
                from &for_load
                where substr(CONCEPT_CD,1,3)='DEM';
        quit;
        proc sql;
            create table people_in_not_dem (label='List of people have non-demographic facts') as
                select distinct PATIENT_NUM
                from &for_load
                where substr(CONCEPT_CD,1,3) NE 'DEM';
        quit;
        proc sql;
            create table people_only_in_dem (label='List of people having ONLY demographic facts') as
                select a.PATIENT_NUM
                from people_in_dem a left join people_in_not_dem b
                on a.PATIENT_NUM=b.PATIENT_NUM
                where b.PATIENT_NUM is null;

            drop table people_in_dem, people_in_not_dem;
        quit;
        proc datasets lib=sasout nolist;
            delete for_i2b2_load_including_dem_only; %*In case it already exists, delete this file so change line doesnt fail;
            change for_i2b2_load=for_i2b2_load_including_dem_only;
        quit;
        %*A create table is used instead of delete because SAS proc sql deletes are mind-numbingly slow.;
        proc sql;
            create table &for_load as
                select *
                from sasout.for_i2b2_load_including_dem_only
                where PATIENT_NUM not in (select PATIENT_NUM from people_only_in_dem);

            drop table people_only_in_dem /*, sasout.for_i2b2_load_including_dem_only */;
        quit;
    %end;
%mend remove_no_ute_peeps;
%remove_no_ute_peeps;

/******************************************************************************
*******************************************************************************
    DO SOME SIMPLE QUALITY CHECKS/FIXES
*******************************************************************************
******************************************************************************/
%macro simple_qa;
    %*Remove fact records that happened before birth year or after death year.;
    proc datasets lib=sasout nolist;
        delete for_i2b2_load_before_simple_qa; %*In case it already exists, delete this file so change line doesnt fail;
        change for_i2b2_load=for_i2b2_load_before_simple_qa;
    quit;
    proc sql; %*This use of compress removes all characters not in the 2nd argument list (case-insensitive).;
        create table &for_load as
            select a.PATIENT_NUM,
			       a.encounter_num,
                   a.CONCEPT_CD,
                   a.START_DATE,
				   a.Nval_Num,
		           a.Tval_Char,
		           a.ValType_Cd 

            from sasout.for_i2b2_load_before_simple_qa a inner join demographics2 b
            on a.PATIENT_NUM=b.PATIENT_NUM
            where year(a.START_DATE) >= year(b.Birth_Date) and
                  year(a.START_DATE) <= year(coalesce(b.Death_Date,"&sysdate"d));

        drop table sasout.for_i2b2_load_before_simple_qa;
    quit;

    %*Also, make sure there are no absolute duplicates in the fact dataset;
    proc sort nodupkey data=&for_load dupout=duplicates;
        by PATIENT_NUM encounter_num CONCEPT_CD START_DATE;
    run;
    proc sql noprint;
        select count(*) into :n_duplicates from duplicates;
    quit;
    %put TEST: ANY DUPLICATES IN THE FACT DATASET?;
    %if &n_duplicates NE 0 %then %do;
        %put %sysfunc(compress(ER ROR)): &n_duplicates REMOVED FROM THE FACTS DATASET!!;
        title 'Duplicates (by PATIENT_NUM CONCEPT_CD START_DATE)!!!';
        proc freq data=duplicates;
            tables CONCEPT_CD START_DATE;
        run;
        title;
        proc datasets nolist;  delete duplicates;  quit;
    %end;
%mend simple_qa;
%simple_qa;

/******************************************************************************
*******************************************************************************
    SUMMARIZE SAS DATASET
*******************************************************************************
******************************************************************************/
%macro summarize;
    title 'FINAL SAS FILE';
    proc contents data=&for_load;  run;
    proc format;
        value $prefix
            'DEM|AGEASOF|0000'-'DEM|AGEASOF|9999'='DEM|AGEASOF|yyyy:*'
            'DEM|SEX:f'-'DEM|SEX:u'='DEM|SEX:*'
            'DEM|VITALASOF|0000'-'DEM|VITALASOF|9999'='DEM|VITALASOF|yyyy:*'
            'BMI:16.5-18.4'-'BMI:>40'='BMI:*'
            'TUMOR:C000'-'TUMOR:C999'='TUMOR:*'
            'PXCPT4:00000'-'PXCPT4:99999'='PXCPT:*'
            'PXHCPC4:A0000'-'PXHCPC4:Z9999'='PXHCPC4:*'
            'DXICD09:000'-'DXICD09:V99.99'='DXICD09:*'
            'PXICD09:00'-'PXICD09:99.99'='PXICD09:*'
            'PXREV:0'-'PXREV:9999'='PXREV:*'
            'RXCUI:0'-'RXCUI:999999'='RXCUI:*'
            'NAACCR|0|0'-'NAACCR|9999|999999999'='NAACCR:*'
;
			
    run;

    proc freq data=&for_load;
        tables START_DATE CONCEPT_CD;
        tables START_DATE * CONCEPT_CD / norow nocol nopercent;
        format START_DATE year4. CONCEPT_CD $prefix.;
    run;

	proc freq data=&for_load;
	tables concept_cd;
	run;

%mend summarize;
*%summarize;

%put FYI: FINISHED; *Write a note to log showing that this program is finished;

*If this program ran as an rsubmitted block of code, your enrsubmit/signoff code;
*goes here.  It will simply cause an inconsequential error otherwise.;


/*
endrsubmit; *Comment this out if not rsubmitted to a SAS server;
signoff GHRIDWIP; *Comment this out if not rsubmitted to a SAS server;


*/
