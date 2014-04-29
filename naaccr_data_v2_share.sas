/* NAACCR MODULE*/
/* Dustin Key 2011 */
/* Group Health Research Institute*/
/* key.d@ghc.org  206-287-2916 */
/* Module declares multiple macros which are executed at the very end of this code.*/
/* This module is part of a master program that goes through various subject areas such as Dx, Px, Rx, Labs, etc. 
 and creates the facts for i2b2.  The master program previous declares the following entities: 

 
 &ute_start_year   Begin time frame of data declared in master program
 &ute_end_year;   End time frame of data declared in master program
 naaccr_v12     SAS dataset of tumors in NAACCR format
%fuzz_date_var  Macro that fuzzes adates +/- 60 days, almost ranuni.
devspace.getranges  SAS file that contains which levels of which SSF vars are continous ranges. 
 &for_load      Table declared in the master program which is the running collection of all facts across subject areas         
           

/* Program Contents and Flow*/
/* 
   Declare 
           CSV2_Schema_Map (map site/histology to a schema number)
           Makedate                (manage tumor diangosis date)
           Facts                   (handle 'regular' facts, not site-specific, no range variables)
           Site Facts              (handle site-specific facts)
					+uses CSV2 Schema Map
           Date Facts              (handle date facts that have no subcategories-just leaf node right click vars)
           Staging Facts           (handle staging factors.  different from above b/c of storage to stage formats)

   Process NAACCR 
           Loop year by year between ute_start and ute_end years

           Sub looping for each of these four % modules via NAACCR item.  Just add or delete item 
          numbers that don't appply .  Looks for _item number_ in var names within NAACCR dataset.

            %facts;  Output naaccr_temp

			%site_facts; Output naaccr_temp_site

            %facts_w_dates; Output naaccr_temp_dates

            %staging_facts Output naaccr_temp_stage;

         Slight formating: code value as n when the level is in a continous range

         Fuzz adates 
 
         Load appropriate NAACCR facts:
          
              naaccr_temp to NAACCR|itemno:value   (most items)
                                value 'n' for ranges & nval_num populated
 
              naaccr_site to NAACCR|schemano:itemno:value
                            
                                value 'n' for ranges & nval_num populated
 
              naaccr_date to NAACCR|itemno
                                integer population of nval_num representing the year of the date

              naaccr_stage to NAACCR|itemno:value 
                                pretty much the same as naaccr_temp except specific staging formatting applied.
    
   End Comments
*/

   


libname cancer 'Naaccr' access=readonly;

/*This contains cancer-related formats:  Staging, Variable Item Number, Cancer Site Mapping (SiteCat)*/

%include 'cancer ontology formats.sas';
 
/*CSV2 Schema Map*/
/* Macro maps tumor cases to numeric schema numbers based on Collaborative Staging System Version 2. */
/* Schema is a function of anatomic site (item 400), Histology (item 522), and sometimes Site Specifc Factor 25, which is
also known as the schema discrimenator. */

/* Someday redesign approach here.*/

%macro csv2_schema_map(inds,outds);

data &outds;
set &inds;
hist2=histologic_type_icd_O_3_522*1;

if SiteCat='AdnexaUterineOther' and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >=9700 and hist2 <= 9701)) then schemano=1;

if SiteCat='AdrenalGland' and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >=9700 and hist2 <= 9701)) then schemano=2;

if SiteCat='AmpullaVater' and ( (hist2 >= 8000 and hist2<=8152)or (hist2 >=8154 and hist2 <=8231)
or (hist2 >=8243 and hist2 <=8245) or (hist2 >= 8247 and hist2 <= 8248) or (hist2 >= 8250 and hist2 <=9136) or
( hist2 >=9141 and hist2 <= 9582) or (hist2 >= 9700 and hist2 <= 9701) ) then schemano=3;

if SiteCat='Anus' and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >=9700 and hist2 <= 9701)) then schemano=4;

if SiteCat='Appendix' and ( (hist2 >= 8000 and hist2 <=8152) or (hist2 >=8154 and hist2 <=8231)
or (hist2 >=8243 and hist2 <=8245) or hist2=8247 or hist2=8248 or (hist2 >=8250 and hist2 <=8576)
or (hist2 >=8940 and hist2 <=8950) and (hist2>= 8980 and hist2 <=8981) ) then schemano=5;

if SiteCat in ('BileDuctsDistal','BileDuctsPerihilar','CysticDuct') and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >=9700 and hist2 <= 9701)) and
cs_site_specific_factor25_2879 in ('040','070') then schemano=6;

if SiteCat in ('BileDuctsDistal','BileDuctsPerihilar','CysticDuct') and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >=9700 and hist2 <= 9701)) and
cs_site_specific_factor25_2879 in ('010','020','050','060','100','999') then schemano=8;

if SiteCat in ('BileDuctsDistal','BileDuctsPerihilar','CysticDuct') and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >=9700 and hist2 <= 9701)) and
cs_site_specific_factor25_2879 ='030' then schemano=24;

/*BileDuctsIntraHepat*/
if primary_site_400 in ('C221','C220') and ( hist2 in (8160,8161,8180) ) then schmano=7;

if SiteCat='BiliaryOther' and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >=9700 and hist2 <= 9701)) 
then schemano=9;

if SiteCat='Bladder' and ( (hist2 >=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <= 8981)) 
then schemano=10;

if SiteCat='Bone' and ( (hist2 >=8800 and hist2 <=9136) or (hist2 >=9142 and hist2 <=9582) ) 
then schemano=11;

if SiteCat='Brain' and ( hist2=8000 or (hist2 >=8680 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) ) 
then schemano=12;

