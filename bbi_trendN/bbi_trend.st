(********************************************************************
 * COPYRIGHT -- bbi-biotech
 ********************************************************************
 * Program: logfile
 * File: fBatchfile.st
 * Author: Tilo
 * Created: January 09, 2012
 ********************************************************************
 * Implementation of program logfile
 ********************************************************************) 

FUNCTION_BLOCK fTrendRead
	(*
	Liest portionsweise Rohdaten-Blöcke aus dem DRAM Dateiabbild um CSV-Exportdateien oder
	die Bildpunkte für die Y-Achsen im Trendobjekt zu erzeugen.
	!Es erfolgen keine Vorbereitungen oder Auswertungen von Achsdatenpunkten mehr (das macht der langsame Visu Task)
	Dateifunktionen für die Trenddatei müssen hier nicht mehr ausgeführt werden (alles aus DRAM mit Zeiger in Kontrollstruktur.
	Eine asynchrone Abbarbeitung möglichst kleiner Blöcke ist notwendig, 
	da je größer der Block, um so größer die Unsicherheit bezüglich der Rechenzeit für die Umwandlung und damit Gefahr von Zykluszeitverletzungen	
	Der FUB ist als Schrittkette organisiert.
	zentrale Kommandos kommen mit c.CMD rein und werden mit 0(fertig) quittiert
	mit c.STA kann dann der Status vom aufrufenden task ausgewertet werden
	STEP ist die interne Schrittvariable, diese darf nicht von außen manipuliert werden. 
	*)
	
	(*
	Abbruchkommando außerhalb der Schleife, direkt in closeCSV Springen
	dann erst Fehlerstaus setzen
	close fehler muss dann überbrückt werden
	Im Warteschritt für dieses Kommando ohne Aktion quittiert
	*)
	IF c.CMD = BAT_R_CMD_abort THEN	//bei stop CMD auf definierten abbruchzweig routen
		IF STEP = BAT_R_STP_wait THEN
			c.CMD:=0;
		ELSE
			DirCreate_0.enable:=0;
			FileOpen_0.enable:=0;
			FileWriteEx_0.enable:=0;
			FileClose_0.enable:=0;
			FileCreate_0.enable:=0;
			STEP:=BAT_R_STP_closeCSV;
			c.STATUS:= BAT_R_STA_closingAbort;
		END_IF;
	END_IF;	

	CASE STEP OF

		BAT_R_STP_wait:
		
			IF c.STATUS = BAT_R_STA_waiting OR c.STATUS = BAT_R_STA_error THEN
				IF c.CMD <> 0 THEN
					IF SIZEOF(aHead) + SIZEOF(aDataA) > c.lastFileOpenLen  THEN   // es müssen mindestens soviele Bytes vorhanden sein um einen Header und den ersten datenzeilenheader abzubilden, datengröße kann nicht mehr geprüft werden, da Tolelranz gegenüber kanaländerungen
						c.error.errorFub:=FileOpen_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='Allocated DRAM size to small';
						c.error.errorSta:=c.STATUS;
						c.STATUS:=BAT_R_STA_error;
						c.CMD:=0;
					ELSE
						offsetTrendFile:=0;	//gesamte gelesene Bytes der Trenddatei
						bufReadTrend:=0; //gelesene bytes im aktuellen block zurücksetzen
						c.rawSamplesRead:=0;	//Anzahl gelesener Datenzeilen in der Trenddatei zurücksetzen
						c.trendSamplesPlotted:=0;	//Anzahl interpolierter zeilen im Trendobjekt
						c.numSkippedRawSamplesTimeErr:=0;
						c.numSkippedTimeouts:=0;
						c.numSkippedRawSamplesCRC:=0;
						c.numSkippedRawBytes:=0;
						targetTimeIncMsec:=c.range * 1000 / (TRENDITEMS );	//die Zielzeiten innerhalb eines Interpolationsschrittes werden in msec geführt
						targetTimeSecAbs:=DT_TO_UDINT(c.offset);
						targetTimeOffsetMsec:=0;
						c.CSVfilesMade:=0;	//Anzahl der erzeugten CSV Dateien
						dataDel;//abbild für memcmp des datendelimeters
						c.rawBuffersRead:=1; //der erste Rohpuffer wird ja sofort begonnen
						offsetCSVFile:=0; // CSV Dateioffset zum Schreiben
						buflenCSV:=0; // Anzahl Bytes bereit im Ausgabepuffer CSV
						FOR i:=0 TO nTRENDCHANNELS BY 1 DO	//min max initialisieren für auto scale
							c.maxPlotted[i]:=1;
							c.minPlotted[i]:=-1;
						END_FOR	
						IF c.CMD = BAT_R_CMD_trend THEN	//trendrefresh angeforderd
							STEP:=BAT_R_STP_unzipCheck;//Plotting = direkt in headerprüfung
							c.STATUS:=BAT_R_STA_unzipping;	
						ELSIF c.CMD = BAT_R_CMD_csvFull OR c.CMD = BAT_R_CMD_csvSmall THEN						
							STEP:=BAT_R_STP_createDir;	//CSV = erst Ordner und Datei erzeuegn
							c.STATUS:=BAT_R_STA_preparing;
						ELSE
							c.error.errorFub:=0;
							c.error.errorStep:=STEP;
							c.error.errorString:='unknown command';
							c.error.errorSta:=c.STATUS;
							c.STATUS:=BAT_R_STA_error;
							c.CMD:=0;
						END_IF;	
					END_IF;	
				END_IF;	
			END_IF;	
			
		BAT_R_STP_createDir:
		
			IF DirCreate_0.enable=0 THEN
				DirCreate_0.enable:=1;
				DirCreate_0.pDevice:=ADR(USBDEVICE);
				DirCreate_0.pName:=ADR('TRENDEXPORT');
			END_IF;
			IF DirCreate_0.status <> ERR_FUB_BUSY AND DirCreate_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF DirCreate_0.status <> ERR_OK AND DirCreate_0.status <> fiERR_DIR_ALREADY_EXIST THEN
					c.error.errorFub:=DirCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unhandled error while creating Dir';
					c.error.errorSta:=c.STATUS;
					STEP:=BAT_R_STP_wait;
					c.STATUS:=BAT_R_STA_error;
					c.CMD:=0;
				ELSE
					STEP:=BAT_R_STP_createCSV;
				END_IF;
				DirCreate_0.enable:=0;
			END_IF
				
		BAT_R_STP_createCSV://anlegen der CSV datei
					
			IF FileCreate_0.enable=0 THEN		
				aHead ACCESS c.pAllocated;
				FileCreate_0.enable:=1;
				FileCreate_0.pDevice:=ADR(USBDEVICE);
				hlpstr:='TRENDEXPORT/';	
				hlpstr:=CONCAT(hlpstr,aHead.A.tag);	//dateinamen aus dialog anhängen
				IF c.CMD = BAT_R_CMD_csvFull THEN
					hlpstr:=CONCAT(hlpstr,'_full');	
				ELSE
					hlpstr:=CONCAT(hlpstr,'_filtered');
				END_IF;	
				IF c.CSVfilesMade > 0 THEN	//suffix anhängen bei mehreren CSV dateien
					brsitoa(UDINT_TO_DINT(c.CSVfilesMade), ADR(hlpstr2));
					hlpstr:=CONCAT(hlpstr,'_');
					hlpstr:=CONCAT(hlpstr,hlpstr2);
				END_IF;
				hlpstr:=CONCAT(hlpstr,'.CSV');
				FileCreate_0.pFile:=ADR(hlpstr);
			END_IF;			
			IF FileCreate_0.status <> ERR_FUB_BUSY AND FileCreate_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FileCreate_0.status <> ERR_OK THEN
					IF FileCreate_0.status = fiERR_EXIST THEN
						c.error.errorString:='file exists already';
					ELSE
						c.error.errorString:='unhandled error while creating CSV';
					END_IF;
					c.error.errorFub:=FileCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorSta:=c.STATUS;
					STEP:=BAT_R_STP_wait;
					c.STATUS:=BAT_R_STA_error;
					c.CMD:=0;
				ELSE 
					c.CSVfilesMade:=c.CSVfilesMade + 1;
					identCSV:=FileCreate_0.ident;
					c.CSVlinesWritten:=0; //aktuelle Zeilenzahl in der CSV zurücksetzen
					IF c.STATUS = BAT_R_STA_preparing THEN //erste datei
						STEP:=BAT_R_STP_unzipCheck;//hier für erste Datei jeweils (erste Datenzeile) in Headerprüfung springen
						c.STATUS:=BAT_R_STA_unzipping;
					ELSIF c.CMD = BAT_R_CMD_csvFull THEN //c.STATUS = BAT_R_STA_newCSVfile
						STEP:=BAT_R_STP_CSVfullHeader;	//sonst für weiter Dateien nur header erzeugen ohne erste datenzeile
					ELSIF c.CMD = BAT_R_CMD_csvSmall THEN
						STEP:=BAT_R_STP_CSVsmallHeader;
					END_IF;
					//status bleibt wie zuvor (preparing oder unzipping)
				END_IF;
				FileCreate_0.enable:=0;
			END_IF
	
		BAT_R_STP_unzipCheck:
			(*
			Header prüfen
			Wenn alles Ok dann erste Datenzeile bereits als lastV/T vorbereiten
			gelesenen Pufferoffset erhöhen
			*)
			aHead ACCESS c.pAllocated; //Datengröße wurde dahingehend bereits zuvor geprüft
			copyHeader:=aHead;
			//diverse fehlerüberprüfungen im header
			CRCA:=CRC32(SIZEOF(copyHeader.A),ADR(copyHeader.A),BATCH_GENERATOR);
			CRCB:=CRC32(SIZEOF(copyHeader.B)-8,ADR(copyHeader.B),BATCH_GENERATOR);
			IF CRCA <> aHead.CRC_A THEN
				c.error.errorFub:=0;
				c.error.errorStep:=STEP;
				c.error.errorString:='Header A corrupted (CRC32)';
				c.error.errorSta:=c.STATUS;
				c.STATUS:=BAT_R_STA_error;
			ELSIF CRCB <> aHead.B.CRC_B THEN
				c.error.errorFub:=0;
				c.error.errorStep:=STEP;
				c.error.errorString:='Header B corrupted (CRC32)';
				c.error.errorSta:=c.STATUS;
				c.STATUS:=BAT_R_STA_error;
			ELSIF brsmemcmp(c.pAllocated + SIZEOF (aHead),ADR(dataDel),4) <> 0 THEN //ersten dataLine Delimeter prüfen
				c.error.errorFub:=0;
				c.error.errorStep:=STEP;
				c.error.errorString:='start Delimeter in first data line missing';
				c.error.errorSta:=c.STATUS;
				c.STATUS:=BAT_R_STA_error;
			ELSE
				bufReadTrend:=	bufReadTrend + SIZEOF (copyHeader);
				aDataA ACCESS c.pAllocated + bufReadTrend;//Datengröße wurde dahingehend bereits bei Kommandoübernahme zuvor geprüft
				cOmax:=	BITCNT(ADR(aDataA.cO_changed),64);
				cCLmax:=   BITCNT(ADR(aDataA.cCL_changed),64);
				cImax:=	BITCNT(ADR(aDataA.cI_changed),64);
				allChannelsMax:=cImax + cCLmax + cOmax;	//hier wird die tatsächliche Kanalanzahl der Anlage gespeichert, damit nicht über alle möglich 144 Kanäle gerechnet werden muss
				IF cOmax=0 OR cCLmax=0 OR cImax=0 THEN
					c.error.errorFub:=0;
					c.error.errorStep:=STEP;
					c.error.errorString:='Channel count 0 not allowed';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_R_STA_error;
				ELSIF bufReadTrend + SIZEOF(aDataA) + (allChannelsMax * 4) + 8 > c.lastFileOpenLen THEN //erwartete länge der datenzeile überschreitet TREND pufferlänge
					c.error.errorFub:=0;
					c.error.errorStep:=STEP;
					c.error.errorString:='file size to small for first data line';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_R_STA_error;
				ELSIF aDataA.t <> aHead.A.firstDat  THEN
					c.error.errorFub:=0;
					c.error.errorStep:=STEP;
					c.error.errorString:='Start Time in first line wrong';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_R_STA_error;
				ELSE
					aCRC ACCESS c.pAllocated + bufReadTrend + SIZEOF(aDataA) + (allChannelsMax * 4);
					CRCA:=CRC32(SIZEOF(aDataA) + (allChannelsMax * 4),c.pAllocated + bufReadTrend,BATCH_GENERATOR);
					IF CRCA <> aCRC THEN //CRC prüfung
						c.error.errorFub:=0;
						c.error.errorStep:=STEP;
						c.error.errorString:='CRC error in first line';
						c.error.errorSta:=c.STATUS;
						c.STATUS:=BAT_R_STA_error;
					ELSE	
						bufReadTrend := bufReadTrend + SIZEOF(aDataA);
						//Eingänge erste Datenzeile in lastT entpacken
						lastT:=DT_TO_UDINT(aDataA.t);
						FOR i:=0 TO cImax-1  BY 1 DO
							aReal ACCESS c.pAllocated + bufReadTrend;
							lastV[i]:= aReal;
							bufReadTrend := bufReadTrend + 4;
						END_FOR;
						FOR i:=cImax TO cCLmax+cImax - 1 BY 1 DO
							aReal ACCESS c.pAllocated + bufReadTrend;
							lastV[i]:= aReal;
							bufReadTrend := bufReadTrend + 4;	
						END_FOR;
						FOR i:=cImax+cCLmax TO cOmax+cImax+cCLmax - 1 BY 1 DO
							aReal ACCESS c.pAllocated + bufReadTrend;
							lastV[i]:= aReal;
							bufReadTrend := bufReadTrend + 4;	
						END_FOR;
						c.rawSamplesRead:=1;
						bufReadTrend := bufReadTrend + 8;//Checksumme und end delimeter
						//Y1 initialisieren und autoscale initialisieren
						FOR i:=0 TO nTRENDCHANNELS BY 1 DO
							CASE c.selectedTypeY[i] OF
								0: //cI	
									Y1[i]:=lastV[c.selectedIndexY[i]];
								1: //cCL	
									Y1[i]:=lastV[c.selectedIndexY[i] + cImax];	
								2: //cO
									indexOffset := cImax + cCLmax;
									Y1[i]:=lastV[c.selectedIndexY[i] + indexOffset];
								3: //hidden
									Y1[i]:=0;
							END_CASE	
							//wenn erstes Sample im Zeichenbereich, dann autoscalegrenzen initialisieren
							IF lastT >= DT_TO_UDINT(c.offset) THEN     
								IF Y1[i] > c.maxPlotted[i] THEN
									c.maxPlotted[i] := Y1[i];
								END_IF;
								IF Y1[i] < c.minPlotted[i] THEN
									c.minPlotted[i] := Y1[i];
								END_IF;;
							END_IF;		
						END_FOR
						
					END_IF;	
				END_IF;
			END_IF;
			//wenn header und erste datenzeile erfolgreich entpackt und geprüft
			IF c.STATUS=BAT_R_STA_unzipping THEN												
				IF c.CMD = BAT_R_CMD_trend THEN
					STEP:=BAT_R_STP_unzip;
				ELSIF c.CMD = BAT_R_CMD_csvFull THEN
					STEP:=BAT_R_STP_CSVfullHeader;
				ELSIF c.CMD = BAT_R_CMD_csvSmall THEN
					STEP:=BAT_R_STP_CSVsmallHeader;
				END_IF;
				c.STATUS:=BAT_R_STA_unzipping;
			ELSE//wenn Prüffehler
				IF c.CMD = BAT_R_CMD_trend THEN	//trendrefresh angeforderd
					STEP:=BAT_R_STP_wait;//direkt zurück für trendplotten
					c.STATUS:=BAT_R_STA_error;
					c.CMD:=0;
				ELSE //csv export angefordert
					STEP:=BAT_R_STP_closeCSV;
					c.STATUS:=BAT_R_STA_closingError;
				END_IF;
			END_IF;	

		BAT_R_STP_CSVsmallHeader:	//nur auswahlspalten im gewählten zeitbereich
			
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.A.tag),brsstrlen(ADR(aHead.A.tag)));
			buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.A.tag));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//Comment
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.A.comment),brsstrlen(ADR(aHead.A.comment)));
			buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.A.comment));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//spalten tags
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('Date and Time'),brsstrlen(ADR('Date and Time')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('Date and Time'));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('Trend Age'),brsstrlen(ADR('Trend Age')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('Trend Age'));
		
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('Inoculation Age'),brsstrlen(ADR('Inoculation Age')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('Inoculation Age'));
			FOR i:=0 TO nTRENDCHANNELS BY 1 DO
				
				CASE c.selectedTypeY[i] OF 
					0: //cI
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
						buflenCSV:= buflenCSV + 1;

						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('I: '),brsstrlen(ADR('I: ')));
						buflenCSV:= buflenCSV + brsstrlen(ADR('I: '));
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.tags.cI[c.selectedIndexY[i]]),brsstrlen(ADR(aHead.B.tags.cI[c.selectedIndexY[i]])));
						buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.tags.cI[c.selectedIndexY[i]]));	
					1: //cCL
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
						buflenCSV:= buflenCSV + 1;
						
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('SP '),brsstrlen(ADR('SP ')));
						buflenCSV:= buflenCSV + brsstrlen(ADR('SP '));
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.tags.cCL[c.selectedIndexY[i]]),brsstrlen(ADR(aHead.B.tags.cCL[c.selectedIndexY[i]])));
						buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.tags.cCL[c.selectedIndexY[i]]));
					2: //cO
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
						buflenCSV:= buflenCSV + 1;
						
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('O: '),brsstrlen(ADR('O: ')));
						buflenCSV:= buflenCSV + brsstrlen(ADR('O: '));
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.tags.cO[c.selectedIndexY[i]]),brsstrlen(ADR(aHead.B.tags.cO[c.selectedIndexY[i]])));
						buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.tags.cO[c.selectedIndexY[i]]));
					3://nix
				END_CASE	
			END_FOR	
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//units 
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('DDD MMM D HH:MM:SS JJJJ'),brsstrlen(ADR('DDD MMM D HH:MM:SS JJJJ')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('DoW MoY D HH:MM:SS JJJJ'));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('h'),brsstrlen(ADR('h')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('h'));
			
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('h'),brsstrlen(ADR('h')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('h'));
			FOR i:=0 TO nTRENDCHANNELS BY 1 DO
					
				CASE c.selectedTypeY[i] OF 
					0: //cI
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
						buflenCSV:= buflenCSV + 1;
						
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.units.cI[c.selectedIndexY[i]]),brsstrlen(ADR(aHead.B.units.cI[c.selectedIndexY[i]])));
						buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.units.cI[c.selectedIndexY[i]]));	
					1: //cCL
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
						buflenCSV:= buflenCSV + 1;
						
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.units.cCL[c.selectedIndexY[i]]),brsstrlen(ADR(aHead.B.units.cCL[c.selectedIndexY[i]])));
						buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.units.cCL[c.selectedIndexY[i]]));
					2: //cO
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
						buflenCSV:= buflenCSV + 1;
						
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.units.cO[c.selectedIndexY[i]]),brsstrlen(ADR(aHead.B.units.cO[c.selectedIndexY[i]])));
						buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.units.cO[c.selectedIndexY[i]]));
					3://nix
				END_CASE
				
			END_FOR	
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//erste datenzeile nur für 1. Datei schreiben, falls die zeit schon im zu plotenden Bereich liegt
			IF (c.STATUS <> BAT_R_STA_newCSVfile) AND (DT_TO_UDINT(aDataA.t)>=targetTimeSecAbs) THEN
				targetTimeSecAbs:=DT_TO_UDINT(aDataA.t)+1;
				ascDT(aDataA.t,ADR(hlpstr),SIZEOF(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
				buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.firstDat))/ 3600;
				brsftoa(curAge,ADR(hlpstr));
				//punkt finden und gegen komma austauschen
				fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
				buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));							
				//ino age ergänzen
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;						
				IF aHead.A.inoculumDat = 0 THEN	//kein ino gesetzt
					curAge:=0;
				ELSIF DiffDT(aDataA.t,aHead.A.inoculumDat) = 4294967295 THEN //vor ino negative age generieren	
					curAge:=UDINT_TO_REAL(DiffDT(aHead.A.inoculumDat,aDataA.t))/ 3600 * -1;
				ELSE
					curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.inoculumDat))/ 3600;	
				END_IF;
				brsftoa(curAge,ADR(hlpstr));
				//punkt finden und gegen komma austauschen
				fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
				buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));							
				FOR i:=0 TO nTRENDCHANNELS BY 1 DO							
					//prüfen, damit bei hidden=3 nichts gemacht wird
					IF c.selectedTypeY[i] < 3 THEN
	
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
						buflenCSV:= buflenCSV + 1;
	
						brsftoa(Y1[i],ADR(hlpstr));
						fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
						brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
						buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
					END_IF;
				END_FOR	
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
				buflenCSV:= buflenCSV + 2;
				c.CSVlinesWritten:=c.CSVlinesWritten+1;
			END_IF;
			STEP:=BAT_R_STP_unzip;
			c.STATUS:=BAT_R_STA_unzipping;	

		BAT_R_STP_CSVfullHeader:

			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.A.tag),brsstrlen(ADR(aHead.A.tag)));
			buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.A.tag));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//Comment
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.A.comment),brsstrlen(ADR(aHead.A.comment)));
			buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.A.comment));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//spalten tags
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('Date and Time'),brsstrlen(ADR('Date and Time')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('Date and Time'));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('Trend Age'),brsstrlen(ADR('Trend Age')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('Trend Age'));
		
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('Inoculation Age'),brsstrlen(ADR('Inoculation Age')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('Inoculation Age'));

			FOR i:= 0 TO cImax - 1 BY 1 DO 
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('I: '),brsstrlen(ADR('I: ')));
				buflenCSV:= buflenCSV + brsstrlen(ADR('I: '));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.tags.cI[i]),brsstrlen(ADR(aHead.B.tags.cI[i])));
				buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.tags.cI[i]));
			END_FOR;
			FOR i:= 0 TO cCLmax - 1 BY 1 DO 
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('SP '),brsstrlen(ADR('SP ')));
				buflenCSV:= buflenCSV + brsstrlen(ADR('SP '));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.tags.cCL[i]),brsstrlen(ADR(aHead.B.tags.cCL[i])));
				buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.tags.cCL[i]));
			END_FOR;
			FOR i:= 0 TO cOmax - 1 BY 1 DO 
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('O: '),brsstrlen(ADR('O: ')));
				buflenCSV:= buflenCSV + brsstrlen(ADR('O: '));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.tags.cO[i]),brsstrlen(ADR(aHead.B.tags.cO[i])));
				buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.tags.cO[i]));
			END_FOR;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//units batch
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('DDD MMM D HH:MM:SS JJJJ'),brsstrlen(ADR('DDD MMM D HH:MM:SS JJJJ')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('DoW MoY D HH:MM:SS JJJJ'));
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('h'),brsstrlen(ADR('h')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('h'));
			
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
			buflenCSV:= buflenCSV + 1;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR('h'),brsstrlen(ADR('h')));
			buflenCSV:= buflenCSV + brsstrlen(ADR('h'));

			FOR i:= 0 TO cImax - 1 BY 1 DO 
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.units.cI[i]),brsstrlen(ADR(aHead.B.units.cI[i])));
				buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.units.cI[i]));
			END_FOR;
			FOR i:= 0 TO cCLmax -1 BY 1 DO 
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.units.cCL[i]),brsstrlen(ADR(aHead.B.units.cCL[i])));
				buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.units.cCL[i]));
			END_FOR;
			FOR i:= 0 TO cOmax - 1 BY 1 DO 
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(aHead.B.units.cO[i]),brsstrlen(ADR(aHead.B.units.cO[i])));
				buflenCSV:= buflenCSV + brsstrlen(ADR(aHead.B.units.cO[i]));
			END_FOR;
			brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
			buflenCSV:= buflenCSV + 2;
			c.CSVlinesWritten:=c.CSVlinesWritten+1;
			//erste datenzeile nur für 1. Datei schreiben
			IF c.STATUS <> BAT_R_STA_newCSVfile THEN
				ascDT(aDataA.t,ADR(hlpstr),SIZEOF(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
				buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;
				curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.firstDat))/ 3600;
				brsftoa(curAge,ADR(hlpstr));
				//punkt finden und gegen komma austauschen
				fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
				buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
				//ino age ergänzen
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
				buflenCSV:= buflenCSV + 1;					
				IF aHead.A.inoculumDat = 0 THEN	//kein ino gesetzt
					curAge:=0;
				ELSIF DiffDT(aDataA.t,aHead.A.inoculumDat) = 4294967295 THEN //vor ino negative age generieren	
					curAge:=UDINT_TO_REAL(DiffDT(aHead.A.inoculumDat,aDataA.t))/ 3600 * -1;
				ELSE
					curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.inoculumDat))/ 3600;	
				END_IF;
				brsftoa(curAge,ADR(hlpstr));
				//punkt finden und gegen komma austauschen
				fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
				buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));						
				FOR i:= 0 TO (allChannelsMax - 1) BY 1 DO 
					brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
					buflenCSV:= buflenCSV + 1;
					brsftoa(lastV[i],ADR(hlpstr));
					fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
					brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
					buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
				END_FOR;		
				brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
				buflenCSV:= buflenCSV + 2;
				c.CSVlinesWritten:=c.CSVlinesWritten+1;
			END_IF;
			STEP:=BAT_R_STP_unzip;
			c.STATUS:=BAT_R_STA_unzipping;
			
		BAT_R_STP_readData:	//Zwischenschritt um FUB zwischen den Blöcken freizugeben

			STEP:=BAT_R_STP_unzip;
			c.rawBuffersRead:=c.rawBuffersRead + 1;
			offsetTrendFile:=offsetTrendFile + bufReadTrend;	//offset gesamte TREND Datei um gelesene Trend Puffer Bytes erhöhen
			bufReadTrend:=0; //gelesene bytes im aktuellen block zurücksetzen
	
		BAT_R_STP_unzip:
			(*
			oberste While schleife nutzt STEP Variable als Abbruchbedingung
			Zuerst muss ein Rohsample entpackt werden.
			Dazu werden anhand der gesetzten Bits für das gefundene Roh-Sample alle Kanäle entpackt curV
			(zumindest In der ersten Datenzeile sollten auch alle Startwerte der Kanäle hinterlegt sein)
			Beim ersten entpackten Roh-Sample wird lastV gesetzt und noch kein TrendSample geplottet (bereits mit header).
			Beim zweiten und jedem weiteren Sample wird fortlaufend curV gebildet.
				Eine innere Schleife plottet jetzt alle TrendSamples die kleiner curT sind
				dabei werden Ziel und Roh-Samplezeiten als UDINT Konvertierungen der absoluten Zeiten verglichen
				Anhand der relativen Position der Zielzeiten zwischen curT und lastT erfolgt eine lineare Interpolation der Y-Werte
				Dabei werden nur die Werte interpoliert, die nach curRecConfig auch gewählt sind.
			Sind alle TrendSamples vor curT geplottet wird curV/T zu lastV/T und ein neues Roh-Sample wird entpackt.
			Das ganze passiert solange bis Blocklänge erreicht-->dann FUB für einen Zyklus freigeben und neuen Block beginnen
			ODER bis Gesamtdatenlänge durchlaufen.
			ODER bis letzte Zielzeit geplottet
			*)
			WHILE (STEP = BAT_R_STP_unzip) DO 
				(*
				1. Mögliche Abbruchbedingung
				erwartete Länge der zu bearbeitenden Kopfdaten überschreitet TREND Gesamtlänge
				Dabei muss wenigstens noch ein header reinpassen
				eher eine Angstbedingung, da vorher das letzte Sample erreicht sin sollte
				*)
				IF offsetTrendFile + bufReadTrend + SIZEOF(aDataA) > c.lastFileOpenLen THEN
					//dann für Trendplotting sofort quittieren
					IF c.CMD = BAT_R_CMD_trend THEN	//wenn nur trendexport
						STEP:=BAT_R_STP_wait;
						IF c.rawSamplesRead = 1 THEN //beim öffnen während des erstern samples
							c.STATUS:=BAT_R_STA_waiting;	
						ELSIF c.trendSamplesPlotted  < TRENDITEMS - 5 THEN
							c.error.errorFub:=0;
							c.error.errorStep:=STEP;
							c.error.errorString:='internal plotting error, too less samples plotted';
							c.error.errorSta:=c.STATUS;
							c.STATUS:=BAT_R_STA_error;
						ELSE
							c.STATUS:=BAT_R_STA_waiting;
						END_IF;
						c.CMD:=0;
					//für CSV Exporte erst schließen
					ELSE
						c.STATUS:=BAT_R_STA_closing;// CSV Puffer abschließend schreiben und alles schließen 
						STEP:=BAT_R_STP_writeCSV;
					END_IF	
				//erwartete Länge der zu bearbeitenden Kopfdaten überschreitet TREND Blocklänge für asynchrone Bearbeitung
				ELSIF bufReadTrend + SIZEOF(aDataA) > BAT_R_BUFSIZE  THEN 
