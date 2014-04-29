/*Disease Cohort Fact Module */




libname getdc 'Define Cohorts' access=readonly;


%macro disease_cohorts;

/* Double check unique by date*/



proc sort data=getdc.conditioncohorts out=from_dcs nodupkey;
by mrn theyear cohorttype;
run;




%do yr = &ute_start_year %to &ute_end_year;
        

data thisyear;
set from_dcs;
if theyear=&yr;
dte=mdy('01','01',theyear);
run;




        proc sql; %*Insert facts for each year-specific IGP enrolled person;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select distinct b.PATIENT_NUM,
			       0,
                   compress("DC:"||cohorttype),
                   dte
            from thisyear a inner join patient_mapping b
            on a.MRN=b.MRN;
        quit;
    
%end;

%mend;

%disease_cohorts;