if SiteCat='Breast' and ( (hist2 >=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <= 8981) or hist2=9020) 
then schemano=13;

if SiteCat='BuccalMucosa' and ( (hist2 >=8000 and hist2 <=8576) or ( hist2 >= 8940 and hist2 <=8950)
or (hist2 >=8980 and hist2 <=8981) ) then schemano=14;

if SiteCat='CarcinoidAppendix' and ( hist2=8153 or (hist2 >= 8240 and hist2 <=8242) or hist2= 8246 or hist2= 8249) then
schemano=15;

if SiteCat='Cervix' and ( (hist2 >=8000 or hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <=8981))
then schemano=16;

if SiteCat='CNSOther' and ( hist2=8000 or (hist2 >=8680 or hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) )
then schemano=17;

if SiteCat='Colon' and ( (hist2 >= 8000 and hist2 <=8152) or (hist2 >=8154 and hist2 <=8231)
or (hist2 >=8243 and hist2 <=8245) or hist2=8247 or hist2=8248 or (hist2 >=8250 and hist2 <=8576)
or (hist2 >=8940 and hist2 <=8950) or (hist2>= 8980 and hist2 <= 8981) ) then schemano=18;
/* and corrected on Feb 2 2012 */

if SiteCat='Conjunctiva' and ( (hist2 >=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950)
or (hist2 >=8980 and hist2 <=8981) ) then schemano=20;

if SiteCat='CorpusAdenosarcoma' and hist2=8933 then schemano=21;

if SiteCat='CorpusCariconma' and ( (hist2>=8000 and hist2 <=8790) or (hist2 >= 8980 and hist2 <=8981) or (hist2 >= 9700 and hist2 <=9701)) then schemano=22;

if SiteCat='CoprusSarcoma' and ( (hist2 >=8890 and hist2 <=8898) or (hist2 >=8930 and hist2 <=8931)
 ) then schemano=23;


if SiteCat='DigestiveOther' and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >= 9141 and hist2 <=9582) or 
(hist2 >=9700 and hist2 <= 9701) ) then schemano=25;

if SiteCat='EndocrineOther' and ( (hist2 >=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >= 9700 and hist2 <= 9701))
then schemano=26;

if SiteCat='EpiglottisAnterior' and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
 or (hist2 >=8980 and hist2 <= 8981) ) then schemano=27;

 if SiteCat='Esophagus' and (  (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
 or (hist2 >=8980 and hist2 <= 8981) ) then schemano=28;

if primary_site_400 in ("C160","C161", "C162") and ( (hist2 >=8000 and hist2 <=8152)
or (hist2 >=8154 and hist2 <=8231) or (hist2 >= 8243 and hist2 <=8245) or hist2=8247 or hist2=8248 or 
(hist2 >=8250 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <=8981) )
and cs_site_specific_factor25_2879 in ('010','020','040','060') then schemano=29;

if SiteCat="EyeOther" and ( (hist2 >=8000 and hist2 <=8713) or (hist2 >= 8800 and hist2 <=9136)
or (hist2 >=9141 and hist2 <=9508) or (hist2 >=9520 and hist2 <=9582) or (hist2 >=9700 and hist2 <=9701) ) then schemano=30;

if SiteCat="FallopianTube" and ( (hist2>=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <=8981) )
then schemano=31;

if SiteCat="FloorMouth" and (  (hist2>=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <=8981) ) then schemano=32;

if SiteCat="Gallbladder" and ( (hist2>=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >= 9700 and hist2 <=9701) )
then schemano=33;

if SiteCat="GenitalFemaleOther" and ( (hist2>=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >= 9700 and hist2 <=9701) )
then schemano=34;

if SiteCat="GentialMaleOther" and ( (hist2>=8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) or (hist2 >= 9700 and hist2 <=9701) )
then schemano=35;

if SiteCat="GISTAppendix" and (hist2 >=8935 and hist2 <=8936) then schemano=36;


if SiteCat="GISTColon" and (hist2 >=8935 and hist2 <=8936) then schemano=37;


if SiteCat="GISTEsophagus" and (hist2 >=8935 and hist2 <=8936) then schemano=38;


if SiteCat="GISTPeritoneum" and (hist2 >=8935 and hist2 <=8936) then schemano=39;


if SiteCat="GISTRectum" and (hist2 >=8935 and hist2 <=8936) then schemano=40;


if SiteCat="GISTSmallIntestine" and (hist2 >=8935 and hist2 <=8936) then schemano=41;

if SiteCat="GISTStomach" and (hist2 >=8935 and hist2 <=8936) then schemano=42;

if SiteCat="GumLower" and (( hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950) or 
(hist2 >=8980 and hist2 <=8981) ) then schemano=43;

if SiteCat="GumOther" and (( hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950) or 
(hist2 >=8980 and hist2 <=8981) ) then schemano=44;

if SiteCat="GumUpper" and (( hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950) or 
(hist2 >=8980 and hist2 <=8981) ) then schemano=45;

if SiteCat="HeartMediastinum" and ((hist2 >= 8800 and hist2 <=8936) or (hist2 >= 8940 and hist2 <= 9136) or 
(hist2 >= 9141 and hist2 <=9582) ) then schemano=46;

if (hemeretic1="HemeRetic1" or hemeretic2="HemeRetic2" or hemeretic3="HemeRetic3")  and 
(( hist2 >= 9731 and hist2 <=9734) or (hist2 >= 9740 and hist2 <=9742)
or (hist2 >= 9750 and hist2 <= 9758) or (hist2 >= 9760 and hist2 <=9762) or 
(hist2 >= 9764 and hist2 <= 9769) or (hist2 >= 9800 and hist2 <= 9801) or hist2=9805 
or hist2=9820 or hist2=9826 or (hist2 >= 9831 and hist2 <=9837) or hist2=9840 or (hist2 >=9860 and hist2 <=9861)
or hist2=9863 or (hist2 >= 9866 and hist2 <= 9867) or (hist2 >= 9870 and hist2 <=9876)
or hist2=9891 or (hist2 >= 9895 and hist2 <= 9897) or hist2=9910 or hist2=9920 or (hist2 >= 9930 and hist2 <=9931)
or hist2=9940 or (hist2 >= 9945 and hist2 <= 9946) or hist2=9948 or hist2=9950 or (hist2 >= 9960 and hist2 <=9964)
or hist2=9970 or hist2=9975 or hist2=9980 or (hist2 >=9982 and hist2 <=9987) or hist2=9989 ) then schemano=47;


if SiteCat="Hypopharynx" and (( hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or 
(hist2 >= 8980 and hist2 <=8981)) then schemano=48;

if SiteCat="IllDefinedOther" and ((hist2 >= 8000 and hist2 <=9136) or (hist2 >= 9141 and hist2 <=9582)
or (hist2 >= 9700 and hist2 <= 9701)) then schemano=49;

if SiteCat="IntracranialGland" and ((hist2 >= 8000 and hist2 <=9136) or (hist2 >= 9141 and hist2 <=9582)
or (hist2 >= 9700 and hist2 <= 9701)) then schemano=50;

if SiteCat="KaposiSarcoma" and hist2=9140 then schemano=51;

if SiteCat="KidneyParenchyma" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981)) then schemano=52;