//					c.STATUS:=BAT_R_STA_getBuf;//neuen TREND Puffer holen , direkt zurückkehren
					STEP:=BAT_R_STP_readData;
					//genug Daten für einen Datenkopfbereich da
				ELSIF brsmemcmp(c.pAllocated + offsetTrendFile + bufReadTrend,ADR(dataDel),4) <> 0 THEN //dataLine Delimeter prüfen
//					brsmemcpy(ADR(debugSample),c.pAllocated + offsetTrendFile + bufReadTrend,256);
//					debugPosition:=offsetTrendFile + bufReadTrend;
					bufReadTrend := bufReadTrend + 1; //ein byte weiter, wenn kein Trend Sample, z.B. AT Bereich oder Fehlerhaftes Sample
					c.numSkippedRawBytes:=c.numSkippedRawBytes + 1;
				ELSE
					aDataA ACCESS c.pAllocated + offsetTrendFile + bufReadTrend; //Referenz setzen, noch nicht gelesen Datenlänge erhöhen
					allchannelsThisSample:=BITCNT(ADR(aDataA.cI_changed),cImax) + BITCNT(ADR(aDataA.cCL_changed),cCLmax) + BITCNT(ADR(aDataA.cO_changed),cOmax);
					//Falls Dateiende erreicht
					IF (offsetTrendFile + bufReadTrend + SIZEOF(aDataA) + (allchannelsThisSample * 4) + 8) > c.lastFileOpenLen THEN
						//dann für Trendplotting sofort quittieren
						IF c.CMD = BAT_R_CMD_trend THEN	//wenn nur trendexport
							STEP:=BAT_R_STP_wait;
							IF c.trendSamplesPlotted  < TRENDITEMS - 5 THEN
								c.error.errorFub:=0;
								c.error.errorStep:=STEP;
								c.error.errorString:='internal plotting error, too less samples plotted';
								c.error.errorSta:=c.STATUS;
								c.STATUS:=BAT_R_STA_error;
							ELSE
								c.STATUS:=BAT_R_STA_waiting;
							END_IF;
							c.CMD:=0;
							//für CSV Exporte erst schließen
						ELSE
							c.STATUS:=BAT_R_STA_closing;// CSV Puffer abschließend schreiben und alles schließen 
							STEP:=BAT_R_STP_writeCSV;
						END_IF	
						//falls blockende erreicht
					ELSIF (bufReadTrend + SIZEOF(aDataA) + (allchannelsThisSample * 4) + 8) > BAT_R_BUFSIZE  THEN 
