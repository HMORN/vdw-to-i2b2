/*
Program: vdw_to_i2b2_step2_vdw_export_to_csv.sas
Date: 9/24/2010
Author: David Eastman, Group Health Research Institute
Purpose: Convert extracted SAS data into CSV (comma delimited) text
         file format.  CSV data can be readily bulk inserted into MSSQL.
         After this program runs, move the CSV or (yearly CSVs) to a local
         hard drive of the i2b2 MSSQL database server and then edit and run
         the vdw_to_i2b2_step3_load_i2b2_mssql.sql T-SQL script.
*/

/******************************************************************************
*******************************************************************************
    BEGIN EDIT SECTION
*******************************************************************************
******************************************************************************/
*If you do a remote submit to a SAS server, rsubmit/signon code goes here;





%make_spm_comment(sasload to csv );


*Change the next line to point to a library where the SAS output should be directed.;
%let sasout=d:\; 

/* %let sasout=\\ghrisas\warehouse\management\offlinedata\i2b2;*/

*If your data is "really large" you may want to make CSV data in yearly chunks;
*so set this next parameter to 1.  Otherwise, set it to 0 to make one CSV file.;
*I highly recommend trying one comprehensive file.  It makes for less manual;
*labor and easier bulk inserts in the T-SQL script.;
%let make_yearly_chunks=1;
/******************************************************************************
*******************************************************************************
    END EDIT SECTION
*******************************************************************************
*******************************************************************************
    DO NOT EDIT BELOW HERE
*******************************************************************************
******************************************************************************/

options nocenter msglevel=i mprint errorabend;

libname sasout "&sasout";

%let for_load=sasout.for_i2b2_load;



/******************************************************************************
*******************************************************************************
    EXPORT DATA TO CSV FILE(S)
*******************************************************************************
******************************************************************************/
*Convert the SAS data set created by the step 1 program into CSV format either;
*as one file or yearly files (based on year of START_DATE).  Using the BULK   ;
*INSERT command on the CSV file(s) is an efficient means of loading data      ;
*into MSSQL.  The replace option is used to automatically overwrite prior     ;
*versions of the CSV files if they exist.;


/*
data check_encnum;
set &for_load;
if encounter_num=.;
run;*/



%macro export_to_csv;
    proc sql;
        create view faked_out_i2b2_struct as
            select /*distinct*/ Encounter_Num length=8 /*Encounter_Num cannot be null in i2b2*/
                  ,Patient_Num
                  ,compress(CONCEPT_CD,'0123456789abcdefghijklmnopqrstuvwxyz.:|<>-','ki') as CONCEPT_CD length=30
                  ,'@' as Provider_Id length=1 /*Provider_Id cannot be null in i2b2 -- use dummy value*/
                  ,Start_Date
                  ,'@' as Modifier_Cd length=100 /*Modifier_Cd cannot be null in i2b2 -- use dummy value*/
				  ,1 as INSTANCE_NUM length=3
                  , valtype_cd as ValType_Cd length=50
                  ,tval_char as TVal_Char length=255
                  ,nVal_num as NVal_Num length=5
                  ,'' as ValueFlag_Cd length=1
                  ,'' as Quantity_Num length=1
                  ,'' as Units_Cd length=1
                  ,'' as End_Date length=1
                  ,'' as Location_Cd length=1
                  ,'' as Observation_Blob length=1
                  ,'' as Confidence_Num length=1
                  ,'' as Update_Date length=1
                  ,'' as Download_Date length=1
                  ,'' as Import_Date length=1
                  ,'@' as  Sourcesystem_Cd length=50
                  ,'' as UPLOAD_ID length=1
				  , 1 as test_search_index
            from &for_load;
    quit;

    %if &make_yearly_chunks EQ 1 %then %do;
        proc sql noprint;
            select year(min(START_DATE)), year(max(START_DATE))
            into :lb, :ub
            from faked_out_i2b2_struct;
        quit;
        %put FYI: START_DATE YEAR RANGE IS &lb TO &ub;
        data %do yyyy = &lb %to &ub;
                 temp_&yyyy (label="subset of data for year &yyyy")
             %end; ;
            set faked_out_i2b2_struct;
            select(year(START_DATE));
                %do yyyy=&lb %to &ub;
                    when(&yyyy) output temp_&yyyy;
                %end;
            end;
        run;
        %do yyyy = &lb %to &ub;
            proc export data=temp_&yyyy
                        outfile="&sasout\for_i2b2_load_&yyyy..csv"
                        dbms=CSV replace;
            run;
            proc datasets nolist;  delete temp_&yyyy;  quit;
        %end;
    %end;
    %else %do; %*Make one file, NOT yearly chunks;
        proc export data=faked_out_i2b2_struct
                    outfile="&sasout\for_i2b2_load.csv"
                    dbms=CSV replace;
        run;
    %end;
%mend export_to_csv;

%export_to_csv; *Execute the macro;


%put FYI: FINISHED; *Write a note to log showing that this program is finished;

*If this program ran as an rsubmitted block of code, your enrsubmit/signoff code;
*goes here.  It will simply cause an inconsequential error otherwise.;

/*
endrsubmit;
signoff GHRIDWIP;

*/