if SiteCat="KidneyRenalPelvis" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then schemano=53;

if primary_site_400="C69.5" and (( hist2 >= 8000 and hist2 <=8576) or ( hist2 >= 8940 and hist2 <=8950) or 
(hist2 >= 8980 and hist2 <=8981) ) and 
cs_site_specific_factor25_2879 in ('010','100') then schemano=54;

if primary_site_400="C69.5" and ( ( hist2 >= 8000 and hist2 <=8576) or ( hist2 >= 8940 and hist2 <=8950) or 
(hist2 >= 8980 and hist2 <=8981) ) and 
cs_site_specific_factor25_2879= '020' then schemano=55;

if SiteCat="LarynxGlottic" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then 
schemano=56;

if SiteCat="LarynOther" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then
schemano=57;

if SiteCat="LarynxSubglottic" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then
schemano=58;

if SiteCat="LarynxSuperglottic" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then
schemano=59;

if SiteCat="LipLower" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) )  then
schemano=60;

if SiteCat="LipOther" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then
schemano=61;


if SiteCat="LipUpper" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then
schemano=62;

if primary_site_400 in ("C220","C221") and (( hist2 >=8170 and hist2 <= 8175)) then schemano=63;

if SiteCat="Lung" and ( (hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981) ) then schemano=64;

if (lymphoma1="Lymphoma1" or lymphoma2="Lymphoma2") and (( hist2 >= 9590 and hist2 <=9699) or (hist2 >= 9702 and hist2 <=9729) or (hist2 in ( 9735, 9737, 9738)))
then schemano=65;

if SiteCat="LymphomaOcularAdnexa" and (( hist2 >=9590 and hist2 <=9699) or (hist2 >= 9702 and hist2 <=9738)
or (hist2 >=9811 and hist2 <=9818) or (hist2 >= 9820 and hist2 <= 9837) )then schemano=66;

if SiteCat="BuccalMucosa" and (hist2 >=8720 and hist2 <= 8790) then schemano=67;

if primary_site_400="C693" and (hist2 >=8720 and hist2 <= 8790) then schemano=68;

if primary_site_400="C694" and (hist2 >= 8720 and hist2 <= 8790) and cs_site_specific_factor25_2879
in ('010','100') then schemano=69;

if primary_site_400="C690" and (hist2 >= 8720 and hist2 <= 8790) then schemano=70;

if primary_site_400="C101" and (hist2 >= 8720 and hist2 <= 8790) then schemano=71;

if SiteCat="EyeOther" and (hist2 >= 8720 and hist2 <= 8790) then schemano=72;

if SiteCat="FloorMouth" and (hist2 >= 8720 and hist2 <= 8790) then schemano=73;

if SiteCat="GumLower" and (hist2 >= 8720 and hist2 <= 8790) then schemano=74;

if SiteCat="GumOther" and (hist2 >= 8720 and hist2 <= 8790) then schemano=75;

if SiteCat="GumUppper" and (hist2 >= 8720 and hist2 <= 8790) then schemano=76;

if SiteCat="Hypopharynx" and (hist2 >= 8720 and hist2 <= 8790) then schemano=77;

if primary_site_400="C694" and (hist2 >= 8720 and hist2 <= 8790) then schemano=78;

if primary_site_400="C320" and (hist2 >= 8720 and hist2 <= 8790) then schemano=79;

if SiteCat="LarynxOther" and (hist2 >= 8720 and hist2 <= 8790) then schemano=80;


if SiteCat="LarynxSubglottic" and (hist2 >=8720 and hist2 <=8790) then schemano=81;

if SiteCat="LarynxSupraglottic" and (hist2 >=8720 and hist2 <=8790) then schemano=82;

if SiteCat="LipLower" and (hist2 >=8720 and hist2 <=8790) then schemano=83;

if SiteCat="LipOther" and (hist2 >=8720 and hist2 <=8790) then schemano=84;

if SiteCat="LipUpper" and (hist2 >=8720 and hist2 <=8790) then schemano=85;

if SiteCat="MouthOther" and (hist2 >=8720 and hist2 <=8790) then schemano=86;