//						c.STATUS:=BAT_R_STA_getBuf;//neuen TREND Puffer holen , direkt zurückkehren
						STEP:=BAT_R_STP_readData;
						//genug für einen Datenbereich da
					ELSE	
						aCRC ACCESS c.pAllocated + offsetTrendFile + bufReadTrend + SIZEOF(aDataA) + (allchannelsThisSample * 4);
						IF CRC32(SIZEOF(aDataA) + (allchannelsThisSample * 4),c.pAllocated + offsetTrendFile + bufReadTrend , BATCH_GENERATOR) <> aCRC THEN //CRC schlägt fehl
							bufReadTrend := bufReadTrend + 1; 
							c.numSkippedRawSamplesCRC:=c.numSkippedRawSamplesCRC + 1;
						//wenn dT=0 (Samplezeit gleich oder kleiner dem vorherigen Sample), 
						//nichts zeichnen, nur Erfassen, Sample verwerfen
						ELSIF DT_TO_UDINT(aDataA.t) <= lastT THEN
							bufReadTrend := bufReadTrend + SIZEOF(aDataA) + (allchannelsThisSample * 4) + 8;//CRC war OK, also kann die gelesene Datenlängeerhöht werden
							c.numSkippedRawSamplesTimeErr:=c.numSkippedRawSamplesTimeErr + 1;
						ELSE
							c.rawSamplesRead:=c.rawSamplesRead + 1;
							bufReadTrend := bufReadTrend + SIZEOF(aDataA); //erstmal nur um headergröße erhöhen
							curT:=DT_TO_UDINT(aDataA.t);
//							debugTargetTdif:=DiffDT(UDINT_TO_DT(targetTimeSecAbs),debugTargetT);
//							debugTargetT:=UDINT_TO_DT(targetTimeSecAbs);
//							debugSampleTdif:=DiffDT(aDataA.t,debugSampleT);
//							debugSampleT:=aDataA.t;
							IF allchannelsThisSample=0 THEN //wenn leeres Sample
								curV:= lastV;//letzte werte nehmen
							ELSE //ansonsten differenzierte prüfung
								FOR i:=0 TO cImax - 1 DO
									IF BITTST(ADR(aDataA.cI_changed),i) THEN // wenn kanal geändert wurde
										aReal ACCESS c.pAllocated + offsetTrendFile + bufReadTrend;
										curV[i]:= aReal;
										bufReadTrend := bufReadTrend + 4; //beim lesen jeweils erhöhen
									ELSE
										curV[i]:= lastV[i];
									END_IF;	
								END_FOR;
								FOR i:=0 TO cCLmax - 1 BY 1 DO
									IF BITTST(ADR(aDataA.cCL_changed),i) THEN // wenn kanal geändert wurde
										aReal ACCESS c.pAllocated + offsetTrendFile + bufReadTrend;
										curV[cImax + i]:= aReal;
										bufReadTrend := bufReadTrend + 4;
									ELSE
										curV[cImax + i]:= lastV[cImax + i];
									END_IF;		
								END_FOR;
								indexOffset:=cImax + cCLmax;
								FOR i:=0 TO cOmax - 1 BY 1 DO
									IF BITTST(ADR(aDataA.cO_changed),i) THEN // wenn kanal geändert wurde
										aReal ACCESS c.pAllocated + offsetTrendFile + bufReadTrend;
										curV[indexOffset + i]:= aReal;
										bufReadTrend := bufReadTrend + 4;
									ELSE
										curV[indexOffset + i]:= lastV[indexOffset + i];
									END_IF;		
								END_FOR;
							END_IF;
							bufReadTrend := bufReadTrend + 8; //CRC und end del
							(* 
							Wenn die obere WHILE Schleife bis hierhin durchreicht, dann sind zwei gültige Rohsamples entpackt.
							für jede RohY Achse liegen die Y Werte in lastV[]/curV[], 
							die Zeiten in lastT/curT sind !! Absolute !! UDINT Zeiten in Sekunden
							Trendplotting-Prüfung erfolgt bei entsprechendem CMD 
							*)
							IF c.CMD = BAT_R_CMD_trend THEN
								(*
								nur zeichnen, falls neue Absolute Zielzeit Im Sekunden im Bereich zwischen den Roh-Samples
								hier wurde bereits geprüft, dass curT > lastT
								Y-Werte nach Achsbelegung für Interpolation vorbereiten, 
								Außerhalb der Plotting Schleife prüfen
								!!!falls es einen MSEC rest aus letztem plotting gibt, ändert sich die Bedingung
								für curT >= targetTimeSecAbs auf curT > targetTimeSecAbs
								mit targetTimeOffsetMsec > 0 liegt bei curT = targetTimeSecAbs das relativ berechnete tx schon nicht mehr in dT
								*)
								draw:=0;
								IF targetTimeOffsetMsec > 0 THEN
									draw:=(lastT <= targetTimeSecAbs) AND (curT > targetTimeSecAbs); 
								ELSE
									draw:=(lastT <= targetTimeSecAbs) AND (curT >= targetTimeSecAbs);
								END_IF;
//								curTequal:=curT = targetTimeSecAbs; //Korrektur für Bedingung in der inneren While Schleife

								IF curT > targetTimeSecAbs THEN
