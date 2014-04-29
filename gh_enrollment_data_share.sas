%macro gh_enrollment_data;
    %*Make IGP and NETWORK year-specific enrollment facts for i2b2.;

    libname vdw 'crn_vdw' access=readonly;

    proc sql;
        %*Make an IGP only view of enrollment using probably_denominator_safe=1;
        create view igp as
            select *
            from vdw.enroll_with_type_with_ewa_vw
            where probably_denominator_safe=1;

        %*Make a Network (not IGP) only view of enrollment using probably_denominator_safe=0;
        create view network as
            select *
            from vdw.enroll_with_type_with_ewa_vw
            where probably_denominator_safe=0;
    quit;

    %*Prepare caselist of all people in the demographic file.;
    data enrollment_caselist;
        set &_vdw_demographic (keep=MRN);
    run;

    %*For each year, make list of all people continuously enrolled that year (2 month gaps allowed).;
    %do yr = &ute_start_year %to &ute_end_year;
        %*For each year, make list of all people continuously enrolled in IGP that year (2 month gaps allowed).;
        %PullContinuous(enrollment_caselist   /*case list*/
                      , igp_&yr        /*outfile*/
                      , "01jan&yr"d    /*index date*/
                      , 0              /*no enrollment required before index date*/
                      , 0              /*this arg does not apply since not requiring pre-index date enrollment*/
                      , 12             /*12 months of enrollment required after index date*/
                      , 2              /*allowing for 2-month gaps at most*/
                      , EnrollDset = igp);

        %*For each year, make list of all people continuously enrolled in the network that year (2 month gaps allowed).;
        %PullContinuous(enrollment_caselist   /*case list*/
                      , network_&yr    /*outfile*/
                      , "01jan&yr"d    /*index date*/
                      , 0              /*no enrollment required before index date*/
                      , 0              /*this arg does not apply since not requiring pre-index date enrollment*/
                      , 12             /*12 months of enrollment required after index date*/
                      , 2              /*allowing for 2-month gaps at most*/
                      , EnrollDset = network);
    %end;

    proc datasets nolist;  delete enrollment_caselist;  quit;

    %do yr = &ute_start_year %to &ute_end_year;
        proc sql;
            create table dupes_igp_&yr as
                select MRN, count(*) as Freq
                from igp_&yr
                group by MRN
                having count(*)>1;

            create table dupes_network_&yr as
                select MRN, count(*) as Freq
                from network_&yr
                group by MRN
                having count(*)>1;
        quit;

        proc sql; %*Insert facts for each year-specific IGP enrolled person;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select distinct b.PATIENT_NUM,
			        0,
                   compress("ENRIGP|&yr:y"),
                   "01jan&yr"d
            from igp_&yr a inner join patient_mapping b
            on a.MRN=b.MRN;

            drop table igp_&yr;
        quit;
        proc sql; %*Insert facts for each year-specific network enrolled person;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select distinct b.PATIENT_NUM,
			        0,
                   compress("ENRNETWORK|&yr:y"),
                   "01jan&yr"d
            from network_&yr a inner join patient_mapping b
            on a.MRN=b.MRN;

            drop table network_&yr;
        quit;
    %end;

    proc format;
        value $enrfmt 'ENRIGP|0000:y'-'ENRIGP|9999:y'='ENRIGP*'
                      'ENRNETWORK|0000:y'-'ENRNETWORK|9999:y'='ENRNETWORK*'
                      other='NON-ENROLL FACTS';
    run;

    title 'Look at enrollment plugin facts';
    proc freq data=&for_load;
        tables CONCEPT_CD START_DATE;
        where CONCEPT_CD in: ('ENRIGP','ENRNETWORK');
    run;
    proc freq data=&for_load;
        tables START_DATE * CONCEPT_CD / norow nocol nopercent;
        format CONCEPT_CD $enrfmt. START_DATE year4.;
    run;

    title;
%mend gh_enrollment_data;
%gh_enrollment_data;