if SiteCat="NasalCavity" and (hist2 >=8720 and hist2 <=8790) then schemano=87;

if SiteCat="Nasopharynx" and (hist2 >=8720 and hist2 <=8790) then schemano=88;

if SiteCat="Oropharynx" and (hist2 >=8720 and hist2 <=8790) then schemano=89;

if SiteCat="PalateHard" and (hist2 >=8720 and hist2 <=8790) then schemano=90;

if SiteCat="PalateSoft" and (hist2 >=8720 and hist2 <=8790) then schemano=91;

if SiteCat="PharynxOther" and (hist2 >=8720 and hist2 <=8790) then schemano=92;

if SiteCat="SinusEthmoid" and (hist2 >=8720 and hist2 <=8790) then schemano=93;

if SiteCat="SinusMaxillary" and (hist2 >=8720 and hist2 <=8790) then schemano=94;

if SiteCat="SinusOther" and (hist2 >=8720 and hist2 <=8790) then schemano=95;

if SiteCat="Skin" and (hist2 >=8720 and hist2 <=8790) then schemano=96;

if SiteCat="TongueAnterior" and (hist2 >=8720 and hist2 <=8790) then schemano=97;

if SiteCat="TongueBase" and (hist2 >=8720 and hist2 <=8790) then schemano=98;

if SiteCat="Penis" and hist2=8247 then schemano=99;

if SiteCat="Scrotum" and hist2=8247 then schemano=100;

if SiteCat="Skin" and hist2=8247 then schemano=101;

if SiteCat="Vulva" and hist2=8247 then schemano=102;

if SiteCat="MiddleEar" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <=8981)) then schemano=103;

if SiteCat="MouthOther" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <=8981)) then schemano=104;

if fungoides1="MycosisFungoides" and (hist2 >=9700 and hist2 <=9701) then schemano=105;

if myelmoma1="MyelomaPlasmaCellDisorder" and ((hist2 >= 9731 and hist2 <=9732) or (hist2= 9734)) then schemano=106;

if SiteCat="NasalCavity" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <=8981)
or (hist2 >=9700 and hist2 <=9701)) then schemano=107;

if SiteCat="Nasopharynx" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <=8981)
or (hist2 >=9700 and hist2 <=9701)) and cs_site_specific_factor25_2879 in ('010','100',' ') then schemano=108;

if primary_site_400='C241' and ((hist2=8153) or (hist2 >= 8240 and hist2 <= 8242) or hist2 in( 8246, 8249)) then schemano=109;

if SiteCat="Colon" and ((hist2=8153) or (hist2 >= 8240 and hist2 <= 8242) or hist2 in( 8246, 8249)) then schemano=110;

if SiteCat="Rectum" and ((hist2=8153) or (hist2 >= 8240 and hist2 <= 8242) or hist2 in( 8246, 8249)) then schemano=111;

if SiteCat="SmallInterstine" and ((hist2=8153) or (hist2 >= 8240 and hist2 <= 8242) or hist2 in( 8246, 8249)) then schemano=112;

if SiteCat="Stomach" and  ((hist2=8153) or (hist2 >= 8240 and hist2 <= 8242) or hist2 in( 8246, 8249)) then schemano=113;

if SiteCat="Orbit" and ((hist2 >=8000 and hist2 <=9136) or (hist2 >= 9141 and hist2 <=9508) or (hist2 >= 9520 and hist2 <=9582) 
or (hist2 >= 9700 and hist2 <= 9701)) then schemano=114;

if SiteCat="Oropharynx" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950) or (hist2 >= 8980 and hist2 <=8981) 
) then schemano=115;

if SiteCat="Ovary" and (( hist2>=8000 and hist2 <=8576) or (hist2 >= 8590 and hist2 <=8671) or (hist2 >=8930 and hist2 <=9110)) then 
schemano=116;

if SiteCat="PalateHard" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <=8981)
) then schemano=117;

if SiteCat="PalateSoft" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or (hist2 >=8980 and hist2 <=8981)
)  then schemano=118;

if SiteCat="PancreasBodyTail" and ((hist2 >= 8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) and (hist2 >=9700 and hist2 <=9701))
then schemano=119;

if SiteCat="PancreasHead" and ((hist2 >= 8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) and (hist2 >=9700 and hist2 <=9701))
then schemano=120;

if SiteCat="PancreasOther" and ((hist2 >= 8000 and hist2 <=9136) or (hist2 >=9141 and hist2 <=9582) and (hist2 >=9700 and hist2 <=9701))
then schemano=121;

if SiteCat="ParotidGland" and ((hist2 >= 8000 and hist2 <=9576) or (hist2 >=8940 and hist2 <=8950) and (hist2 >=8980 and hist2 <=9701))
then schemano=122;

if SiteCat="Penis" and (( hist2 >=8000 and hist2 <=8246) or (hist2 >=8248 and hist2 <=8576) or (hist2 >=8940 and hist2 <=8950)
or (hist2 >=8980 and hist2 <= 8981)or hist2=9020) then schemano=123;

if SiteCat="Peritoneum" and (( hist2 >=8800 and hist2 <=8921) or (hist2 >= 8940 and hist2 <=9055)
or (hist2 >=9120 and hist2 <=9136) or (hist2 >= 9141 and hist2 <=9582) ) and cs_site_specific_factor25_2879 in 
('001','003','004','009','100',' ') then schemano=124;

if SiteCat="Peritoneum" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >= 8590 and hist2 <=8671) or
(hist2 >= 8930 and hist2 <=8934) or (hist2 >=8940 and hist2 <=9110) ) and cs_site_specific_factor25_2879='002' then schemano=125;