//									debugDrawCount:=debugDrawCount + 1;
									(*
									Roh-Samples, welche die Roh-Samplingrate um mehr als 5 Sekunden überschreiten werden gezählt
									Es wird mit allen Y=0 gezeichnet
									=Anzahl der Aufzeichnungsunterbrechungen/Stromausfälle
									*)
									timeGapRawSamples:=	curT-lastT;
									IF timeGapRawSamples > (aHead.A.samplingRate + 5) THEN
										c.numSkippedTimeouts:=c.numSkippedTimeouts + 1;
										skip:=1;
									ELSE
										skip:=0;
									END_IF;
									FOR i:=0 TO nTRENDCHANNELS BY 1 DO
										CASE c.selectedTypeY[i] OF
											0: //cI	
												Y2[i]:=curV[c.selectedIndexY[i]];
												Y1[i]:=lastV[c.selectedIndexY[i]];
											1: //cCL	
												Y2[i]:=curV[c.selectedIndexY[i] + cImax];
												Y1[i]:=lastV[c.selectedIndexY[i] + cImax];
											2: //cO
												indexOffset := cImax + cCLmax;
												Y2[i]:=curV[c.selectedIndexY[i] + indexOffset];
												Y1[i]:=lastV[c.selectedIndexY[i] + indexOffset];
											3: //nix
										END_CASE
										//wenn Rohsample im Zeichenbereich, dann autoscalegrenzen prüfen
									
										IF Y2[i] > c.maxPlotted[i] THEN
											c.maxPlotted[i] := Y2[i];
										END_IF;
										IF Y2[i] < c.minPlotted[i] THEN
											c.minPlotted[i] := Y2[i];
										END_IF;
										IF Y1[i] > c.maxPlotted[i] THEN
											c.maxPlotted[i] := Y1[i];
										END_IF;
										IF Y1[i] < c.minPlotted[i] THEN
											c.minPlotted[i] := Y1[i];
										END_IF;
										dY[i]:=Y2[i]-Y1[i];//Differenz der Y über gesamtes RohSamplepaar außerhalb der Schleife vorbereiten
										
									END_FOR;
									(*
									hier erfolgt die eigentliche Plotting schleife zwischen den Roh Samples
									Die Zeiten innerhalb der Plotting-Schleife werden relativ zu lastT gführt und in MSec!!!
									targetTimeOffsetMsec wird als Übertrag in den nächsten Plotting Vorgang verwendet 
									*)
									dT:=timeGapRawSamples * 1000; //Gesamt Rohsampledifferenz in Msec
									//Msec Rest aus letzter Umrechnung von tx + neue relative Position zwischen Roh-Samplepaar Start 
									//und targetTimeSecAbs sind der ertse neue Plotting Zielwert
									tx:=targetTimeOffsetMsec; 
									WHILE  tx < dT DO //interpoliere zwischen den werten 
										FOR i:=0 TO nTRENDCHANNELS BY 1 DO
											IF c.selectedTypeY[i]<3 THEN
												IF skip THEN	//falls Aufzeichnungsunterbrechung
													y[i].item[c.trendSamplesPlotted]:=0;
												ELSE
													y[i].item[c.trendSamplesPlotted]:=Y1[i]+dY[i] * UDINT_TO_REAL(tx) / UDINT_TO_REAL(dT);
												END_IF;
											END_IF;					
										END_FOR
										c.trendSamplesPlotted:=c.trendSamplesPlotted+1;	//Anzahl der der erzeugten Trendzeilen erhöhen
										//ABBRUCH FÜR ENDE des PLOTTING BEREICHS
										tx:=tx+targetTimeIncMsec; //neue relative Zielzeit bilden
										IF c.trendSamplesPlotted > TRENDITEMS  THEN
											tx	:= dT + 1; //Abbruch erzwingen
											c.CMD:=0;		//sofort zurück
											STEP:=BAT_R_STP_wait;
											c.STATUS:=BAT_R_STA_waiting;
										END_IF;
									END_WHILE;
									
									//neue Absolute Zielzeit bilden
									targetTimeSecAbs:=targetTimeSecAbs + (tx/1000);
									//debugTargetTimeSecAbs:=UDINT_TO_DT(targetTimeSecAbs);
									//Modulo der Umrechnung der relativen zielzeit bilden (Msec offset für nächsten Plotting durchgang)
									targetTimeOffsetMsec:=tx MOD 1000;
								END_IF;
							(*
							Es folgt CSV Full 
							jedes gelesen Sample wird ungeprüft in die datei geschrieben
							verwendet nur curY/T	
							*)
							ELSIF c.CMD = BAT_R_CMD_csvFull THEN
								ascDT(aDataA.t,ADR(hlpstr),SIZEOF(hlpstr));
								brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
								buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
								brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
								buflenCSV:= buflenCSV + 1;
								curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.firstDat))/ 3600;
								brsftoa(curAge,ADR(hlpstr));
								//punkt finden und gegen komma austauschen
								fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
								brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
								buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
								//ino age ergänzen
								brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
								buflenCSV:= buflenCSV + 1;
									
								IF aHead.A.inoculumDat = 0 THEN	//kein ino gesetzt
									curAge:=0;
								ELSIF DiffDT(aDataA.t,aHead.A.inoculumDat) = 4294967295 THEN //vor ino negative age generieren	
									curAge:=UDINT_TO_REAL(DiffDT(aHead.A.inoculumDat,aDataA.t))/ 3600 * -1;
								ELSE
									curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.inoculumDat))/ 3600;	
								END_IF;
								brsftoa(curAge,ADR(hlpstr));
								//punkt finden und gegen komma austauschen
								fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
								brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
								buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
										
								FOR i:= 0 TO (allChannelsMax - 1) BY 1 DO 
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
									buflenCSV:= buflenCSV + 1;
									brsftoa(curV[i],ADR(hlpstr));
									fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
									buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
								END_FOR;		
								brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
								buflenCSV:= buflenCSV + 2;
								c.CSVlinesWritten:=c.CSVlinesWritten+1;
							(*
							Es folgt CSVSmall 
							jedes gelesene Sample wird ungeprüft in die datei geschrieben
							allerdings nur die samples im Zielzeitbereich und nur die gewälten achsen	
							*)
							ELSIF c.CMD = BAT_R_CMD_csvSmall THEN
								//Zeit der Rohdatenzeile hat auswahlzeitbereich überschritten
								IF curT > (DT_TO_UDINT(c.offset) + c.range) THEN 
									c.STATUS:=BAT_R_STA_closing;// CSV Puffer schreiben und alles abschließen 
									STEP:=BAT_R_STP_writeCSV;
								//Zeit der Rohzeile muss aber auch erstmal drin sein im Auswahlbereich
								ELSIF (DT_TO_UDINT(aDataA.t)>=targetTimeSecAbs)	THEN
									FOR i:=0 TO nTRENDCHANNELS BY 1 DO
										CASE c.selectedTypeY[i] OF
										0: //cI	
										Y2[i]:=curV[c.selectedIndexY[i]];
										1: //cCL	
										Y2[i]:=curV[c.selectedIndexY[i] + cImax];	
										2: //cO
										indexOffset := cImax + cCLmax;
										Y2[i]:=curV[c.selectedIndexY[i] + indexOffset];
										3: //nix
										END_CASE	
									END_FOR;
									targetTimeSecAbs:=DT_TO_UDINT(aDataA.t)+1; //damit auch schön jede weitere zeile geschrieben wird
									ascDT(aDataA.t,ADR(hlpstr),SIZEOF(hlpstr));
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
									buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
									buflenCSV:= buflenCSV + 1;
									curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.firstDat))/ 3600;
									brsftoa(curAge,ADR(hlpstr));
									//punkt finden und gegen komma austauschen
									fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));;
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
									buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
										
									//ino age ergänzen
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
									buflenCSV:= buflenCSV + 1;
									
									IF aHead.A.inoculumDat = 0 THEN	//kein ino gesetzt
										curAge:=0;
									ELSIF DiffDT(aDataA.t,aHead.A.inoculumDat) = 4294967295 THEN //vor ino negative age generieren	
										curAge:=UDINT_TO_REAL(DiffDT(aHead.A.inoculumDat,aDataA.t))/ 3600 * -1;
									ELSE
										curAge:=UDINT_TO_REAL(DiffDT(aDataA.t,aHead.A.inoculumDat))/ 3600;	
									END_IF;
									brsftoa(curAge,ADR(hlpstr));
									//punkt finden und gegen komma austauschen
									fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
									buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));
	
									FOR i:=0 TO nTRENDCHANNELS BY 1 DO
											
										IF c.selectedTypeY[i]<3 THEN
											brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(SEMI),1);
											buflenCSV:= buflenCSV + 1;

											brsftoa(Y2[i],ADR(hlpstr));
											fReplaceChar(46,44,UDINT_TO_INT(SIZEOF(hlpstr)),ADR(hlpstr));

											brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(hlpstr),brsstrlen(ADR(hlpstr)));
											buflenCSV:= buflenCSV + brsstrlen(ADR(hlpstr));

										END_IF;	
									END_FOR;	
									brsmemcpy(ADR(bufCSV)+buflenCSV,ADR(CRLF),2);
									buflenCSV:= buflenCSV + 2;
									c.CSVlinesWritten:=c.CSVlinesWritten+1;		
								END_IF;
							END_IF;
							lastV:=curV;		//alte Datenzeile verwerfen und auf neue setzen für alle kommandos
							lastT:=curT;
							c.percentRead:=UDINT_TO_USINT(((offsetTrendFile + bufReadTrend) * 100) / c.lastFileOpenLen);
						END_IF								
					END_IF;	
				END_IF;

				IF (STEP = BAT_R_STP_unzip) AND (c.CMD <> BAT_R_CMD_trend)THEN		
					IF  buflenCSV + MAX_CHAR_CSV_ROW > CSV_W_BUFSIZE  	THEN //Puffer füer CSV output komplett gefüllt
						//c.STATUS:=BAT_R_STA_newCSVfile;
						STEP:=BAT_R_STP_writeCSV;//CSV Puffer schreiben, direkt zurückkehren, dazu Status auf unzipping halten
					ELSIF c.CSVlinesWritten + 1 > MAX_LINES_CSV THEN //maximale CSV Zeilenzahl erreicht	
						c.STATUS:=BAT_R_STA_newCSVfile;//CSV Puffer schreiben und neue CSV Datei anfordern, dann zurückkehren
						STEP:=BAT_R_STP_writeCSV;

					END_IF;
					//Anmerkung:		wenn beides eintritt wird halt einmal ein leere puffer geschrieben bevor eine neue date erzeugt wird
				END_IF;
				
			END_WHILE
		
		BAT_R_STP_writeCSV:
			
			FileWriteEx_0.enable:=1;
			FileWriteEx_0.ident:=identCSV;
			FileWriteEx_0.len:=buflenCSV;
			FileWriteEx_0.offset:=offsetCSVFile;
			FileWriteEx_0.option:=0;
			FileWriteEx_0.pSrc:=ADR(bufCSV);
	
			IF FileWriteEx_0.status <> ERR_FUB_BUSY AND FileWriteEx_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FileWriteEx_0.status = ERR_OK THEN
					CASE c.STATUS OF
						//Datei Abschließen
						BAT_R_STA_closing, BAT_R_STA_newCSVfile:
							offsetCSVFile:=0;	//für neue CSV Datei nach max. Zeilenlänge, offset 0 setzen
							STEP:=BAT_R_STP_closeCSV;
						BAT_R_STA_unzipping:  	
							offsetCSVFile:=offsetCSVFile+buflenCSV;	//für einfaches Puffer leeren, offset für nächstes schreiben erhöhen
							STEP:=BAT_R_STP_unzip; //direkt weiter zum entpacken in nächstes Pufferpaket
						ELSE
					END_CASE;
						
					offsetCSVFile:=offsetCSVFile+buflenCSV;		//Offset in CSV um geschriebene Bytes erhöhen
					buflenCSV:=0;						//Anzahl der aufbereiteten Bytes zurücksetzen
				ELSE
					c.error.errorFub:=FileWriteEx_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unhandled error while writing CSV';
					c.error.errorSta:=c.STATUS;
					STEP:=BAT_R_STP_closeCSV;
					c.STATUS:=BAT_R_STA_closingError;
				END_IF;	
				FileWriteEx_0.enable:=0;
			END_IF;	
			
		BAT_R_STP_closeCSV:	
			
			FileClose_0.enable:=1;
			FileClose_0.ident:=identCSV;
			
			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
				CASE c.STATUS OF
					BAT_R_STA_closingAbort:
						c.error.errorFub:=FileClose_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='user abort';
						c.error.errorSta:=c.STATUS;		
						STEP:=BAT_R_STP_wait;
						c.STATUS:=BAT_R_STA_error;
						c.CMD:=0;
						
					BAT_R_STA_closingError:
						STEP:=BAT_R_STP_wait;
						c.STATUS:=BAT_R_STA_error;
						c.CMD:=0;
					
					BAT_R_STA_closing:
						STEP:=BAT_R_STP_wait;
						c.STATUS:=BAT_R_STA_waiting;
						c.CMD:=0;
					
					BAT_R_STA_newCSVfile:
						STEP:=BAT_R_STP_createCSV;	//neue datei öffnen
						
					ELSE
						c.error.errorFub:=FileClose_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='unknown STA while closing CSV';
						c.error.errorSta:=c.STATUS;		
						
						STEP:=BAT_R_STP_wait;
						c.STATUS:=BAT_R_STA_error;
						c.CMD:=0;
				END_CASE;				
				FileClose_0.enable:=0;
			END_IF;					

		ELSE	
			c.error.errorFub:=0;
			c.error.errorStep:=STEP;
			c.error.errorString:='unknown STP in Main Case';
			c.error.errorSta:=c.STATUS;
			
			c.STATUS:=BAT_R_STA_error;
			STEP:=BAT_R_STP_wait;
	END_CASE
	
	DirCreate_0();
	FileOpen_0();
	FileWriteEx_0();
	FileClose_0();
	FileCreate_0();
	
