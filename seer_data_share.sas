%macro seer_data;
    %*Make IGP and NETWORK year-specific enrollment facts for i2b2.;

    libname vdw 'CRN_VDW' access=readonly;
 

    proc sql;
        %*Create seer table;
        create table seer as
            select mrn, enr_start, enr_end
            from vdw.enroll2
            where in_seer_area='Y';

        create table unkseer as 
		 select mrn, enr_start, enr_end
		 from vdw.enroll2
		 where in_seer_area='U';

		 create table noseer as 
		 select mrn, enr_start, enr_end
		 from vdw.enroll2
		 where in_seer_area='N';
     
    quit;

    %*Prepare caselist of all people in the demographic file.;
    data enrollment_caselist;
        set &_vdw_demographic (keep=MRN);
    run;

    %*For each year, make list of all people continuously enrolled that year (2 month gaps allowed).;
    %do yr = &ute_start_year %to &ute_end_year;
        %*For each year, make list of all people continuously enrolled in IGP that year (2 month gaps allowed).;
        %PullContinuous(enrollment_caselist   /*case list*/
                      , seer_&yr        /*outfile*/
                      , "01jan&yr"d    /*index date*/
                      , 0              /*no enrollment required before index date*/
                      , 0              /*this arg does not apply since not requiring pre-index date enrollment*/
                      , 12             /*12 months of enrollment required after index date*/
                      , 2              /*allowing for 2-month gaps at most*/
                      , EnrollDset = seer);

	  %PullContinuous(enrollment_caselist   /*case list*/
                      , unkseer_&yr        /*outfile*/
                      , "01jan&yr"d    /*index date*/
                      , 0              /*no enrollment required before index date*/
                      , 0              /*this arg does not apply since not requiring pre-index date enrollment*/
                      , 12             /*12 months of enrollment required after index date*/
                      , 2              /*allowing for 2-month gaps at most*/
                      , EnrollDset = unkseer);

		  %PullContinuous(enrollment_caselist   /*case list*/
                      , noseer_&yr        /*outfile*/
                      , "01jan&yr"d    /*index date*/
                      , 0              /*no enrollment required before index date*/
                      , 0              /*this arg does not apply since not requiring pre-index date enrollment*/
                      , 12             /*12 months of enrollment required after index date*/
                      , 2              /*allowing for 2-month gaps at most*/
                      , EnrollDset = noseer);

     
      %end;

    proc datasets nolist;  delete enrollment_caselist;  quit;

    %do yr = &ute_start_year %to &ute_end_year;
        proc sql;
            create table dupes_seer_&yr as
                select MRN, count(*) as Freq
                from seer_&yr
                group by MRN
                having count(*)>1;

			  create table dupes_unkseer_&yr as
                select MRN, count(*) as Freq
                from unkseer_&yr
                group by MRN
                having count(*)>1;

			  create table dupes_noseer_&yr as
                select MRN, count(*) as Freq
                from noseer_&yr
                group by MRN
                having count(*)>1;


		quit;
       

        proc sql; %*Insert facts for each year-specific SEER enrolled person;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select distinct b.PATIENT_NUM,
			        0,
                   compress("SEER|&yr:y"),
                   "01jan&yr"d
            from seer_&yr a inner join patient_mapping b
            on a.MRN=b.MRN;

            drop table seer_&yr;
        quit;


	     proc sql; %*Insert facts for each year-specific SEER enrolled person;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select distinct b.PATIENT_NUM,
			       0,
                   compress("SEER|&yr:u"),
                   "01jan&yr"d
            from unkseer_&yr a inner join patient_mapping b
            on a.MRN=b.MRN;

            drop table unkseer_&yr;

		 proc sql; %*Insert facts for each year-specific SEER enrolled person;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select distinct b.PATIENT_NUM,
			       0,
                   compress("SEER|&yr:n"),
                   "01jan&yr"d
            from noseer_&yr a inner join patient_mapping b
            on a.MRN=b.MRN;

            drop table noseer_&yr;


        quit;

       
    %end;

    proc format;
        value $enrfmt 'SEER|0000:y'-'SEER|9999:y'='SEER*'
                     
                      other='NON-SEER FACTS';
    run;

    title 'Look at enrollment plugin facts';
    proc freq data=&for_load;
        tables CONCEPT_CD START_DATE;
        where CONCEPT_CD in: ('SEER');
    run;
    proc freq data=&for_load;
        tables START_DATE * CONCEPT_CD / norow nocol nopercent;
        format CONCEPT_CD $enrfmt. START_DATE year4.;
    run;

    title;
%mend seer_data;

%seer_data;