if primary_site_400='C111' and (( hist2 >=8000 and hist2 <= 8576) or (hist2 >= 8940 and hist2 <=8950) or 
 (hist2 >= 8980 and hist2 <= 8981)) and cs_site_specific_factor25_2879='020' then 
 schemano=126;

if SiteCat="PharynxOther" and (( hist2 >=8000 and hist2 <=8713) or (hist2 >=8800 and hist2 <=9136) and (hist2 >= 9141 and hist2 <=9582)
or(hist2>=9700 and hist2 <=9701)) then schemano=127;

if SiteCat="Placenta" and ( ( hist2 >= 9100 and hist2 <= 9105) )
then schemano=128;

if SiteCat="Pleura" and (( hist2 >= 9050 and hist2 <= 9052) )
then schemano=129;

if SiteCat="Prostate" and (( hist2 >= 8000 and hist2 <=8110) or (hist2 >= 8140 and hist2 <=8576) or (hist2 >=8940 and hist2 <= 8950) 
or (hist2 >= 8980 and hist2 <=8981 ))
then schemano=130;

if SiteCat="Rectum" and ((hist2 >= 8000 and hist2 <=8152) or (hist2 >= 8154 and hist2 <=8231)
or (hist2 >=8243 and hist2 <=8245) or (hist2 =8247) or (hist2 =8248)
or (hist2 >= 8250 and hist2 <= 8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <=8981) ) then schemano=131;

if SiteCat="RespiratoryOther" and ((hist2 >= 8000 and hist2 <=9136) or (hist2 >= 9141 and hist2 <= 9582)
or (hist2 >=9700 and hist2 <=9701)) then schemano=132;

if retinoblastoma1="Retinoblastoma" and (( hist2 >= 9510 and hist2 <=9514)) then schemano=133;

if primary_site_400='C480' and (( hist2 >= 8000 and hist2 <=8921) or 
(hist2 >= 8940 and hist2 <=9136) or ( hist2 >= 9141 and hist2 <=9582)) then schemano=134;

if SiteCat="SalivaryGlandOther" and ((hist2 >=8000 and hist2 <=8576) or ( hist2 >= 8940 and hist2 <=8950) or ( hist2 >= 8980 and 
hist2 <= 8981)) then schemano=135;

if SiteCat="Scrotum" and ((hist2 >= 8000 and hist2 <= 8246) or (hist2 >= 8248 and hist2 <=8576) 
or (hist2 >= 8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <=8981)) then schemano=136;

if SiteCat="SinusEthmoid" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950) or 
(hist2 >= 8980 and hist2 <= 8981)) then schemano=137;

if SiteCat="SinusMaxillary" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950) or 
(hist2 >= 8980 and hist2 <= 8981) ) then schemano=138;

if SiteCat="SinusOther" and ((hist2 >= 8000 and hist2 <= 8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >=8980 and 
hist2 <= 8981) ) then schemano=139;

if SiteCat="Skin" and ((hist2 >= 8000 and hist2 <= 8246) or (hist2 >= 8248 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950)
or (hist2 >= 8980 and hist2 <=8981)) then schemano=140;

if SiteCat="SkinEyelid" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >=8940 and hist2 <= 8950) or 
(hist2 >= 8980 and hist2 <=8981) ) then schemano=141;

if SiteCat="SmallIntestine" and (( hist2 >= 8000 and hist2 <= 8152) or (hist2 >= 8154 and hist2 <=8231)
or (hist2 >= 8243 and hist2 <= 8245) or (hist2 in (8247,8248)) or (hist2 >= 8250 and hist2 <= 8576) or 
( hist2 >= 8940 and hist2 <= 8950) or (hist2 >= 8980 and hist2 <= 8981)) then schemano=142;

if SiteCat="SoftTissue=" and ((hist2 >=8800 and hist2 <=8936) or (hist2 >= 8940 and hist2 <=9136) or (hist2 >= 9141 and hist2 <=9582))
then schemano=143;

if primary_site_400 in ("C161","C162","C163","C164","C165","C166","C168","C169") and (( hist2 >= 8000 and hist2 <=8152)
or (hist2 >=8154 and hist2 <=8231) or (hist2 >=8243 and hist2 <=8245) or ( hist2 in (8247,8248)) or 
(hist2 >= 8250 and hist2 <= 8576) or (hist2 >=8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <=8990) ) then schemano=144;

if primary_site_400="C080" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or 
(hist2 >= 8980 and hist2 <=8981)) then schemano=145;

if SiteCat="Testis" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8590 and hist2 <=8593) or 
(hist2 >= 8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <= 8981) or (hist2 >=9060 and hist2 <=9090) or 
 (hist2 >= 9100 and hist2 <=9105) ) then schemano=146;

if SiteCat="Thyroid" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or 
(hist2 >= 8980 and hist2 <=8981)) then schemano=147;


if SiteCat="TongueAnterior" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950) or
(hist2 >=8980 and hist2 <=8981)) then schemano=148;

if SiteCat="TongueBase" and ((hist2 >=8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <= 8950) or
(hist2 >=8980 and hist2 <=8981) ) then schemano=149;

if SiteCat="Trachea" and (( hist2 >= 8000 and hist2 <=9136) or (hist2 >= 9141 and hist2 <= 9582) 
or (hist2 >= 9700 and hist2 <=9701)) then schemano=150;

if SiteCat="Urethra" and (( hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <=8981)) then schemano=151;

if SiteCat="UrinaryOther" and (( hist2 >= 8000 and hist2 <=9136) or (hist2 >= 9141 and hist2 <=9582)
or (hist2 >= 9700 and hist2 <=9701)) then schemano=152;