END_FUNCTION_BLOCK


(*   ############### fTrendWrite
	- schreibt Trenddatei
	- erstellt beim start mit AT ebenfalls die Eventsdatei
	- leert eventpuffer unabhängig von trendzykluszeit alle 5 sekunden in die trenddatei, falls events da sind
	- beim abschluss wird Trend/eventdatei ein letztes mal geschrieben
	- es wird nur jeweils eine instanz der fileio fubs verwendet

*)
FUNCTION_BLOCK fTrendWrite
	
	//hilfs FUB zum speichern von letzter stepfolge
	IF STEP <> stack.in THEN
		stack(in:=STEP);
	END_IF;
	
	CASE STEP OF
	
		BAT_W_STP_init:			//nur bei erstem aufruf
			
			IF enable THEN						
				STEP:=BAT_W_STP_open;
				c.STATUS:=BAT_W_STA_initializing;
				c.error.openerrors:=0;
				aRem ACCESS pRem;
				aNon ACCESS pNon;
				ebuf ACCESS pATbuf;	
			END_IF;
		
		BAT_W_STP_wait:			//Idle schritt, routet CMD und timer in die Schritte
		
			IF NOT enable THEN //neu: calls mit not enable, warten auf sicheren Dateizustand und zwingen den FUB in den Zustand bei start der SPS bis zum erneuten enable
				STEP:=0;
				c.STATUS:=0;
			ELSIF c.STATUS = BAT_W_STA_waiting OR c.STATUS = BAT_W_STA_error  THEN
				IF c.CMD = BAT_W_CMD_start THEN
					c.STATUS:=BAT_W_STA_starting;
					lastPop:=DT_TO_UDINT(time);
					STEP:=BAT_W_STP_dir;
					c.eventsInFile:=0;
					IF bufh_in.A.samplingRate=0 THEN /////!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
						bufh_in.A.samplingRate:=1;
					END_IF;
				END_IF;	
			ELSIF c.STATUS=BAT_W_STA_recording THEN	
				IF freeMem < 1024 OR c.CMD = BAT_W_CMD_stop THEN //Abschaltung bei zu wenig speicher oder stop befehl
					c.STATUS:=BAT_W_STA_stopping;
					STEP:=BAT_W_STP_open;
				ELSIF (*TON_0.Q*) (DT_TO_UDINT(time) - DT_TO_UDINT(bufh_out.A.lastDat))>= c.info.samplingRate THEN //Zeitstempel > c.info.samplingRate THEN
					STEP:=BAT_W_STP_open;	
				//hier zeitlich unabhängiges anrollen des Eventpuffer leerens, alle 5 sekunden
				ELSIF bufh_in.A.isAT <> 0 THEN
					IF (ebuf.firstPushed = ebuf.nextPush) THEN
						eventsToPop:=0;
					ELSIF ebuf.firstPushed > ebuf.nextPush THEN
						eventsToPop := TRAIL_ENTRIES - ebuf.firstPushed + 1 + ebuf.nextPush;
					ELSE
						eventsToPop := ebuf.nextPush - ebuf.firstPushed;
					END_IF;		
					IF	eventsToPop > 0 AND ((DT_TO_UDINT(time) - lastPop)>= 5) THEN
						lastPop:=DT_TO_UDINT(time);
						STEP:=EVENT_W_STP_open;	
					END_IF;
				END_IF;	
				
				//####################hier einstieg für laufendes Füllen von EVENTdatei
				
			END_IF;	
				
		BAT_W_STP_open:	
			
			IF  FileOpen_0.enable=0 THEN
				FileOpen_0.enable:=1;
				FileOpen_0.mode:=fiREAD_WRITE;
				FileOpen_0.pDevice:=ADR(LOCALDEVICE);
				brsitoa(USINT_TO_DINT(indexUnit),ADR(hlpstr));
				hlpstr:=CONCAT('web/plcfile/TREND',hlpstr);
				hlpstr:=CONCAT(hlpstr,'/');
				hlpstr:=CONCAT(hlpstr,filename);
				hlpstr:=CONCAT(hlpstr,'.TREND');
				FileOpen_0.pFile:=ADR(hlpstr);
			END_IF;			
			IF FileOpen_0.status <> ERR_FUB_BUSY AND FileOpen_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FileOpen_0.status = fiERR_FILE_NOT_FOUND THEN
					IF c.STATUS = BAT_W_STA_initializing  THEN
						STEP:=BAT_W_STP_close;//bei erstinitialisierung, wenn noch keine trend datei besteht nichts tun
					ELSE
						c.error.errorFub:=FileOpen_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='file dissapeared unexpectedly';
						c.error.errorSta:=c.STATUS;
						c.STATUS:=BAT_W_STA_error;
						c.CMD:=0;
						STEP:=BAT_W_STP_wait;
					END_IF;	
				ELSIF	FileOpen_0.status <> ERR_OK THEN                   
					
//					obsolet, test bei 1103 zeigen, das selbst bei Speicherfresser keine retries mehr ausgeführt werden
//					IF c.error.openerrors < MAXRETRIES THEN
//						c.error.openerrors:=c.error.openerrors + 1 ;
//						STEP:=BAT_W_STP_openretry;
//						fileIdent:=FileOpen_0.ident;
//						c.error.openErrorCode:=FileOpen_0.status;
//					ELSE
						c.error.openerrors:=0;
						c.error.errorFub:=FileOpen_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='unhandled error while tr. open';
						c.error.errorSta:=c.STATUS;
						c.STATUS:=BAT_W_STA_error;
						c.CMD:=0;
						STEP:=BAT_W_STP_wait;
				//	END_IF;
				ELSE 
					countOpenRaw:=countOpenRaw+1;
					c.error.openerrors:=0;
					fileIdent:=FileOpen_0.ident;
					fileOpenLen:=FileOpen_0.filelen;
				
					CASE c.STATUS OF 
						
						BAT_W_STA_initializing, BAT_W_STA_recording, BAT_W_STA_stopping:
							
							IF fileOpenLen <> 0 THEN 
								STEP:=BAT_W_STP_read_header;
							ELSE		//datei zwar da aber leer
								c.error.errorFub:=FileOpen_0.status;
								c.error.errorStep:=STEP;
								c.error.errorString:='file empty';
								c.error.errorSta:=c.STATUS;
								STEP:=BAT_W_STP_error;
							END_IF;
							
						ELSE
							
							c.error.errorFub:=FileOpen_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='unhandled STA while open';
							c.error.errorSta:=c.STATUS;
							STEP:=BAT_W_STP_error;	
					END_CASE
				END_IF;
				FileOpen_0.enable:=0;
			END_IF
			
		EVENT_W_STP_open:	
			
			IF  FileOpen_0.enable=0 THEN
				FileOpen_0.enable:=1;
				FileOpen_0.mode:=fiREAD_WRITE;
				FileOpen_0.pDevice:=ADR(LOCALDEVICE);
				brsitoa(USINT_TO_DINT(indexUnit),ADR(hlpstr));
				hlpstr:=CONCAT('web/plcfile/EVENTS',hlpstr);
				hlpstr:=CONCAT(hlpstr,'/');
				hlpstr:=CONCAT(hlpstr,filename);
				hlpstr:=CONCAT(hlpstr,'.EVENT');
				FileOpen_0.pFile:=ADR(hlpstr);
			END_IF;			
			IF FileOpen_0.status <> ERR_FUB_BUSY AND FileOpen_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FileOpen_0.status = fiERR_FILE_NOT_FOUND THEN
					c.error.errorFub:=FileOpen_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='eventfile dissapeared unexpectedly';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				ELSIF	FileOpen_0.status <> ERR_OK THEN                   
					c.error.openerrors:=0;
					c.error.errorFub:=FileOpen_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unhandled error while open eventfile';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				ELSE 
					countOpenRaw:=countOpenRaw+1;
					c.error.openerrors:=0;
					fileIdentEvent:=FileOpen_0.ident;
					fileOpenLenEvent:=FileOpen_0.filelen;
				
					CASE c.STATUS OF 
						
						BAT_W_STA_recording, BAT_W_STA_stopping:
							
							IF fileOpenLenEvent <> 0 THEN 
								STEP:=EVENT_W_STP_read_header;
							ELSE		//datei zwar da aber leer
								c.error.errorFub:=FileOpen_0.status;
								c.error.errorStep:=STEP;
								c.error.errorString:='eventfile empty';
								c.error.errorSta:=c.STATUS;
								STEP:=BAT_W_STP_error;
							END_IF;	
						ELSE
							c.error.errorFub:=FileOpen_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='unhandled STA while open eventfile';
							c.error.errorSta:=c.STATUS;
							STEP:=BAT_W_STP_error;	
					END_CASE
				END_IF;
				FileOpen_0.enable:=0;
			END_IF

