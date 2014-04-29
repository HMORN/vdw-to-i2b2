/*
CODE IN THIS FILE IS OPTIONAL.  WHATEVER IS SET TO RUN HERE WILL RUN AFTER ALL THE OTHER
FACTS ARE GENERATED BUT BEFORE CLEANING OCCURS.  TO GENERATE AD HOC FACTS, SWAP OUT MRN FOR
PATIENT_NUM USING THE PATIENT_MAPPING WORK DIR FILE OR USE THE fuzz_date_var MACRO.  THE
CONCEPT_CD VALUES SHOULD BE 30 CHARS AT MOST AND THE DATES SHOULD BE FUZZED OR YEARLY (USE
JANUARY 1ST OF YEAR IF YEARLY).

VARIABLES AND DATA STRUCTURES YOU CAN COUNT ON USING (CREATED IN THE MAIN PROGRAM) ARE:

    - WORK.PATIENT_MAPPING DATASET - VARS ARE MRN, PATIENT_NUM, and date_fuzz_factor
    - for_load - MACRO VARIABLE POINTINT TO THE OUTPUT DATASET INTO WHICH FACTS SHOULD BE
                 INSERTED - VARS ARE PATIENT_NUM, CONCEPT_CD, AND START_DATE
    - ute_start_year AND _ute_end_year - MACRO VARS CONTAINING THE UTILIZATION TIME PERIOD BOUNDS

PLEASE NOTE THAT IF YOU WRAP YOUR CODE IN A MACRO (RECOMMENDED TO EASE TURNING IT ON AND OFF),
YOU MUST INVOKE THE MACRO IN THIS FILE AS WELL AS DECLARING IT.
*/

/*
This is sample code showing how one might add yearly continuous enrollment facts allowing for
2-month gaps in enrollment.  It uses the PullContinuous standard macro so the code is pretty
simple.  Macro invocation is commented out by default.  Intended as example code only.
*/
%macro enrollment_data;
    %*Prepare caselist of all people in the demographic file.;
    data enrollment_caselist;
        set &_vdw_demographic (keep=MRN);
    run;

    %*For each year, make list of all people continuously enrolled that year (2 month gaps allowed).;
    %do yr = &ute_start_year %to &ute_end_year;
        %PullContinuous(enrollment_caselist /*case list*/
                      , enrolled_&yr /*outfile - contains only MRN if person was enrolled*/
                      , "01jan&yr"d  /*index date*/
                      , 0            /*no enrollment required before index date*/
                      , 0            /*this arg does not apply since not requiring pre-index date enrollment*/
                      , 12           /*12 months of enrollment required after index date*/
                      , 2            /*allowing for 2-month gaps at most*/
                      , EnrollDset = &_vdw_enroll /*use the VDW enroll file to get enrollment data*/);
    %end;

    proc datasets nolist;  delete enrollment_caselist;  quit;

    %do yr = &ute_start_year %to &ute_end_year;
        proc sql; %*Insert a fact for each year-specific enrolled person;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select b.PATIENT_NUM,
			                 0,
                   compress("ENR|&yr:y"),
                   "01jan&yr"d
            from enrolled_&yr a inner join patient_mapping b
            on a.MRN=b.MRN;

            drop table enrolled_&yr;
        quit;
    %end;
%mend enrollment_data;


%enrollment_data;

%include '\gh_enrollment_data.sas' / source2;



%include '\seer_data.sas' / source2;


%include '\naaccr_data_v2.sas' / source2; 

%include '\mom_baby.sas' /source2;

%include '\disease_cohorts.sas' /source2;