if SiteCat="Vagina" and ((hist2 >= 8000 and hist2 <=8576) or (hist2 >= 8800 and hist2 <=8801)
or (hist2 >= 8940 and hist2 <=8950) or (hist2 >= 8980 and hist2 <=8981) ) then schemano=153;

if SiteCat="Vulva" and (( hist2 >= 8000 and hist2 <=8246) or (hist2 >=8248 and hist2 <=8576) or ( hist2 >= 8940 and hist2 <=8950)
or (hist2 >= 8980 and hist2 <= 8981)) then schemano=154; 

run;



%mend csv2_schema_map;



%macro makedate(outvar,invar);
  *This macro reads in a NAACCR date var which is text MMDDYYYY and converts
   the var to a numeric. It also creates the label, format, and imputes
   values for missing months and days;
  *Invar is  date var
   Outvar is the name of the numeric var you want to create;

  %let impvar = &outvar._imputed;

  length &outvar.  4
         &impvar   3
         _mo _da  $2
         _yr      $4
    ;
  format &outvar. date9.;
  label &outvar = "SASDATE for &invar";
  label &impvar = "Imputation flag &outvar: 1 is day, 2 is month, 3 is both";

  &impvar=0;

  * Month;
  _mo = substr(&invar,1,2);
  if _mo = '99' then do;
    _mo = '06';
    &impvar=&impvar+2;
  end;
  * Day;
  _da = substr(&invar,3,2);
  if _da = '99' then do;
    _da = '15';
    &impvar=&impvar+1;
  end;
  * Year;
  _yr = substr(&invar,5,4);
  if _yr NOT IN ('9999', '0000') then do;
     if _mo='11' and _da='31' then _da='30'; 
     &outvar = mdy(input(_mo,2.),input(_da,2.),input(_yr,4.));
  end;
  else do;
  	 &outvar = .;
  end;

  drop _mo _da _yr;
%mend makedate;


/* The dslist below contains NAACCR items for the non site-specfic facts which you want to map to i2b2. */


%macro facts;

%let dslist=90,150,160,190, 220,380,400,410,440,444,446,490,
500,501,521,522,523,605,610,630,668,670,672,674,676,
690,700,710,720,730,740,746,747,748,759,780,790,800,810,820,830,870,880,890,900,
910,930,940,950,960,970,980,990,1060,1292,1294,1296,1320, 1340,1350,1360,1370,1380,
1390,1400,1410,1420,1430,1460,1500,
1639,1760,1770,1780,1790,1910,1920,2180, 
3000,3010,3020,3030,3040,3050,3250,3270,3280,3310,3430,3440,3450,3460,3470,3480,3482,3490,3492,3600,7480;


%let i=1;

%do %until ( (%scan((&dslist),&i) < 1)  or (&i>200) );


%let ds_loop=%scan((&dslist),&i);


proc sql;
create table varlist as 
  select *
    from dictionary.columns
where libname='CANCER' and memname='NAACCR_V12' 
	; 
quit;

data varlist2;
set varlist;
format naaccr_no $4.;
naaccr_no=scan(name,-1,"_");
if naaccr_no="&ds_loop";
call symput('namevar',name);
run;



proc sql;
create table naaccr_temp&i (label='A record per marital status per naaccr row per person') as
                select distinct chsid as mrn, encounter_num, &namevar  as naaccr_code length=10 informat $10., dxdate as ADATE, &ds_loop as naaccr_var 
                from cancer
               ;

%if &i=1 %then %do;
data naaccr_temp;
set naaccr_temp1;
informat naaccr_code $10.;
run;
%let i=%eval(&i+1);

	%end;

  %else %do;

  proc append data=naaccr_temp&i base=naaccr_temp ; run;

%let i=%eval(&i+1);

  %end;

%end;

%mend facts;


%macro site_facts;

%let dslist=1290,2861,2862,2863,2864,2865,2866,2867,2868,2869,2870,2871,2872,2873,2874,2875,2876,2877,2878,2879
2880, 2890, 2900, 2910, 2920,2930, 2810 /*CS EXT*/, 2830 /*CS Lymph Nodes*/, 2840 /*CS Lymph Nodes Eval*/,
2850 /*CS METS at DX*/, 2860 /*CS METS at Eval*/, 830, 820, 2800 /*Tumor Size*/;

%let i=1;

%do %until ( (%scan((&dslist),&i) < 1)  or (&i>200) );
%let ds_loop=%scan((&dslist),&i);


proc sql;
create table varlist as 
  select *
    from dictionary.columns
where libname='CANCER' and memname='NAACCR_V12' 
	; 
quit;

data varlist2;
set varlist;
format naaccr_no $4.;
naaccr_no=scan(name,-1,"_");
if naaccr_no="&ds_loop";
call symput('namevar',name);
run;

/*Ancilary anatomic site helper formats used to combine site numbers into schema determining useful blocks*/

data labelstuff;
set cancer;
SiteCat=put(primary_site_400,$site7b.);
hemeretic1=put(primary_site_400,$hlping1b.);
hemeretic2=put(primary_site_400,$hlping2b.);
hemeretic3=put(primary_site_400,$hlping3b.);
lymphoma1=put(primary_site_400,$hlping4b.);
lymphoma2=put(primary_site_400,$hlping5b.);
fungoides1=put(primary_site_400,$hlping6b.);
myelmoma1=put(primary_site_400,$hlping7b.);
retinoblastoma1=put(primary_site_400,$hlping8b.);
surgsite=put(primary_site_400,$surgsite.);
fordsite=put(surgsite,$fordsite.);
run;

/*Employ mapping to schema for site-specific factors*/

%csv2_schema_map(labelstuff,labelstuff2);