//		BAT_W_STP_openretry:	//routet auf open für retries
//			
//			FileClose_0.enable:=1;
//			FileClose_0.ident:=fileIdent;
//			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
//				FileClose_0.enable:=0;
//				STEP:=BAT_W_STP_open;
//			END_IF;
			
		BAT_W_STP_dir:
			
			IF DirCreate_0.enable=0 THEN
				DirCreate_0.enable:=1;
				DirCreate_0.pDevice:=ADR(LOCALDEVICE);
				brsitoa(USINT_TO_DINT(indexUnit),ADR(hlpstr));
				hlpstr:=CONCAT('web/plcfile/TREND',hlpstr);
				DirCreate_0.pName:=ADR(hlpstr);
			END_IF;
			IF DirCreate_0.status <> ERR_FUB_BUSY AND DirCreate_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF DirCreate_0.status = ERR_OK OR DirCreate_0.status = fiERR_DIR_ALREADY_EXIST THEN
					IF c.isAT THEN
						STEP:=EVENT_W_STP_dir;	
					ELSE	
						STEP:=BAT_W_STP_create;	
					END_IF;
				ELSE
					c.error.errorFub:=DirCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unhandled error while creating trend dir';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				END_IF;	
				DirCreate_0.enable:=0;
			END_IF;
			
		EVENT_W_STP_dir: //erstellen des EVENT Ordners
			
			IF DirCreate_0.enable=0 THEN
				DirCreate_0.enable:=1;
				DirCreate_0.pDevice:=ADR(LOCALDEVICE);
				brsitoa(USINT_TO_DINT(indexUnit),ADR(hlpstr));
				hlpstr:=CONCAT('web/plcfile/EVENTS',hlpstr);
				DirCreate_0.pName:=ADR(hlpstr);
			END_IF;
			IF DirCreate_0.status <> ERR_FUB_BUSY AND DirCreate_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF DirCreate_0.status = ERR_OK OR DirCreate_0.status = fiERR_DIR_ALREADY_EXIST THEN
					STEP:=BAT_W_STP_create;	
				ELSE
					c.error.errorFub:=DirCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unhandled error while creating events dir';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				END_IF;	
				DirCreate_0.enable:=0;
			END_IF;
			
		BAT_W_STP_create:		//bei start neue datei im TREND verzeichnis erstellen
			
			IF FileCreate_0.enable=0 THEN
				FileCreate_0.enable:=1;
				FileCreate_0.pDevice:=ADR(LOCALDEVICE);
				brsitoa(USINT_TO_DINT(indexUnit),ADR(hlpstr));
				hlpstr:=CONCAT('web/plcfile/TREND',hlpstr);
				hlpstr:=CONCAT(hlpstr,'/');
				hlpstr:=CONCAT(hlpstr,filename);
				hlpstr:=CONCAT(hlpstr,'.TREND');
				FileCreate_0.pFile:=ADR(hlpstr);
			END_IF;
									
			IF FileCreate_0.status <> ERR_FUB_BUSY AND FileCreate_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileCreate_0.status = fiERR_EXIST THEN
					c.error.errorFub:=FileCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='trend file exists already';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				ELSIF	FileCreate_0.status <> ERR_OK THEN
					c.error.errorFub:=FileCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unh.err.cr. trendfile: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				ELSE
					fileIdent:=FileCreate_0.ident;
					fileOpenLen:=0;
					CASE c.STATUS OF 
			
						BAT_W_STA_starting:
							IF c.isAT THEN
								STEP:=EVENT_W_STP_create;
							ELSE
								STEP:=BAT_W_STP_write_header;		
							END_IF;
						ELSE
							c.error.errorFub:=FileCreate_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='unhandled STA while creating trendfile';
							c.error.errorSta:=c.STATUS;
							c.STATUS:=BAT_W_STA_error;
							c.CMD:=0;
							STEP:=BAT_W_STP_wait;	
					END_CASE		
				END_IF
				FileCreate_0.enable:=0;
			END_IF;	
		
		EVENT_W_STP_create: //bei start neue datei im EVENT verzeichnis erstellen
			
			IF FileCreate_0.enable=0 THEN
				FileCreate_0.enable:=1;
				FileCreate_0.pDevice:=ADR(LOCALDEVICE);
				brsitoa(USINT_TO_DINT(indexUnit),ADR(hlpstr));
				hlpstr:=CONCAT('web/plcfile/EVENTS',hlpstr);
				hlpstr:=CONCAT(hlpstr,'/');
				hlpstr:=CONCAT(hlpstr,filename);
				hlpstr:=CONCAT(hlpstr,'.EVENT');
				FileCreate_0.pFile:=ADR(hlpstr);
			END_IF;
									
			IF FileCreate_0.status <> ERR_FUB_BUSY AND FileCreate_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileCreate_0.status = fiERR_EXIST THEN
					c.error.errorFub:=FileCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='event file exists already';
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				ELSIF	FileCreate_0.status <> ERR_OK THEN
					c.error.errorFub:=FileCreate_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unh.err.creating event file: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
					c.error.errorSta:=c.STATUS;
					c.STATUS:=BAT_W_STA_error;
					c.CMD:=0;
					STEP:=BAT_W_STP_wait;
				ELSE
					fileIdentEvent:=FileCreate_0.ident;
					fileOpenLenEvent:=0;
					CASE c.STATUS OF 
			
						BAT_W_STA_starting:
	
							STEP:=EVENT_W_STP_write_first;		
							
						ELSE
							c.error.errorFub:=FileCreate_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='unhandled STA while creating eventfile';
							c.error.errorSta:=c.STATUS;
							c.STATUS:=BAT_W_STA_error;
							c.CMD:=0;
							STEP:=BAT_W_STP_wait;	
					END_CASE		
				END_IF
				FileCreate_0.enable:=0;
			END_IF;	
			
		EVENT_W_STP_read_header: // öffnet event header

			IF FileReadEx_0.enable=0 THEN
				FileReadEx_0.enable:=1;
				FileReadEx_0.ident:=fileIdentEvent;
				FileReadEx_0.len:=SIZEOF(bufh_event_in);
				FileReadEx_0.offset:=0;
				FileReadEx_0.pDest:=ADR(bufh_event_in);
			END_IF;
			
			IF FileReadEx_0.status <> ERR_FUB_BUSY AND FileReadEx_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileReadEx_0.status <> ERR_OK THEN
					c.error.errorFub:=FileReadEx_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unh.err.r.eh.: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
					STEP:=EVENT_W_STP_error;
				ELSE
					//fehlerüberprüfungen im header
					IF CRC32(SIZEOF(bufh_event_in)-4,ADR(bufh_event_in),BATCH_GENERATOR) <> bufh_event_in.crcHeader THEN
						c.error.errorFub:=ERR_OK;
						c.error.errorStep:=STEP;
						debug1:=CRC32(SIZEOF(bufh_event_in)-4,ADR(bufh_event_in),BATCH_GENERATOR);
						c.error.errorString:='Header E corrupted (CRC32)';
						STEP:=EVENT_W_STP_error;
					ELSE
						
						CASE c.STATUS OF

							BAT_W_STA_stopping,BAT_W_STA_recording:	
								
								STEP:=EVENT_W_STP_write_header;
							
							ELSE
								c.error.errorFub:=FileReadEx_0.status;
								c.error.errorStep:=STEP;
								c.error.errorString:='unhandled STA while E-Header read';
								c.error.errorSta:=c.STATUS;
								STEP:=EVENT_W_STP_error;	
						END_CASE
												
					END_IF;
				END_IF
				FileReadEx_0.enable:=0;
			END_IF;	
					
		BAT_W_STP_read_header:  // to do tag comment und sampling rate in control struktur übergeben 
			
			IF FileReadEx_0.enable=0 THEN
				FileReadEx_0.enable:=1;
				FileReadEx_0.ident:=fileIdent;
				FileReadEx_0.len:=SIZEOF(bufh_in);
				FileReadEx_0.offset:=0;
				FileReadEx_0.pDest:=ADR(bufh_in);
			END_IF;
			
			IF FileReadEx_0.status <> ERR_FUB_BUSY AND FileReadEx_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileReadEx_0.status <> ERR_OK THEN
					c.error.errorFub:=FileReadEx_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unh.err.r.h.: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
					STEP:=BAT_W_STP_error;
				ELSE
					//diverse fehlerüberprüfungen im header
					IF CRC32(SIZEOF(bufh_in.A),ADR(bufh_in.A),BATCH_GENERATOR) <> bufh_in.CRC_A THEN
						c.error.errorFub:=ERR_OK;
						c.error.errorStep:=STEP;
						c.error.errorString:='Header A corrupted (CRC32)';
						STEP:=BAT_W_STP_error;
