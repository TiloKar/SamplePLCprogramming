FUNCTION_BLOCK statusStack
	IF size < MAXSIZE THEN //füllen
		stack[next]:=in;
		next:=next+1;
		size:=size+1;
		toString:='';
		FOR i:= 0 TO size-1 BY 1 DO
			hlpstr:='';
			brsitoa(stack[i],ADR(hlpstr));
			toString:=CONCAT(toString, hlpstr);
			toString:=CONCAT(toString, '-');
		END_FOR;	
		
	ELSE	//bei voller kapazität
		stack[next]:=in;
		next:=next+1;
		IF next > MAXSIZE THEN
			next:=0;
		END_IF;
		toString:='';
		FOR i:= next TO size BY 1 DO
			hlpstr:='';
			brsitoa(stack[i],ADR(hlpstr));
			toString:=CONCAT(toString, hlpstr);
			toString:=CONCAT(toString, '-');
		END_FOR;
		IF next > 0 THEN 
			FOR i:= 0 TO next-1 BY 1 DO
				hlpstr:='';
				brsitoa(stack[i],ADR(hlpstr));
				toString:=CONCAT(toString, hlpstr);
				toString:=CONCAT(toString, '-');
			END_FOR;
		END_IF;
	END_IF;	
	
	
END_FUNCTION_BLOCK
	
	

FUNCTION fLoadConfig
	dst.cCL:=src.cCL;  //alle reglereinstellungen sofort übernehmen
		
	FOR i:= 0 TO ncO BY 1 DO	//alle cO, nur nicht die stapelweise digitalventile anwenden
		CASE  info.cO[i].type OF
					
			0,12:		//leere kanäle, Stapelweise digitalventile
				//nix
			ELSE
						
				dst.cO[i]:=src.cO[i];	
		END_CASE;	
	END_FOR;	
	
	dst.cI:=src.cI;  //alle alarmeinstellungen für nutzeralarme sofort übernehmen
	fLoadConfig:=1;
END_FUNCTION





FUNCTION BITTST
	//Testet bit an zielposition durch anlegen einer 8 bit maske
	BITTST:=0;
	IF pIN <> 0 THEN
		targetBlock := (tstPos / 8); //zeiger offset ermitteln
		exponent:=tstPos - (targetBlock * 8);
		targetBlockMask := REAL_TO_USINT(2**exponent);	
		
		aIN ACCESS pIN + targetBlock;
		
		BITTST := (aIN AND targetBlockMask) > 0;
		
	END_IF;	

END_FUNCTION

FUNCTION BITCLR
	//setzt bit an zielposition durch anlegen einer 8 bit maske
	BITCLR:=0;
	IF pIN <> 0 THEN
		targetBlock := (setPos / 8); //zeiger offset ermitteln
		exponent:=setPos - (targetBlock * 8);
		targetBlockMask:=16#FF;
		targetBlockMask := targetBlockMask - REAL_TO_USINT(2**exponent);	
		
		aIN ACCESS pIN + targetBlock;
		aIN:= aIN AND targetBlockMask;
		BITCLR:=1;
	END_IF;	

END_FUNCTION


FUNCTION BITSET
	//setzt bit an zielposition durch anlegen einer 8 bit maske
	BITSET:=0;
	IF pIN <> 0 THEN
		targetBlock := (setPos / 8); //zeiger offset ermitteln
		exponent:=setPos - (targetBlock * 8);
		targetBlockMask := REAL_TO_USINT(2**exponent);	
		
		aIN ACCESS pIN + targetBlock;
		aIN:= aIN OR targetBlockMask;
		BITSET:=1;
	END_IF;	

END_FUNCTION