proc sql;
create table naaccr_temp_sites&i (label='A record per marital status per naaccr row per person') as
                select distinct chsid as mrn,encounter_num, &namevar  as naaccr_code length=10 informat $10., dxdate as ADATE, &ds_loop as naaccr_var ,
               primary_site_400, schemano, fordsite
                from labelstuff2
                ;

	

%if &i=1 %then %do;
data naaccr_temp_sites;
set naaccr_temp_sites1;
informat naaccr_code $10.;
run;
%let i=%eval(&i+1);

	%end;

  %else %do;

  proc append data=naaccr_temp_sites&i base=naaccr_temp_sites ; run;

%let i=%eval(&i+1);

  %end;

%end;



%mend site_facts;


%macro facts_w_dates;


%let dslist=230,390,443,445,580,590,600, 678, 1080,1200,1210,1220,1230,1240,1250,1260,
1750,2090,2110,2111,2190; 



%let i=1;

%do %until ( (%scan((&dslist),&i) < 1)  or (&i>200) );


%let ds_loop=%scan((&dslist),&i);


proc sql;
  create table varlist as 
  select *
    from dictionary.columns
where libname='CANCER' and memname='NAACCR_V12' 
	; 
quit;

data varlist2;
set varlist;
format naaccr_no $4.;
naaccr_no=scan(name,-1,"_");
if naaccr_no="&ds_loop";
call symput('namevar',name);
run;


data naaccrdate;
format theyear 4.;
set cancer(keep=&namevar dxdate chsid encounter_num );
namevar2=substr(&namevar,1,4);
theyear=namevar2*1;
run;



proc sql;
create table naaccr_temp&i (label='A record per marital status per naaccr row per person') as
                select distinct chsid as mrn, encounter_num, theyear as naaccr_code , dxdate as ADATE, &ds_loop as naaccr_var
				
 
                from naaccrdate
                ;

%if &i=1 %then %do;
data naaccr_temp_dates;
set naaccr_temp1;
			run;
%let i=%eval(&i+1);

	%end;

  %else %do;
  proc append data=naaccr_temp&i base=naaccr_temp_dates ; run;

%let i=%eval(&i+1);

%end;

%end;


%mend facts_w_dates;


%macro staging_facts;


proc sql;
create table naaccr_temp_staging_facts (label='A record per marital status per naaccr row per person') as
                select distinct chsid as mrn,encounter_num, compress(put(composite_ajcc, $cmp_aj.))  as naaccr_code length=10 informat $10., dxdate as ADATE, '0000' as naaccr_var,
               primary_site_400
                from cancer;
run;

proc sql;
create table staging_facts_der6t as
 select distinct chsid as mrn,encounter_num, compress(put(derived_ajcc_6_t_2940, $store_to_stage_t.))  as naaccr_code length=10 informat $10., dxdate as ADATE, '2940' as naaccr_var,
               primary_site_400
                from cancer;
run;

proc sql;
create table staging_facts_der7t as
 select distinct chsid as mrn,encounter_num, compress(put(derived_ajcc_7_t_3400, $store_to_stage_t.))  as naaccr_code length=10 informat $10., dxdate as ADATE, '3400' as naaccr_var,
               primary_site_400
                from cancer;
run;


proc sql;
create table staging_facts_der6n as
 select distinct chsid as mrn,encounter_num, compress(put(derived_ajcc_6_n_2960, $store_to_stage_n.))  as naaccr_code length=10 informat $10., dxdate as ADATE, '2960' as naaccr_var,
               primary_site_400
                from cancer;
run;

proc sql;
create table staging_facts_der7n as
 select distinct chsid as mrn,encounter_num, compress(put(derived_ajcc_7_n_3410, $store_to_stage_n.))  as naaccr_code length=10 informat $10., dxdate as ADATE, '3410' as naaccr_var,
               primary_site_400
                from cancer;
run;


proc sql;
create table staging_facts_der6m as
 select distinct chsid as mrn,encounter_num, compress(put(derived_ajcc_6_m_2980, $store_to_stage_m.))  as naaccr_code length=10 informat $10., dxdate as ADATE, '2980' as naaccr_var,
               primary_site_400
                from cancer;
run;

proc sql;
create table staging_facts_der7m as
 select distinct chsid as mrn,encounter_num, compress(put(derived_ajcc_7_m_3420, $store_to_stage_m.))  as naaccr_code length=10 informat $10., dxdate as ADATE, '3420' as naaccr_var,
               primary_site_400
                from cancer;
run;

                
%mend staging_facts;




%macro process_naaccr;



/*Loop year-by-year */


%macro assign_encs_tumor;



libname cancer 'Naaccr' access=readonly;

/*Loop year-by-year */


proc sort data=cancer.naaccr_v12 out=orderedcanc2 nodupkey; by chsid tumor_record_number_60 dxdate; run;


data numberthem_tumor(keep=encounter_num chsid tumor_record_number_60 dxdate);
set orderedcanc2;
encounter_num=_n_;
run;


%mend;



%assign_encs_tumor;



proc sort data=cancer.naaccr_v12 out=orderedcanc; by chsid tumor_record_number_60 dxdate; run;


data cancerb;
merge orderedcanc(in=a) numberthem_tumor(in=b);
by chsid tumor_record_number_60 dxdate;
if a;
run;





  %do yr = &ute_start_year %to &ute_end_year; 




 data cancer;
 set cancerb;
 if year(dxdate)=&yr;

 run;

%facts;

%site_facts;

%facts_w_dates;

%staging_facts;


data naaccr_temp_dates2;
set naaccr_temp_dates;
format  naaccr_var2 $4.;
naaccr_code2=naaccr_code;
naaccr_var2=naaccr_var;