//					ELSIF bufh_in.A.version <> BATCH_VERSION THEN
//						c.error.errorFub:=ERR_OK;
//						c.error.errorStep:=STEP;
//						c.error.errorString:='wrong version';
//						STEP:=BAT_W_STP_error;
//					ELSIF bufh_in.A.anzcI <> ncI OR bufh_in.A.anzcO <> ncO OR bufh_in.A.anzcCL <> ncCL OR bufh_in.A.ident <> BATCHIDENT THEN
//						c.error.errorFub:=ERR_OK;
//						c.error.errorStep:=STEP;
//						c.error.errorString:='configuration doesnt fit';
//						STEP:=BAT_W_STP_error;
					ELSIF CRC32(SIZEOF(bufh_in.B) - 8,ADR(bufh_in.B),BATCH_GENERATOR) <> bufh_in.B.CRC_B THEN
						c.error.errorFub:=ERR_OK;
						c.error.errorStep:=STEP;
						c.error.errorString:='Header B corrupted (CRC32)';
						STEP:=BAT_W_STP_error;
					ELSE
						
						CASE c.STATUS OF

							BAT_W_STA_initializing:
							
								
								IF bufh_in.A.batchState = BATCH_STARTED THEN	//nach neustart fortsetzen
									STEP:=BAT_W_STP_write_header; 
									c.comment:=bufh_in.A.comment;
									c.samplingRate:=bufh_in.A.samplingRate;    		//einmal den kommentar und die sampling rate aus dem trendfile holen und im gesperrrten startparamtern anzeigen
								
									IF bufh_in.A.isAT <> 0 THEN 
										e.ID:=14; //reboot event absetzen
										e.dat:=time;
										debug:=1;
										addEvent(TRUE,pATbuf,e);	
									END_IF;
								ELSE
									STEP:=BAT_W_STP_close;
								END_IF;
	
							BAT_W_STA_stopping,BAT_W_STA_recording:	
								
								STEP:=BAT_W_STP_write_header;
							
							ELSE
								c.error.errorFub:=FileReadEx_0.status;
								c.error.errorStep:=STEP;
								c.error.errorString:='unhandled STA while Header read';
								c.error.errorSta:=c.STATUS;
								STEP:=BAT_W_STP_error;	
						END_CASE
												
					END_IF;
				END_IF
				FileReadEx_0.enable:=0;
			END_IF;	
		
		
		
		
		EVENT_W_STP_write_first:  //schreibt ersten event header beim start des AT
		
			IF FileWrite_0.enable = 0 THEN	
				bufh_event_out.deviceident:=BATCHIDENT;
				bufh_event_out.maxBufCount:=0;
				bufh_event_out.maxBufSize:=0;
				bufh_event_out.records:=0;
				bufh_event_out.crcHeader:=CRC32(SIZEOF(bufh_event_out) - 4,ADR(bufh_event_out),BATCH_GENERATOR);
			
				FileWrite_0.offset:=0;
				FileWrite_0.len:=SIZEOF(bufh_event_out);
				FileWrite_0.pSrc:=ADR(bufh_event_out);
				FileWrite_0.enable:=1;
				FileWrite_0.ident:=fileIdentEvent;
			END_IF;
			
			IF FileWrite_0.status <> ERR_FUB_BUSY AND FileWrite_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FileWrite_0.status <> ERR_OK THEN
					c.error.errorFub:=FileWrite_0.status;
					c.error.errorStep:=STEP;
					STEP:=BAT_W_STP_error;
					c.error.errorString:='unh.err.wr.1st ev.hd: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
				ELSE
					
					CASE c.STATUS OF
						
						BAT_W_STA_starting:
						
							//STEP:=BAT_W_STP_write_header;
							STEP:=EVENT_W_STP_closeRec;
									
						ELSE
							
							c.error.errorFub:=FileWrite_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='unhandled STA while 1st ev.hd write';
							c.error.errorSta:=c.STATUS;
							STEP:=BAT_W_STP_error;
					END_CASE
					
				END_IF
				FileWrite_0.enable:=0;
			END_IF;	
		
		BAT_W_STP_write_header:		//schreibt trend header und legt trend datenzeile an
		
			IF FileWrite_0.enable = 0 THEN	
				CASE c.STATUS OF

					BAT_W_STA_starting://header neu erstellen und 1. Zeile komplett schreiben
						lastFullSample:=DT_TO_UDINT(time);
						bufh_out.A.ident:=BATCHIDENT;
						bufh_out.A.isAT:=c.isAT;  //AT flag ersetzt unbenutzte versionsinfo
						bufh_out.A.anzcI:=aNon.lastValidcI;
						bufh_out.A.anzcCL:=aNon.lastValidcCL; 
						bufh_out.A.anzcO:=aNon.lastValidcO;
						IF c.samplingRate=0 THEN
							c.samplingRate:=10;
						END_IF;
						bufh_out.A.samplingRate:=c.samplingRate;
						bufh_out.A.treshold;//obsolet
						bufh_out.A.tag:=filename;
						bufh_out.A.comment:=c.comment;			
						bufh_out.A.batchState:=BATCH_STARTED;
						bufh_out.A.firstDat:=time;
						bufh_out.A.lastDat:=time;
						bufh_out.A.lineCount:=1;
						bufh_out.A.inoculumDat:=0;
						bufh_out.CRC_A:=CRC32(SIZEOF(bufh_out.A),ADR(bufh_out.A),BATCH_GENERATOR);
						FOR i:= 0 TO ncI BY 1 DO 
							bufh_out.B.tags.cI[i]:=aNon.cI[i].tag;
							bufh_out.B.units.cI[i]:=aNon.cI[i].unitStr;
							fMakeTrendData_0.stack.cI[i]:=aNon.cI[i].in;
						END_FOR;
						FOR i:= 0 TO ncO BY 1 DO
							bufh_out.B.tags.cO[i]:=aNon.cO[i].tag;
							bufh_out.B.units.cO[i]:=aNon.cO[i].unitStr;
							fMakeTrendData_0.stack.cO[i]:=aRem.cO[i].out;
						END_FOR;
						FOR i:=0 TO ncCL BY 1 DO
							bufh_out.B.tags.cCL[i]:=aNon.cCL[i].tag;
							bufh_out.B.units.cCL[i]:=aNon.cCL[i].unitStr;
							fMakeTrendData_0.stack.cCL[i]:=aRem.cCL[i].W;
						END_FOR;
						bufh_out.B.CRC_B:=CRC32(SIZEOF(bufh_out.B) - 8,ADR(bufh_out.B),BATCH_GENERATOR);
						fMakeTrendData_0.new:=1;
											
					ELSE//BAT_W_STA_initializing,BAT_W_STA_stopping,BAT_W_STA_recording:
						
						//c.isAT:=bufh_in.A.isAT<>0; //bei laufendem trend isAt in Kontrollstruktur übernhemen
						bufh_out:=bufh_in;		//pauschal erstmal alles übernehmen
						
						IF c.STATUS = BAT_W_STA_stopping THEN 
							bufh_out.A.batchState:=BATCH_FINALIZED;
						ELSE
							bufh_out.A.batchState:=BATCH_STARTED;
						END_IF;	
						
						IF c.inoculate AND c.STATUS=BAT_W_STA_recording THEN
							c.inoculate:=0;
							IF bufh_out.A.inoculumDat = 0 THEN		//spätere inoculumtrigger werden ignoriert
								bufh_out.A.inoculumDat:=time;
							END_IF;
						END_IF;
					
						bufh_out.A.lastDat:=time;
					
						bufh_out.A.lineCount:=bufh_in.A.lineCount+1;
		
						bufh_out.CRC_A:=CRC32(SIZEOF(bufh_out.A),ADR(bufh_out.A),BATCH_GENERATOR);
		
						FOR i:= 0 TO ncI BY 1 DO 
							fMakeTrendData_0.stack.cI[i]:=aNon.cI[i].in;
						END_FOR;	
						FOR i:= 0 TO ncO BY 1 DO 
							fMakeTrendData_0.stack.cO[i]:=aRem.cO[i].out;
						END_FOR;
						FOR i:=0 TO ncCL BY 1 DO
							fMakeTrendData_0.stack.cCL[i]:=aRem.cCL[i].W;
						END_FOR;	
				
						fMakeTrendData_0.new:=c.STATUS <> BAT_W_STA_recording; //nur logging komprimieren, also bei init und stopping volle datenzeile
						//automatisch nach 10 minuten ein volles sample schreiben
						IF (DT_TO_UDINT(time) - lastFullSample) > 600 THEN
							fMakeTrendData_0.new:=1;
							lastFullSample:=DT_TO_UDINT(time);
						END_IF;
						
				END_CASE
				fMakeTrendData_0.time:=time;
				fMakeTrendData_0.ncCLthis:=aNon.lastValidcCL;
				fMakeTrendData_0.ncIthis:=aNon.lastValidcI;
				fMakeTrendData_0.ncOthis:=aNon.lastValidcO;
				fMakeTrendData_0();
				
				FileWrite_0.offset:=0;
				FileWrite_0.len:=SIZEOF(bufh_out);
				FileWrite_0.pSrc:=ADR(bufh_out);
				FileWrite_0.enable:=1;
				FileWrite_0.ident:=fileIdent;
			END_IF;
			
			IF FileWrite_0.status <> ERR_FUB_BUSY AND FileWrite_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FileWrite_0.status <> ERR_OK THEN
					c.error.errorFub:=FileWrite_0.status;
					c.error.errorStep:=STEP;
					STEP:=BAT_W_STP_error;
					c.error.errorString:='unh.err.wr.h.: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
				ELSE
					
					CASE c.STATUS OF
						
						BAT_W_STA_initializing,BAT_W_STA_stopping, BAT_W_STA_recording:
							
							STEP:=BAT_W_STP_get_offset;
						
						BAT_W_STA_starting:
						
							STEP:=BAT_W_STP_write_data;
									
						ELSE
							
							c.error.errorFub:=FileWrite_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='unhandled STA while Header write';
							c.error.errorSta:=c.STATUS;
							STEP:=BAT_W_STP_error;
					END_CASE
					
				END_IF
				FileWrite_0.enable:=0;
			END_IF;	
			
		EVENT_W_STP_write_header:		//schreibt E header und legt E Datenblock an
		
			IF FileWrite_0.enable = 0 THEN	
				
				bufh_event_out:=bufh_event_in; //erstmal alles übernehmen
			
				//hier fMakeEventData ausführen
				fMakeEventData_0.pATbuf:=pATbuf;
				fMakeEventData_0.time:=time;
				fMakeEventData_0();
				IF bufh_event_out.maxBufSize < fMakeEventData_0.offset THEN//falls datengröße größer als im alten header dann neu stezne
					bufh_event_out.maxBufSize := fMakeEventData_0.offset;
				END_IF;
				IF bufh_event_out.maxBufCount < eventsToPop THEN //anzahl der gelesenen Events bei Bedarf erhöhen
					bufh_event_out.maxBufCount := eventsToPop; 
				END_IF; 
				bufh_event_out.records:=bufh_event_out.records + eventsToPop;	//records hochzählen
				bufh_event_out.crcHeader:=CRC32(SIZEOF(bufh_event_out)-4,ADR(bufh_event_out),BATCH_GENERATOR);
					
				FileWrite_0.offset:=0;
				FileWrite_0.len:=SIZEOF(bufh_event_out);
				FileWrite_0.pSrc:=ADR(bufh_event_out);
				FileWrite_0.enable:=1;
				FileWrite_0.ident:=fileIdentEvent;
			END_IF;
			
			IF FileWrite_0.status <> ERR_FUB_BUSY AND FileWrite_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FileWrite_0.status <> ERR_OK THEN
					c.error.errorFub:=FileWrite_0.status;
					c.error.errorStep:=STEP;
					STEP:=BAT_W_STP_error;
					c.error.errorString:='unh.err.wr.eh.: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
				ELSE
					
					CASE c.STATUS OF
						
						BAT_W_STA_stopping, BAT_W_STA_recording:
							
							STEP:=EVENT_W_STP_get_offset;
									
						ELSE
							
							c.error.errorFub:=FileWrite_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='unhandled STA while E-Header write';
							c.error.errorSta:=c.STATUS;
							STEP:=BAT_W_STP_error;
					END_CASE
					
				END_IF
				FileWrite_0.enable:=0;
			END_IF;	
		
		BAT_W_STP_get_offset:	//bestimmt offset korrektur für anhängen der datenzeile
			
			IF FileReadEx_0.enable=0 THEN
				FileReadEx_0.enable:=1;
				FileReadEx_0.ident:=fileIdent;
			
				IF fileOpenLen < (BATCH_OFFSETSEARCH + 1) THEN
					FileReadEx_0.offset:=0;
					FileReadEx_0.len:=fileOpenLen;
				ELSE
					FileReadEx_0.offset:=fileOpenLen - BATCH_OFFSETSEARCH - 1;
					FileReadEx_0.len:=BATCH_OFFSETSEARCH +1;
				END_IF;	
				FileReadEx_0.pDest:=ADR(bufoff);
			END_IF;
			
			IF FileReadEx_0.status <> ERR_FUB_BUSY AND FileReadEx_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileReadEx_0.status <> ERR_OK THEN
					c.error.errorFub:=FileReadEx_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unhandled error while getting offset';
					STEP:=BAT_W_STP_error;
				ELSE
					//offset bestimmen
					gotOffset:=0;
					i:=4;
					WHILE NOT gotOffset AND i <= FileReadEx_0.len DO
						aDel ACCESS ADR(bufoff) + FileReadEx_0.len - i;
						IF aDel[0]=DATA_LINE_ENDCHAR AND aDel[1]=DATA_LINE_ENDCHAR AND aDel[2]=13 AND aDel[3]=10 THEN
							gotOffset:=1;
							difOffset:=i - 4;
						END_IF;
						i:=i+1;
					END_WHILE
					
					IF gotOffset THEN
						STEP:=BAT_W_STP_write_data;
					ELSE
						c.error.errorFub:=FileReadEx_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='no offset found';
						STEP:=BAT_W_STP_error;
					END_IF;
				END_IF
				FileReadEx_0(enable:=0);
			END_IF;	
			
		EVENT_W_STP_get_offset:	//bestimmt offset korrektur für anhängen der datenzeile
			
			IF FileReadEx_0.enable=0 THEN
				FileReadEx_0.enable:=1;
				FileReadEx_0.ident:=fileIdentEvent;
				
				IF fileOpenLenEvent = SIZEOF(bufh_event_out) THEN  //erstes schreiben
					gotOffset:=1;
					difOffset:=0;
					FileReadEx_0.offset:=0;
					FileReadEx_0.len:=fileOpenLenEvent;
				ELSIF fileOpenLenEvent < (BATCH_OFFSETSEARCH + 1) THEN
					FileReadEx_0.offset:=0;
					FileReadEx_0.len:=fileOpenLenEvent;
					gotOffset:=0;
				ELSE
					FileReadEx_0.offset:=fileOpenLenEvent - BATCH_OFFSETSEARCH - 1;
					FileReadEx_0.len:=BATCH_OFFSETSEARCH + 1;
					gotOffset:=0;
				END_IF;	
				FileReadEx_0.pDest:=ADR(bufoff);
			END_IF;
			
			IF FileReadEx_0.status <> ERR_FUB_BUSY AND FileReadEx_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileReadEx_0.status <> ERR_OK THEN
					c.error.errorFub:=FileReadEx_0.status;
					c.error.errorStep:=STEP;
					c.error.errorString:='unhandled error while getting offset event';
					STEP:=BAT_W_STP_error;
				ELSE
					//offset bestimmen
					
					i:=4;
					WHILE NOT gotOffset AND i <= FileReadEx_0.len DO
						aDel ACCESS ADR(bufoff) + FileReadEx_0.len - i;
						IF aDel[0]=DATA_LINE_ENDCHAR AND aDel[1]=DATA_LINE_ENDCHAR AND aDel[2]=13 AND aDel[3]=10 THEN
							gotOffset:=1;
							difOffset:=i - 4;
						END_IF;
						i:=i+1;
					END_WHILE
					
					IF gotOffset THEN
						STEP:=EVENT_W_STP_write_data;
					ELSE
						c.error.errorFub:=FileReadEx_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='no offset found event';
						STEP:=BAT_W_STP_error;
					END_IF;
				END_IF
				FileReadEx_0(enable:=0);
			END_IF;	
			
		EVENT_W_STP_write_data: //hängt die in write header generierte eventzeile an
		
		
			IF FileWrite_0.enable=0 THEN 
	
				FileWrite_0.offset:=fileOpenLenEvent - difOffset;	
				FileWrite_0.len:=fMakeEventData_0.offset;	//	dynamisch generierte datenlänge führt schnell  zu offset fehler
				FileWrite_0.pSrc:=ADR(fMakeEventData_0.data);				
				FileWrite_0.enable:=1;
				FileWrite_0.ident:=fileIdentEvent;	
			END_IF;
			IF FileWrite_0.status <> ERR_FUB_BUSY AND FileWrite_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileWrite_0.status <> ERR_OK THEN
					c.error.errorFub:=FileWrite_0.status;
					c.error.errorStep:=STEP;
					STEP:=BAT_W_STP_error;
					c.error.errorString:='unh.err.wr.e.d.: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
				ELSE
					c.eventsInFile:=bufh_event_out.records;
					CASE c.STATUS OF

						BAT_W_STA_recording:
							
							STEP:=EVENT_W_STP_closeRec;
										
						BAT_W_STA_stopping:

							STEP:=EVENT_W_STP_close;
					
						ELSE
							c.error.errorFub:=FileWrite_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='';
							brsitoa(STEP,ADR(c.error.errorString));
							c.error.errorString:=CONCAT('unhandled STA while event write: ',c.error.errorString);
							c.error.errorSta:=c.STATUS;
							STEP:=BAT_W_STP_error;
					END_CASE		
				END_IF			
				FileWrite_0.enable:=0;
			END_IF;	
	
	
		BAT_W_STP_write_data: //hängt die in write header generierte datenzeile an
		
			IF FileWrite_0.enable=0 THEN 
				IF c.STATUS = BAT_W_STA_starting THEN
					FileWrite_0.offset:=SIZEOF(bufh_out);				
				ELSE
					FileWrite_0.offset:=fileOpenLen - difOffset;	
				END_IF;	
				FileWrite_0.len:=fMakeTrendData_0.dataLen;	//	dynamisch generierte datenlänge führt schnell  zu offset fehler
				FileWrite_0.pSrc:=ADR(fMakeTrendData_0.data);				
				FileWrite_0.enable:=1;
				FileWrite_0.ident:=fileIdent;	
			END_IF;
			IF FileWrite_0.status <> ERR_FUB_BUSY AND FileWrite_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF	FileWrite_0.status <> ERR_OK THEN
					c.error.errorFub:=FileWrite_0.status;
					c.error.errorStep:=STEP;
					STEP:=BAT_W_STP_error;
					c.error.errorString:='unh.err.wr.d.: ';
					c.error.errorString:=CONCAT(c.error.errorString,stack.toString);
				ELSE
					c.info:=bufh_out.A; //für alle fälle nach schreiben den neuen header in info übernehmen
					CASE c.STATUS OF

						BAT_W_STA_initializing,BAT_W_STA_starting,BAT_W_STA_recording:
							
							STEP:=BAT_W_STP_closeRec;
										
						BAT_W_STA_stopping:

							STEP:=BAT_W_STP_close;
					
						ELSE
							c.error.errorFub:=FileWrite_0.status;
							c.error.errorStep:=STEP;
							c.error.errorString:='';
							brsitoa(STEP,ADR(c.error.errorString));
							c.error.errorString:=CONCAT('unhandled STA while Data write: ',c.error.errorString);
							c.error.errorSta:=c.STATUS;
							STEP:=BAT_W_STP_error;
					END_CASE		
				END_IF			
				FileWrite_0.enable:=0;
			END_IF;					

	
	
	
		BAT_W_STP_close:	//routet immer auf idle mit Statusänderung auf WAIT, trigger aus trendschleife

			FileClose_0.enable:=1;
			FileClose_0.ident:=fileIdent;
			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
				FileClose_0.enable:=0;
				countCloseRaw:=countCloseRaw+1;
				CASE c.STATUS OF
					BAT_W_STA_initializing:
						
						c.CMD:=0;
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_waiting;
						
					BAT_W_STA_stopping:	
						IF bufh_in.A.isAT<>0 THEN //prüfen, ob bei events noch was zu tun ist
							IF (ebuf.firstPushed = ebuf.nextPush) THEN
								eventsToPop:=0;
							ELSIF ebuf.firstPushed > ebuf.nextPush THEN
								eventsToPop := TRAIL_ENTRIES - ebuf.firstPushed + 1 + ebuf.nextPush;
							ELSE
								eventsToPop := ebuf.nextPush - ebuf.firstPushed;
							END_IF;		
							IF	eventsToPop > 0 THEN
								STEP:=EVENT_W_STP_open;	//hier einsprung ins finale abschließen der events datei
							ELSE
								c.CMD:=0;
								STEP:=BAT_W_STP_wait;
								c.STATUS:=BAT_W_STA_waiting;	
							END_IF;
						ELSE
							c.CMD:=0;
							STEP:=BAT_W_STP_wait;  //sonst normaler abschluss der *.TREND (letzter schritt ohne AT)
							c.STATUS:=BAT_W_STA_waiting;
						END_IF;
					ELSE
						c.error.errorFub:=FileClose_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='';
						brsitoa(STEP,ADR(c.error.errorString));
						c.error.errorString:=CONCAT('unhandled STA while cl. d. st.: ',c.error.errorString);
						c.error.errorSta:=c.STATUS;
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_error;
				END_CASE
				
			END_IF;
			
		EVENT_W_STP_close:	//routet immer auf idle mit Statusänderung auf WAIT, trigger aus eventschleife

			FileClose_0.enable:=1;
			FileClose_0.ident:=fileIdentEvent;
			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
				FileClose_0.enable:=0;
				countCloseRaw:=countCloseRaw+1;
				CASE c.STATUS OF
					BAT_W_STA_stopping:	 //letzter schritt bei sbschluss des trends mit AT
						c.CMD:=0;
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_waiting;
					ELSE
						
						c.error.errorFub:=FileClose_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='';
						brsitoa(STEP,ADR(c.error.errorString));
						c.error.errorString:=CONCAT('unhandled STA while cl. e. st.: ',c.error.errorString);
						c.error.errorSta:=c.STATUS;
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_error;
				END_CASE
			
			END_IF;
		
		BAT_W_STP_closeRec:	//routet immer auf idle mit Statusänderung auf recording, trigger aus trendschleife

			FileClose_0.enable:=1;
			FileClose_0.ident:=fileIdent;
			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
				FileClose_0.enable:=0;
				countCloseRaw:=countCloseRaw+1;
				CASE c.STATUS OF
					BAT_W_STA_initializing, BAT_W_STA_recording:		
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_recording;
					BAT_W_STA_starting:
						c.CMD:=0;
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_recording;
						
					ELSE
						c.error.errorFub:=FileClose_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='';
						brsitoa(STEP,ADR(c.error.errorString));
						c.error.errorString:=CONCAT('unhandled STA while cl. d. rec/in.: ',c.error.errorString);
						c.error.errorSta:=c.STATUS;
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_error;	
				END_CASE
			END_IF;
			
		EVENT_W_STP_closeRec: //schließen der event datei auf recording, trigger aus eventschleife
		
			FileClose_0.enable:=1;
			FileClose_0.ident:=fileIdentEvent;
			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
				FileClose_0.enable:=0;
				countCloseRaw:=countCloseRaw+1;		
				CASE c.STATUS OF
					BAT_W_STA_starting: //beim starten wird nur einmal der header der eventsdatei angelegt, bevor eigentliches Trenddatei geschrieben wird
					//zurückrouten zum normalen schreiben der ersten events zeile
						STEP:=BAT_W_STP_write_header;
					BAT_W_STA_recording: //beim normalen schreiben ist das der rücksprung in wait
						STEP:=BAT_W_STP_wait;
						c.STATUS:=BAT_W_STA_recording;
					ELSE
					
						c.error.errorFub:=FileClose_0.status;
						c.error.errorStep:=STEP;
						c.error.errorString:='';
						brsitoa(STEP,ADR(c.error.errorString));
						c.error.errorString:=CONCAT('unhandled STA while cl. e. rec/st.: ',c.error.errorString);
						c.error.errorSta:=c.STATUS;
						STEP:=BAT_W_STP_error;
				END_CASE;
			END_IF;
			
		BAT_W_STP_error:	//routet immer auf idle mit Statusänderung auf Fehler, trigger aus trendschleife
			
			FileClose_0.enable:=1;
			FileClose_0.ident:=fileIdent;
			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
				FileClose_0.enable:=0;
				countCloseRaw:=countCloseRaw+1;
				STEP:=BAT_W_STP_wait;
				c.STATUS:=BAT_W_STA_error;
			END_IF;  
		
		EVENT_W_STP_error: //routet immer auf idle mit Statusänderung auf Fehler, trigger aus eventschleife
			
			FileClose_0.enable:=1;
			FileClose_0.ident:=fileIdentEvent;
			IF FileClose_0.status <> ERR_FUB_BUSY AND FileClose_0.status <> ERR_FUB_ENABLE_FALSE THEN
				FileClose_0.enable:=0;
				countCloseRaw:=countCloseRaw+1;
				c.CMD:=0;
				STEP:=BAT_W_STP_wait;
				c.STATUS:=BAT_W_STA_error;
			END_IF;  
			
			
		ELSE
			
	END_CASE
	
	IF NOT enable THEN
		FileClose_0.enable:=0;
		FileOpen_0.enable:=0;
		FileCreate_0.enable:=0;
		FileReadEx_0.enable:=0;
		FileWrite_0.enable:=0;
	//	TON_0.IN:=0;
		c.CMD:=0;
		STEP:=BAT_W_STP_init;
		c.STATUS:=BAT_W_STA_initializing;
	END_IF;	
	FileOpen_0();
	FileClose_0();
	FileCreate_0();
	FileReadEx_0();
	FileWrite_0();
	DirCreate_0();