FUNCTION BITCNT
	//Zählt bits ab zeigeradresse in 32 bit portionen
	//maskierung der überzähligen bits im letzten block für kein genaues Vielfaches von 32
	BITCNT:=0;
	IF pIN <> 0 AND cntLen > 0 THEN
		lastBlock := (cntLen / 32); //anzahl der 4 byte blöcke ermitteln
		IF cntLen > (lastBlock * 32) THEN //falls cntLen kein genaues Vielfaches
			lastBlockMask:=16#FFFFFFFF;
			scount:=UDINT_TO_SINT(((lastBlock + 1) * 32) - cntLen);
			lastBlockMask:=SHR(lastBlockMask,scount);
		ELSIF cntLen = (lastBlock * 32) THEN //falls CntLen genau passt, alle bits des blocks zählen
			lastBlock:=lastBlock - 1;
			lastBlockMask:=	0;
		END_IF;
		
		FOR i:= 0 TO lastBlock BY 1 DO
			BITCNT32:=0;
			aIN ACCESS pIN + (i*4);
			IF lastBlockMask > 0 AND i=lastBlock THEN	//falls ungerades Vielfaches und letzter block, dann überzählige bits ignorieren
				v := aIN AND lastBlockMask;
			ELSE
				v:=aIN;
			END_IF;
			WHILE v > BITCNT32 DO
				BITCNT32:=BITCNT32+1;
				v:= v AND ( v - 1);
			END_WHILE
			BITCNT := BITCNT + UDINT_TO_USINT(BITCNT32);
		END_FOR;	
	 
	END_IF;	

	//	BITCNT1:=0;
	//	v:=IN[0];
	//	WHILE v > BITCNT1 DO
	//		BITCNT1:=BITCNT1+1;
	//		v:= v AND ( v - 1);
	//	END_WHILE
	//	
	//	BITCNT2:=0;
	//	v:=IN[1];
	//	WHILE v > BITCNT2 DO
	//		BITCNT2:=BITCNT2+1;
	//		v:= v AND ( v - 1);
	//	END_WHILE
	//	
	//	BITCNT:=UDINT_TO_USINT(BITCNT1 + BITCNT2);
	
END_FUNCTION