run; 

libname devspace 'NAACCR Ontology Development\';


data getranges(drop=itemno);
format naaccr_var 4.;
set devspace.getranges;
if maxrange < minrange then delete;
rangeid=schemano||itemno;
naaccr_var=itemno*1;
run;

proc sort data=getranges ; by rangeid; run;

data rangerank;
set getranges;
by rangeid;
retain rangerank;
if first.rangeid then do;
     rangerank=1;end;
else do rangerank=rangerank+1; end;


run;

/* Only up to two continuous ranges per SSF */

data firstranges;
set rangerank;
if rangerank=1;
run;

data secondranges(rename=(minrange=minrange2 maxrange=maxrange2));
set rangerank;
if rangerank=2;
run;


proc sort data=firstranges; by naaccr_var schemano; run;
proc sort data=secondranges; by naaccr_var schemano; run;

/*Attach ranges to the regular facts*/

proc sort data=naaccr_temp; by naaccr_var; run;

data naaccr_temp_w_ranges;
merge naaccr_temp(in=a) firstranges(in=b) secondranges(in=c);
by naaccr_var;
if a;
run;


/* Code 'n' instead of the level when within a range*/

/*Right range is not inclusive currently.  Need to check this.*/

data naaccr_temp2;
set naaccr_temp_w_ranges;
format naaccr_code2 $10. naaccr_var2 $4. nval_num 4.;
naaccr_code2=input(naaccr_code,$10.);
naaccr_var2=naaccr_var;
val=naaccr_code*1;
nval_num=.;
if (val >=minrange and val <maxrange) or (val >=minrange2 and val <maxrange2) then do;
naaccr_code2='n';
nval_num=val;
end;
run;



/*Attach the ranges to the site facts */
proc sort data=naaccr_temp_sites; by naaccr_var schemano; run;



data naaccr_temp_sites_w_ranges;
merge naaccr_temp_sites(in=a) firstranges(in=b) secondranges(in=c);
by naaccr_var schemano;
if a;
run;



data naaccr_temp_sites2;
set naaccr_temp_sites_w_ranges;
format naaccr_code2 $10. naaccr_var2 $50. naaccr_code3 10.;
naaccr_code2=input(naaccr_code,$50.);
naaccr_var2=naaccr_var;
val=naaccr_code*1;
nval_num=.;
if (val >=minrange and val <maxrange) or (val >=minrange2 and val <maxrange2) then do;
naaccr_code2='n';
nval_num=val;
end;


concept=trim(compress("NAACCR|"||schemano||":"||naaccr_var2||":"||naaccr_code2));	

/*Fords surgery sites different*/ 
/*Need to check this one*/

if naaccr_var=1290 then do;
    concept=trim(compress("NAACCR|1290|FORDS:"||fordsite||"|C:"||naaccr_code2));
end;

run;


data naaccr_temp_staging_facts2;
set naaccr_temp_staging_facts
staging_facts_der6t
staging_facts_der7t
staging_facts_der6n
staging_facts_der7n
staging_facts_der6m
staging_facts_der7m;

format naaccr_code2 $10. naaccr_var2 $4.;
naaccr_code2=input(naaccr_code,$10.);
naaccr_var2=naaccr_var;
run;

/* Fuzz adates*/

%fuzz_date_var(inds=naaccr_temp2,
                       outds=naaccr_temp2_fuzzed);

%fuzz_date_var(inds=naaccr_temp_dates2,
                       outds=naaccr_temp_dates2_fuzzed);


%fuzz_date_var(inds=naaccr_temp_sites2, 
                       outds=naaccr_temp_sites2_fuzzed);

%fuzz_date_var(inds=naaccr_temp_staging_facts2, 
                       outds=naaccr_temp_staging_fuzzed);




		proc print data=naaccr_temp2_fuzzed(obs=50); run;


        proc sql; %*Insert facts for each dxyear, NAACCCR;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE, nval_num, tval_char, valtype_cd)
            select distinct PATIENT_NUM,
			       encounter_num,
                   compress("NAACCR|"||naaccr_var2||":"||naaccr_code2),
                   fuzzed_adate,
				   nval_num,
				   'E',
				   'N'
            from naaccr_temp2_fuzzed ;

            drop table naaccr_temp2;
        quit;



		proc sql; %*Insert facts for each dxyear, NAACCCR;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE, nval_num, tval_char, valtype_cd)
            select distinct PATIENT_NUM,
			       encounter_num,
                   compress("NAACCR|"||naaccr_var2),
                   fuzzed_adate,
				   naaccr_code2,
				   'E',
				   'N'


            from naaccr_temp_dates2_fuzzed ;
	

            drop table naaccr_temp_dates2;
        quit;


	/*These are the site specific facts.  Naaccr_code3 should be integer for value range searches. */

proc sql; %*Insert facts for each dxyear, NAACCCR;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE, nval_num, tval_char, valtype_cd)
            select distinct PATIENT_NUM,
			       encounter_num,
                   concept,
                   fuzzed_adate,
				   nval_num,
				   'E',
				   'N'
            from naaccr_temp_sites2_fuzzed ;

            drop table naaccr_temp_sites2;
        quit;

proc sql; %*Insert facts for each dxyear, NAACCCR;
            insert into &for_load(PATIENT_NUM,encounter_num,CONCEPT_CD,START_DATE)
            select distinct PATIENT_NUM,
			    encounter_num,
                compress("NAACCR|"||naaccr_var2||":"||naaccr_code2),
                   fuzzed_adate
            from naaccr_temp_staging_fuzzed ;

        quit;


%end;

%mend process_naaccr;


/*Executes program*/

%process_naaccr;