//	TON_0(PT:=UDINT_TO_TIME(c.info.samplingRate * 1000),IN:=(STEP=BAT_W_STP_wait) AND (c.STATUS=BAT_W_STA_recording));
		
END_FUNCTION_BLOCK

(*
filter für datei typen 0=.TREND 1=.CONFIG
erkennt falsche dateitypen
dateinamen ohne endung werden automatisch auf entsprechende endung gesetzt.
*)
FUNCTION fFileFilter
	fFileFilter:=0;
	IF pString <> 0 AND strlen > 0 THEN
		i:=0;
		WHILE i < strlen DO //letzten punkt finden
			aChar ACCESS pString + INT_TO_UDINT(i);
			IF aChar = 46 THEN lastPoint:=i; END_IF;
			i:=i+1;
		END_WHILE
		
		IF i<>0 THEN //endung vorhanden also prüfen	
			CASE filter OF
				0,1,2,3,4,5,6:	//trend
					aString ACCESS pString + INT_TO_UDINT(lastPoint+1);	
					fFileFilter:= aString = 'TREND' OR aString = 'trend';		
				7:	
					aString ACCESS pString + INT_TO_UDINT(lastPoint+1);	
					fFileFilter:= aString = 'CONFIG' OR aString = 'config';	
				8:	
					aString ACCESS pString + INT_TO_UDINT(lastPoint+1);	
					fFileFilter:= aString = 'BBID' OR aString = 'bbid';
			END_CASE
		END_IF;	
				
	END_IF;	
END_FUNCTION



FUNCTION_BLOCK fMakeTrendData
	dataLen:=0;
	dataLineTrend.A.t:=time;
	count:=0;
	//alle zurücksetzen
	dataLineTrend.A.cI_changed[0]:=0;
	dataLineTrend.A.cI_changed[1]:=0;
	dataLineTrend.A.cO_changed[0]:=0;
	dataLineTrend.A.cO_changed[1]:=0;
	dataLineTrend.A.cCL_changed[0]:=0;
	dataLineTrend.A.cCL_changed[1]:=0;
	FOR i:=0 TO ncIthis BY 1 DO 
		//Eingänge
		IF new THEN
			BITSET(ADR(dataLineTrend.A.cI_changed),i);
			aReal ACCESS ADR(dataLineTrend.B.value_cI) + 4 * count;
			aReal:=stack.cI[i];
			oldstack.cI[i]:=stack.cI[i];
			count:=count+1;
		ELSE
			IF brsmemcmp(ADR(stack.cI[i]),ADR(oldstack.cI[i]),4) <> 0 THEN
				BITSET(ADR(dataLineTrend.A.cI_changed),i);
				aReal ACCESS ADR(dataLineTrend.B.value_cI) + 4 * count;
				aReal:=stack.cI[i];
				oldstack.cI[i]:=stack.cI[i];
				count:=count+1;
			END_IF;	
		END_IF;
	END_FOR;
	// Regler
	FOR i:=0 TO ncCLthis BY 1 DO 
		IF new THEN 
			BITSET(ADR(dataLineTrend.A.cCL_changed),i);
			aReal ACCESS ADR(dataLineTrend.B.value_cI) + 4 * count;
			aReal:=stack.cCL[i];
			oldstack.cCL[i]:=stack.cCL[i];
			count:=count+1;
		ELSE
			IF brsmemcmp(ADR(stack.cCL[i]),ADR(oldstack.cCL[i]),4) <> 0 THEN
				BITSET(ADR(dataLineTrend.A.cCL_changed),i);
				aReal ACCESS ADR(dataLineTrend.B.value_cI) + 4 * count;
				aReal:=stack.cCL[i];
				oldstack.cCL[i]:=stack.cCL[i];
				count:=count+1;
			END_IF;	
		END_IF;
	END_FOR;
	// Ausgänge
	FOR i:=0 TO ncOthis BY 1 DO	
		IF new THEN 
			BITSET(ADR(dataLineTrend.A.cO_changed),i);
			aReal ACCESS ADR(dataLineTrend.B.value_cI) + 4 * count;
			aReal:=stack.cO[i];
			oldstack.cO[i]:=stack.cO[i];
			count:=count+1;
		ELSE
			IF brsmemcmp(ADR(stack.cO[i]),ADR(oldstack.cO[i]),4) <> 0 THEN
				BITSET(ADR(dataLineTrend.A.cO_changed),i);
				aReal ACCESS ADR(dataLineTrend.B.value_cI) + 4 * count;
				aReal:=stack.cO[i];
				oldstack.cO[i]:=stack.cO[i];
				count:=count+1;
			END_IF;
		END_IF;
	END_FOR;
	
	dataLen:=SIZEOF(dataLineTrend.A) + count * 4;
	//CRC anhängen
	CRC ACCESS ADR(dataLineTrend) + dataLen;
	CRC:=CRC32(dataLen,ADR(dataLineTrend),BATCH_GENERATOR);
	dataLen:=dataLen + 4;
	
	aCRLF ACCESS ADR(dataLineTrend) + dataLen;
	aCRLF[0]:=DATA_LINE_ENDCHAR;
	aCRLF[1]:=DATA_LINE_ENDCHAR;
	aCRLF[2]:=13;
	aCRLF[3]:=10;
	
	dataLen:=dataLen + 4;
	//until here all trend data is generated
	brsmemcpy(ADR(data),ADR(dataLineTrend),dataLen); //copy to output buffer, ab hier direkt mit ADR(data) arbeiten

END_FUNCTION_BLOCK