//checksummenberechnung CRC32/8 nach Castagnoli 1993
FUNCTION CRC32
	crc_input:=1;
	FOR n:=0 TO plen-1 BY 1 DO //exklusive checksumme
		IF pmem<>0 THEN
			mem ACCESS pmem + n;
			indata:=mem;
			FOR i:=0 TO 7 BY 1 DO
				IF(((crc_input AND 16#80000000)<>0)<>((indata AND 16#80) <>0)) THEN
					crc_input:=(SHL(crc_input,1))XOR(gen);
				ELSE
					crc_input:=SHL(crc_input,1);
				END_IF;
				indata:=SHL(indata,1);
			END_FOR;
		END_IF;
	END_FOR;
	CRC32:=crc_input;
END_FUNCTION



FUNCTION crcmodbus
	crc_input:=16#FFFF;
	IF pmem <> 0 AND plen > 0 AND plen < 255 THEN
		FOR n:=0 TO plen-1 BY 1 DO //exklusive checksumme
			mem ACCESS pmem+UINT_TO_UDINT(n);
			crc_input:=crc_input XOR mem;
			FOR i:=0 TO 7 BY 1 DO
				IF(crc_input AND 16#0001) <> 0 THEN
					crc_input:=(SHR(crc_input,1))XOR(16#A001);
				ELSE
					crc_input:=SHR(crc_input,1);
				END_IF;
			END_FOR;
		END_FOR;
	END_IF;
	crcmodbus:=crc_input;
END_FUNCTION
FUNCTION fFindLastNumber
//findet letzte zahl im string, - ascii 45 ist auch dabei
	fFindLastNumber:=0;
	IF pString <> 0 AND strlen > 0 THEN
		i:=0;
		WHILE i < strlen DO
			aChar ACCESS pString + strlen - i - 1;
			IF ((aChar > 47) AND (aChar < 58)) OR aChar = 46 THEN 
				fFindLastNumber:=strlen - i - 1; 
				i:=strlen;
			END_IF;
			i:=i+1;
		END_WHILE				
	END_IF;	
	
END_FUNCTION
FUNCTION fFindFirstNumber
//findet erste zahl im string
	fFindFirstNumber:=0;
	IF pString <> 0 AND strlen > 0 THEN
		i:=0;
		WHILE i < strlen DO
			aChar ACCESS pString + i;
			IF ((aChar > 47) AND (aChar < 58)) OR aChar = 46 THEN 
				fFindFirstNumber:=i;
				i:=strlen;
			END_IF;
			i:=i+1;
		END_WHILE			
	END_IF;	
	
END_FUNCTION
FUNCTION fReplaceChar
//ersetzt byteweise alles zeichen über den genannten speicherbereich
	fReplaceChar:=0;
	IF pString <> 0 AND strlen > 0 AND charOld > 0 AND charNew > 0 THEN
		fReplaceChar:=1;
		FOR i:= 0 TO strlen - 1 BY 1 DO
			aChar ACCESS pString + i;
			IF aChar = charOld THEN 
				aChar:=charNew;
			END_IF;
		END_FOR;	
	END_IF;	
	
END_FUNCTION

FUNCTION fFindLastChar
	//gibt letzte position eines zeichens im string zurück
// char 47 - slash "/"
	fFindLastChar:=0;
	IF pString <> 0 AND strlen > 0 THEN
		i:=0;
		WHILE i < strlen DO
			aChar ACCESS pString + strlen - i - 1;
			IF aChar = char THEN 
				fFindLastChar:=strlen - i; 
				i:=strlen;
			END_IF;
			i:=i+1;
		END_WHILE	
	END_IF;	
END_FUNCTION

FUNCTION fFindFirstChar
	//gibt letzte position eines zeichens im string zurück
// char 47 - slash "/"
	fFindFirstChar:=0;
	IF pString <> 0 AND strlen > 0 THEN
		i:=0;
		WHILE i < strlen DO
			aChar ACCESS pString + i;
			IF aChar = char THEN 
				fFindFirstChar:=i+1;
				i:=strlen;
			END_IF;
			i:=i+1;
		END_WHILE	
	END_IF;	
END_FUNCTION
FUNCTION finvertBytes
	finvertBytes:=0;
	IF bytecount = 2 OR bytecount = 4 AND pValue > 0 THEN
		IF bytecount = 2 THEN
			finvertBytes:=2;
			aUINT ACCESS pValue;
			raw[0]:=aUINT[0];
			aUINT[0]:=aUINT[1];
			aUINT[1]:=raw[0];			
		ELSIF bytecount  =4 THEN
			finvertBytes:=4;
			aUDINT ACCESS pValue;
			raw[0]:=aUDINT[0];
			raw[1]:=aUDINT[1];
			aUDINT[0]:=aUDINT[3];
			aUDINT[1]:=aUDINT[2];
			aUDINT[2]:=raw[1];
			aUDINT[3]:=raw[0];
		END_IF;
	END_IF;	

END_FUNCTION

FUNCTION_BLOCK fScale
	IF enable THEN
		IF (x1 = x2) OR (y1 = y2) THEN
			y:=0;
		ELSE
			a:=(y1 - y2) / (x1 -x2);
			b:=y1 - a*x1;
			y:=a*x + b;
		END_IF;	
	END_IF;
END_FUNCTION_BLOCK

FUNCTION hexexp
	CASE in OF
		48 : hexexp:=0;
		49 : hexexp:=1;
		50 : hexexp:=2;
		51 : hexexp:=3;
		52 : hexexp:=4;
		53 : hexexp:=5;
		54 : hexexp:=6;
		55 : hexexp:=7;	
		56 : hexexp:=8;
		57 : hexexp:=9;
		65 : hexexp:=10;
		66 : hexexp:=11;
		67 : hexexp:=12;
		68 : hexexp:=13;
		69 : hexexp:=14;
		70 : hexexp:=15;
		ELSE
		      hexexp:=0;
	END_CASE		
END_FUNCTION
	
FUNCTION hexstr4todec
	brsmemcpy(ADR(hlp),pString,4);
	
	hexstr4todec:=hexexp(hlp[3]);
	hexstr4todec:= hexstr4todec + hexexp(hlp[2]) * 16;
	hexstr4todec:= hexstr4todec + hexexp(hlp[1]) * 256;
	hexstr4todec:= hexstr4todec + hexexp(hlp[0]) * 4096;
		
	
END_FUNCTION	
	
(*
	schneidet n digits einer DINT Zahl ab
*)
FUNCTION fTrunc_DINT 
	IN:=IN / d;
	fTrunc_DINT:=IN * d;
END_FUNCTION

(*
-gibt unit string aus (für batch header und export dateien)
*)
FUNCTION_BLOCK fgetUnitString
	CASE unit OF
		0,19:			out:='ml/min';	
		1:				out:='rpm';
		2:				out:='ml';
		3,4,5	:		out:='%';
		8:				out:='mbar';
		9:				out:='°C';
		10:				out:='g';
		12:				out:='S/m';		
		13:				out:='mS/cm';		//veraltet
		15:				out:='g/h';
		16:				out:='min';	
		17:				out:='Nm';
		18:		    	out:='m';
		ELSE		out:='-';	//6,7,11,14
	END_CASE
END_FUNCTION_BLOCK

FUNCTION fGetUnit

	CASE raw OF
		0 : //volumeFlow
			fGetUnit:=USINT_TO_UINT(raw)*100+ USINT_TO_UINT(setup.unitFlow);
		2 : //volume
			fGetUnit:=USINT_TO_UINT(raw)*100+ USINT_TO_UINT(setup.unitVol);
		19: //volume2
			fGetUnit:=USINT_TO_UINT(raw)*100+ USINT_TO_UINT(setup.unitVol2);
		8 : //pres
			fGetUnit:=USINT_TO_UINT(raw)*100+ USINT_TO_UINT(setup.unitPres);
		9 : //temp
			fGetUnit:=USINT_TO_UINT(raw)*100+ USINT_TO_UINT(setup.unitTemp);
		10 : //weight
			fGetUnit:=USINT_TO_UINT(raw)*100+ USINT_TO_UINT(setup.unitMass);
		12 : //cond
			fGetUnit:=USINT_TO_UINT(raw)*100+ USINT_TO_UINT(setup.unitCond);
		ELSE
			fGetUnit:=USINT_TO_UINT(raw)*100;
	END_CASE;

END_FUNCTION


FUNCTION_BLOCK fAlertExportWRITE
	CASE byStep OF
		
		0://einsprung
			IF export THEN
				
				byStep:=1;
				status:=1;
				error:=0;
				delFile:=0;
			END_IF;	
			
		1://try create
			FileCreate_0.enable:=1;
			//FileCreate_0.mode:=fiREAD_ONLY;
			FileCreate_0.pDevice:=ADR(device);
			FileCreate_0.pFile:=ADR('ALHistory.csv');
			FileCreate_0();
			
			IF FileCreate_0.status <> ERR_FUB_BUSY THEN
				IF FileCreate_0.status = fiERR_EXIST THEN //datei existiert schon
					byStep:=2;
					
				ELSIF FileCreate_0.status = ERR_OK THEN
					byStep:=3;
				ELSE
					error_step:=byStep;
					error_status:=FileCreate_0.status;
					byStep:=20;
					error:=1;
				END_IF;
				FileCreate_0(enable:=0);
			END_IF;
		2:	//if exits
			FileDelete_0.enable:=1;
			FileDelete_0.pDevice:=ADR(device);
			FileDelete_0.pName:=ADR('ALHistory.csv');
			FileDelete_0();
			IF FileDelete_0.status <> ERR_FUB_BUSY THEN
				IF FileDelete_0.status = ERR_OK THEN
					byStep:=20;
					delFile:=1;
				ELSE
					error_step:=byStep;
					error_status:=FileDelete_0.status;
					byStep:=20;
					error:=1;
				END_IF;
				FileDelete_0(enable:=0);
			END_IF;
		3: //make buffer
			fAlertExportGET_0.visu:=visu;
			fAlertExportGET_0();
			IF fAlertExportGET_0.status = 4 THEN
				error_step:=byStep;
				error_status:=fAlertExportGET_0.status;
				byStep:=20;
				error:=1;
			ELSIF fAlertExportGET_0.status = 0 THEN 
				byStep:=4;
			ELSE
				
			END_IF;
		4:	//open
			FileOpen_0.enable:=1;
			FileOpen_0.mode:=fiWRITE_ONLY;
			FileOpen_0.pDevice:=ADR(device);
			FileOpen_0.pFile:=ADR('ALHistory.csv');
			FileOpen_0();
			IF FileOpen_0.status <> ERR_FUB_BUSY THEN
				IF FileOpen_0.status = ERR_OK THEN
					byStep:=5;
				ELSE
					error_step:=byStep;
					error_status:=FileWrite_0.status;
					byStep:=20;	
					error:=1;				
				END_IF;
				//FileOpen_0(enable:=0);
			END_IF;	
		
		5: //write to file		
			
			FileWrite_0.enable:=1;
			FileWrite_0.ident:=FileOpen_0.ident;
			FileWrite_0.len:=fAlertExportGET_0.buf_out_len;
			FileWrite_0.offset:=0;
			FileWrite_0.pSrc:=ADR(fAlertExportGET_0.buf_out);
			FileWrite_0();
			
			IF FileWrite_0.status <> ERR_FUB_BUSY THEN
				IF FileWrite_0.status = ERR_OK THEN
					byStep:=20;
				ELSE
					error_step:=byStep;
					error_status:=FileWrite_0.status;
					byStep:=20;	
					error:=1;				
				END_IF;
				FileWrite_0(enable:=0);
			END_IF;	
		
		
			
		20://error
			
			FileClose_0.enable:=1;
			FileClose_0.ident:=FileCreate_0.ident;
			FileClose_0();
			
			IF FileClose_0.status <> ERR_FUB_BUSY THEN
				
				IF error THEN
					status:=2;
					byStep:=0;
					export := 0;
				ELSIF delFile THEN
					byStep:=1;
					delFile:=0;
				ELSE
					status:=0;
					export := 0;
					byStep:=0;
				END_IF;	
				FileClose_0(enable:=0);
				
			END_IF;	
			
					
				
			
	END_CASE
	
	
	
	
END_FUNCTION_BLOCK


FUNCTION_BLOCK fAlertExportGET
	
	CASE byStep OF
		0:		//einsprung
			VC_HANDLE := VA_Setup(1,visu); 
			IF VC_HANDLE <> 0 THEN 
				byStep:=1; 
				status:=1;
				buf_out_len:=0;
			END_IF;
		
		1: 	//access
			
			status_int:=VA_Saccess(1,VC_HANDLE);
			IF status_int=0 THEN 
				
				//byStep:=2;
				len_int:=SIZEOF(hlpstr);
				status_int:=VA_GetExAlarmList(1,VC_HANDLE,ADR(hlpstr),ADR(len_int),1,59,0);
			
				IF status_int <> vaERR_BUSY_ALARMSYSTEM AND status_int <> vaERR_BUSY THEN
					
					IF status_int = 0 THEN
						brsmemcpy(ADR(buf_out),ADR(header),SIZEOF(header));
						buf_out_len:=buf_out_len + UDINT_TO_DINT(SIZEOF(header));
						brsmemcpy(ADR(buf_out) + buf_out_len,ADR(CRLF),2);
						buf_out_len:=buf_out_len + 2;
						brsmemcpy(ADR(buf_out) + buf_out_len,ADR(hlpstr),DINT_TO_UDINT(len_int));
						buf_out_len:=buf_out_len + len_int;
						brsmemcpy(ADR(buf_out) + buf_out_len,ADR(CRLF),2);
						buf_out_len:=buf_out_len + 2;
						byStep:=2;
					ELSIF status_int = vaERR_EMPTY_ALARMLIST THEN
						byStep:=0;
						status:=0;
					ELSE
						error_stp:=byStep;
						error_status:=status_int;
						status:=4;
						byStep:=0;
					END_IF;	
				END_IF;
				status_int:=VA_Srelease(1,VC_HANDLE);	
			
			END_IF;
	
		2:	
		
			status_int:=VA_Saccess(1,VC_HANDLE);
			IF status_int=0 THEN 
				
				//byStep:=2;	
				len_int:=SIZEOF(hlpstr);
				status_int:=VA_GetExAlarmList(1,VC_HANDLE,ADR(hlpstr),ADR(len_int),2,59,0);
			
				IF status_int <> vaERR_BUSY_ALARMSYSTEM AND status_int <> vaERR_BUSY THEN
					
					IF status_int = 0 THEN
						brsmemcpy(ADR(buf_out) + buf_out_len,ADR(hlpstr),DINT_TO_UDINT(len_int));
						buf_out_len:=buf_out_len + len_int;
						brsmemcpy(ADR(buf_out) + buf_out_len,ADR(CRLF),2);
						buf_out_len:=buf_out_len + 2;
					ELSIF status_int = vaERR_EMPTY_ALARMLIST THEN
						byStep:=0;
						status:=0;
					ELSE
						error_stp:=byStep;
						error_status:=status_int;
						status:=4;
						byStep:=0;
					END_IF;	
				END_IF;
				status_int:=VA_Srelease(1,VC_HANDLE);	
			
			END_IF;
		
	END_CASE;
	
		
END_FUNCTION_BLOCK	


(*-------------------------------------------fDisableConfig------------------------------------------------------------------------*)
//deaktiviert cO und CL der rübergebenen config
FUNCTION fDisableAll
	
	//disable of sequenzes not here because of e.g. safety cooling in steri sequences
	
	//disable all actuators
	FOR i:=0 TO ncO BY 1 DO
		IF non.cO[i].type <> 12 THEN	//alle typen außer die stapelweise verarbeiteten ventile werden zurückgesetzt,
			rem.config.cO[i].out:=0;
		END_IF;
	END_FOR;
	//disable all Controllers
	FOR i:=0 TO ncCL BY 1 DO
		rem.config.cCL[i].enable:=0;
	END_FOR;
	//disable all profiles
	FOR i:=0 TO nPROFILE BY 1 DO
		rem.profile[i].status:=0;
		rem.profile[i].start:=0;
	END_FOR;
	
	fDisableAll;
END_FUNCTION