
FUNCTION_BLOCK fVoegtl
	IF NOT init THEN	//pauschal auf alle angemeldeten Kanäle die Headerdaten schreiben
		init:=1;
		FOR k:=0 TO nVGTL BY 1 DO
			IF pcI[k]<>0 THEN
				acI ACCESS 	pcI[k];
				acI.inMax:=30000;
				acI.inMin:=0;
				acI.unit:=0;
				acI.unitStr:='ml/min';
				acI.type:=37;
				lastValidIndex:=k;
				
				IF pcOr[k]<>0 THEN	
					acOr ACCESS 	pcOr[k];
					acOr.outMax:=30000;
					acOr.outMin:=0;
					acOr.unit:=0;
					acOr.unitStr:='ml/min';
					acOr.type:=37;
					lastValidIndex:=k;	
				ELSE
					k:=nVGTL+1;
				END_IF;	
			ELSE
				k:=nVGTL+1;
			END_IF;		
		END_FOR;
	END_IF;
	
	IF enable THEN
		IF NOT enabled THEN
			XOPENCONFIG_0.argc:=0;
			XOPENCONFIG_0.argv:=0;
			XOPENCONFIG_0.delimc := 0;
			XOPENCONFIG_0.idle := 4;
			XOPENCONFIG_0.tx_cnt := 1;
			XOPENCONFIG_0.rx_cnt := 1;
			XOPENCONFIG_0.tx_len := 256;
			XOPENCONFIG_0.rx_len := 256;
			FRM_xopen_0.config:=ADR(XOPENCONFIG_0);
			FRM_xopen_0.device:=ADR(deviceString);
			enabled:=1;
			i:=0;
			status:=0;
			FOR k:=0 TO nVGTL BY 1 DO
				lineStatus[k]:=0;
				errorImage[k]:=0;
				lineInit[k]:=0;
			END_FOR;
		END_IF;
	ELSE	
		IF enabled THEN						
			step:=90;		
			FOR k:=0 TO lastValidIndex BY 1 DO
				lineStatus[k]:=99;
				IF pcI[k]<>0 THEN
					acI ACCESS 	pcI[k];
					acI.valid:=0;
				END_IF;
			END_FOR;
			status:=98;
			preLineError:=99;
			enabled:=0;	
		END_IF;
		IF step=0 THEN
			status:=99;
		END_IF;
	END_IF;
	
	CASE step OF
		
		0:	//wait for commands
	
			IF enabled THEN
				IF lineStatus[i] > 20 THEN
					errorCount[i] := errorCount[i] + 1;
					IF errorCount[i] > 1 THEN
						IF pcI[i]<>0 THEN
							acI ACCESS 	pcI[i];
							acI.valid:=0;
							acI.error:=1;
						END_IF;
						IF pcOr[i]<>0 THEN
							acOr ACCESS 	pcOr[i];
							acOr.error:=1;
						END_IF;
						errorImage[i]:=1;
						lineInit[i]:=0;
						lastErrorLine[i]:=lineStatus[i];
						errorCount[i] := 0;
						i:=i+1; //line nur bei fehler erhöhen
					END_IF;
					
				ELSIF lineStatus[i] = 0 THEN
					errorCount[i] := 0;	
					IF status > 0 AND status <> 99 THEN // beim ersten aufruf und nach disable nicht die line erhöhen
						i:=i+1; // sonst pauschal erhöhen
					END_IF;	
				ELSE	
					lineStatus[i]:=65;	// case im routing schritt unbehandelt
				END_IF;
				
				IF i > lastValidIndex THEN // neu beginnen falls letzte belegte line erreicht
					i:=0;
				END_IF;
				
				
				IF NOT lineInit[i] THEN
					lineStatus[i]:=1;			//nur beim erste init den nennbereich holen
				ELSE
					lineStatus[i]:=7;			//immer mit messwert starten		
				END_IF;	
				
				IF pcal[i] <> 0 THEN			//trigger für adressfunktion
					acal ACCESS pcal[i];
					IF acal.parInt[2] > 0 THEN
						lineStatus[i]:=6;
					END_IF;
				END_IF
				
				//internes dv_frame fub routing
				CASE status OF
					0,91,98:	//geschlossene Schnittstelle nach init oder disable oder open fehler
						status:=1;	//Versuch zu öffnen nach fehler, close
						step:=1;
					4,94,95,97:		//anders als bei single line routet dieser schritt auch fehler bei denen die SN offen bleibt
	
						step:=2;
						status:=2; //geöffnet, Anfrageframe vorbereiten, weitere stati in den lines	
					
					ELSE
					lineStatus[i]:=64;	// case im routing schritt unbehandelt
				END_CASE;	
			END_IF;	

		1: (*OPEN*)

			FRM_xopen_0.enable:=1;
			FRM_xopen_0.mode:=ADR(STR_OPEN);
			IF FRM_xopen_0.status <> ERR_FUB_BUSY AND FRM_xopen_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FRM_xopen_0.status <> ERR_OK THEN
					lineStatus[i]:=98;
					status:=91;
					step:=0;	
				ELSE
					ident:=FRM_xopen_0.ident;
					step:=2;
					status:=2; //geöffnet, Anfrageframe vorbereiten, weitere stati in den lines
				END_IF;	
				FRM_xopen_0.enable:=0; 
			END_IF;
		
		
		2:	//Anfrageframe vorbereiten

			CASE lineStatus[i] OF 
				
				1://Regelfunktion setzen 000E auf 1
					
					IF pcal[i]=0 THEN
						step:=0;
						status:=94;
						lineStatus[i]:=90;	//90   tag pointer leer														
					ELSE
						acal ACCESS pcal[i];
						IF acal.parInt[0] = 0 THEN
							acal.parInt[0]:= i+1;
						END_IF;
					//	newProt[i]:=TRUE;//acal.parInt[1]=2;  //prüfen ob cal struktur neue protokollversion markiert
						slaveAdr[i]:=UINT_TO_USINT(acal.parInt[0]);
						write.code:=16#10;
						write.slave:=slaveAdr[i];
						write.register0:=0;
						write.register1:=16#0E;
						write.num0:=0;
						write.num1:=1; 
						write.byteCount:=2;
						value:=0;
						write.data[0]:=0;
						write.data[1]:=1;//1=modbus sollwert, 22 = ventil geschlossen, 23 offen
						crc:=crcmodbus(ADR(write),9);
						brsmemcpy(ADR(write.data[2]),ADR(crc),2);	
						brsmemcpy(ADR(memOut),ADR(write),11);
						FRM_write_0.buflng:=11;
						status:=3;	//sendet
						step:=30;

					END_IF;	
				
				11:	//kein gas-Fehler quittieren 
				
					write.code:=16#10;
					write.slave:=slaveAdr[i];
					write.register0:=16#40;
					write.register1:=16#4F;
					write.num0:=0;
					write.num1:=1; //
					write.byteCount:=2;
					
					write.data[0]:=0;
					write.data[1]:=0;
					write.data[1].3:=1;
					crc:=crcmodbus(ADR(write),9);
					brsmemcpy(ADR(write.data[2]),ADR(crc),2);	
					brsmemcpy(ADR(memOut),ADR(write),11);
					FRM_write_0.buflng:=11;
					status:=3;	//sendet
					step:=30;
				
				
				2: //mit 0014/6020 messbereich in L/min holen
					
					read.code:=3;
					read.slave:=slaveAdr[i];
				//	IF newProt[i] THEN
						read.register0:=16#60;
						read.register1:=16#20;
//					ELSE
//						read.register0:=16#00;
//						read.register1:=16#14;
//					END_IF;
					read.num0:=0;
					read.num1:=2;
					crc:=crcmodbus(ADR(read),6);
					brsmemcpy(ADR(read.crc16_0),ADR(crc),2);
					brsmemcpy(ADR(memOut),ADR(read),8);
					FRM_write_0.buflng:=8;
					status:=3;	//sendet
					step:=30;	//
			
				7:	//Fehlerzustand holen

				
					read.code:=3;
					read.slave:=slaveAdr[i];
					read.register0:=16#00;
					read.register1:=16#0C;
					read.num0:=0;
					read.num1:=1;	
					crc:=crcmodbus(ADR(read),6);
					brsmemcpy(ADR(read.crc16_0),ADR(crc),2);
					brsmemcpy(ADR(memOut),ADR(read),8);
					FRM_write_0.buflng:=8;
					status:=3;	//sendet
					step:=30;	//	
					
				8:	//Hardwarefehler holen
					read.code:=3;
					read.slave:=slaveAdr[i];
					read.register0:=16#00;
					read.register1:=16#0D;
					read.num0:=0;
					read.num1:=1;	
					crc:=crcmodbus(ADR(read),6);
					brsmemcpy(ADR(read.crc16_0),ADR(crc),2);
					brsmemcpy(ADR(memOut),ADR(read),8);
					FRM_write_0.buflng:=8;
					status:=3;	//sendet
					step:=30;	//	
					
					
				
				3:	//Istwert holen

				
					read.code:=3;
					read.slave:=slaveAdr[i];
					read.register0:=0;
					read.register1:=0;
					read.num0:=0;
					read.num1:=2;	
					crc:=crcmodbus(ADR(read),6);
					brsmemcpy(ADR(read.crc16_0),ADR(crc),2);
					brsmemcpy(ADR(memOut),ADR(read),8);
					FRM_write_0.buflng:=8;
					status:=3;	//sendet
					step:=30;	//	
				
				4:	//Sollwert holen
	
					read.code:=3;
					read.slave:=slaveAdr[i];
					read.register0:=0;
					read.register1:=16#06;
					read.num0:=0;
					read.num1:=2; //
					crc:=crcmodbus(ADR(read),6);
					brsmemcpy(ADR(read.crc16_0),ADR(crc),2);
					brsmemcpy(ADR(memOut),ADR(read),8);
					FRM_write_0.buflng:=8;
					status:=3;	//sendet
					step:=30;	//
		
				
				5:	//Sollwert setzen
				
					write.code:=16#10;
					write.slave:=slaveAdr[i];
					write.register0:=0;
					write.register1:=16#06;
					write.num0:=0;
					write.num1:=2; //
					write.byteCount:=4;
					value:=SP[i] / 1000;  //nicht vergessen, bei ungleichheit auch nach lesen SP auf neuen wert zu setzen
					finvertBytes(ADR(value),4);
					brsmemcpy(ADR(write.data[0]),ADR(value),4);
					crc:=crcmodbus(ADR(write),11);
					brsmemcpy(ADR(write.data[4]),ADR(crc),2);
					brsmemcpy(ADR(memOut),ADR(write),13);
					FRM_write_0.buflng:=13;
					status:=3;	//sendet
					step:=30;
				
				6:	//Adresse setzen (nur cal)
					
					IF pcal[i]=0 THEN
						step:=0;
						status:=94;
						lineStatus[i]:=28;														
					ELSE
						acal ACCESS pcal[i];
						write.code:=16#10;
						write.slave:=slaveAdr[i];
						slaveAdr[i]:=UINT_TO_USINT(acal.parInt[2]);//für nächste aufrufe übernehemen
						acal.parInt[0]:=acal.parInt[2];	//für cal menü übernehemen
						acal.parInt[2]:=0; //zurücksetzen
						write.register0:=0;
						write.register1:=16#13;
						write.num0:=0;
						write.num1:=1; //
						write.byteCount:=2;
						write.data[0]:=0;
						write.data[1]:=slaveAdr[i]; //neue adresse
						crc:=crcmodbus(ADR(write),9);
						brsmemcpy(ADR(write.data[2]),ADR(crc),2);	
						brsmemcpy(ADR(memOut),ADR(write),11);
						FRM_write_0.buflng:=11;
						status:=3;	//sendet
						step:=30;	//
					END_IF;	
										
				ELSE
					step:=0;
					status:=94;
					lineStatus[i]:=95;						//95   CASE unbehandelt bei Frame vorbereitung	
				
			END_CASE;

		30:	//verzögerung nach erfolgreichem lesen
			IF TON_0.Q THEN
				step:=3;	
			END_IF;		
		
		3:	//frame senden auswerten
			
			FRM_write_0.enable:=1;
			FRM_robuf_0.buffer:=FRM_write_0.buffer;
			FRM_robuf_0.buflng:=FRM_write_0.buflng;
			FRM_write_0.ident:=ident;
			FRM_write_0.buffer:=ADR(memOut);
			
			IF FRM_write_0.status <> ERR_FUB_BUSY AND FRM_write_0.status <> ERR_FUB_ENABLE_FALSE THEN
				IF FRM_write_0.status <> ERR_OK THEN
					IF FRM_write_0.status = frmERR_NOTOPENED THEN
						preLineError:=71;
					ELSE
						preLineError:=70;
					END_IF;
					step:=90;				//	schreibpuffer freigeben
				ELSE
					step:=4;				//	alles OK, warten auf antwort
					status:=4;

				END_IF;	
				FRM_write_0.enable := 0;
			END_IF;
		
		4:		//antwort erwarten
		
			FRM_read_0.ident:=ident;
			FRM_read_0.enable:=1;
			FRM_rbuf_0.buffer:=FRM_read_0.buffer;
			FRM_rbuf_0.buflng:=FRM_read_0.buflng;
			
			IF FRM_read_0.status <> ERR_FUB_BUSY AND FRM_read_0.status <> ERR_FUB_ENABLE_FALSE THEN
				
				IF FRM_read_0.status = ERR_OK THEN //empfang
					preLineError := 0;
					brsmemset(ADR(memIn),0,SIZEOF(memIn));//bereinigen des hilfsarrays
					brsmemset(ADR(response),0,SIZEOF(response));//bereinigen des hilfsarrays

					hlplen:=FRM_read_0.buflng;
					
					IF hlplen > 40 THEN
						preLineError:=40;		//	40 antwort zu lang
						status:=95;
						IF hlplen < 255 THEN
							brsmemcpy(ADR(memIn),FRM_read_0.buffer,hlplen); //kopieren auf roharray
							brsmemcpy(ADR(response),FRM_read_0.buffer,hlplen); //kopieren auf struct
						END_IF;	
					ELSIF hlplen < 2 THEN
						preLineError:=47;		//	47 antwort zu kurz
						status:=95;
						brsmemcpy(ADR(memIn),FRM_read_0.buffer,hlplen); //kopieren auf roharray
						brsmemcpy(ADR(response),FRM_read_0.buffer,hlplen); //kopieren auf struct
					ELSE
						brsmemcpy(ADR(memIn),FRM_read_0.buffer,hlplen); //kopieren auf roharray
						brsmemcpy(ADR(response),FRM_read_0.buffer,hlplen); //kopieren auf struct
						CASE lineStatus[i] OF
							1,11,5,6:	//schreiben
								IF hlplen = 8 THEN																		//prüfen
									brsmemcpy(ADR(crc),ADR(response) + 6,2);											//prüfen
									IF crcmodbus(ADR(response),hlplen - 2) <> crc THEN
										preLineError:=43;//	43 crc fehler antwort auf  schreibbefehl
										status:=95;
										responseDebug43:=response;
									END_IF;
								ELSE
									preLineError:=41;//	41 antwort schreiben länge falsch
									status:=95;
									responseDebug41:=response;
								END_IF;
							ELSE //lesen
								IF response.count + 5 = hlplen (*AND hlplen > 1*) THEN	
									brsmemcpy(ADR(crc),ADR(response) + response.count + 3,2);											//prüfen
									IF crcmodbus(ADR(response),hlplen - 2) <> crc THEN
										preLineError:=42;//	42 crc fehler antwort auf  lesebefehl
										status:=95;
									END_IF;;
								ELSE
									preLineError:=44;//	44 antwort lesen falsche länge
									status:=95;
								END_IF;						
						END_CASE
					END_IF;
					
					IF preLineError = 0 THEN // falls noch kein CRC fehler
					
						CASE lineStatus[i] OF
							
							1://regelfunktion setzen auswerten
						
								lineStatus[i]:=2;	
							
							2://antwort nennbereich
								
								IF response.count = 4 THEN
									brsmemcpy(ADR(value),ADR(response.data[0]),4);//
									finvertBytes(ADR(value),4);
									IF pcI[i]=0 OR pcOr[i]=0 THEN	//auf angeschlossenen cI und cO schreiben (Adr Array eingang)
										preLineError:=46;			//	46 zeiger auf xCUBIO Kanal nicht initialisiert
										status:=95;
									ELSE							
										acI ACCESS pcI[i];
										acI.inMax:=value * 1000;
										acOr ACCESS pcOr[i];
										acOr.outMax:=value * 1000;
										lineStatus[i]:=7;
										lineInit[i]:=1;//Nennbereich erfolgreich ausgelesen, weiter mit MFC istwert auslesen  
									END_IF;		
								ELSE
									preLineError:=45;	//	45  Antwort bytecount zu kurz
									status:=95;
								END_IF;	
							7://antwort error1
							
								IF response.count = 2 THEN
									brsmemcpy(ADR(error1[i]),ADR(response.data[0]),2);//
									finvertBytes(ADR(error1[i]),2);
									lineStatus[i]:=8;							
								ELSE
									preLineError:=52;	//	42 Antwort bytecount zu kurz
									status:=95;
								END_IF;	
								
							8://antwort error2
							
								IF response.count = 2 THEN
									brsmemcpy(ADR(error2[i]),ADR(response.data[0]),2);//
									finvertBytes(ADR(error2[i]),2);
									IF error2[i].3 AND PV[i]>2 THEN
										lineStatus[i]:=11;
									ELSE
										lineStatus[i]:=3;
									END_IF;								
								ELSE
									preLineError:=52;	//	42 Antwort bytecount zu kurz
									status:=95;
								END_IF;	
								
							11://antwort quittieren
								
								lineStatus[i]:=3;
							
							3://antwort istwert
							
								IF response.count = 4 THEN
									brsmemcpy(ADR(value),ADR(response.data[0]),4);//
									finvertBytes(ADR(value),4);
									IF pcI[i]=0 THEN	//auf angeschlossenen cI und cO schreiben (Adr Array eingang)
										preLineError:=51;			//	51 zeiger auf xCUBIO kanal nicht initialisiert
										status:=95;
									ELSE
										acI ACCESS 	pcI[i];
										acI.in:=value*1000;	
										PV[i]:=value;
										acI.error:=0;
										acI.valid:=1;
										lineStatus[i]:=4;
									END_IF;								
								ELSE
									preLineError:=52;	//	42 Antwort bytecount zu kurz
									status:=95;
								END_IF;	
							
							4://antwort sollwert holen
							
								IF response.count = 4 THEN
									brsmemcpy(ADR(value),ADR(response.data[0]),4);//
									finvertBytes(ADR(value),4);
									value:=value*1000;
									IF (pcO[i]=0) OR (pcOr[i]=0) THEN	//auf angeschlossenen cI und cO schreiben (Adr Array eingang)
										preLineError:=50;			//	51 zeiger auf xCUBIO kanal nicht initialisiert
										status:=95;
									ELSE
										acO ACCESS 	pcO[i];	
									
										acOr ACCESS pcOr[i];
										acOr.error:=0;
//								
										IF value <> acO.out THEN	//sollwert passt?
											lineStatus[i]:=5;	//sollwert neu setzen
											SP[i]:=acO.out; //zwischenspeichern
										ELSE
											lineStatus[i]:=0;												//zurück zum lesen, dann einen weiter
										END_IF;
									END_IF;			
								ELSE
									preLineError:=53;	//	53 Antwort bytecount zu kurz
									status:=95;
								END_IF;	
							
							5://antwort sollwert tsetzen
							
								IF response.count = 16 THEN
									lineStatus[i]:=0;
									IF pcOr[i]<>0 THEN
										acOr ACCESS pcOr[i];
										acOr.error:=0;
									END_IF;
								ELSIF response.count = 0 THEN
									//tolleranz gegenüber veränderter Antwort bei schnellen sollwertdynamiken
									lineStatus[i]:=0;
								ELSE
									preLineError:=54;	//   antwortlänge falsch
									responseDebug54:=response;
									status:=95;						
								END_IF;	
							
							6://adresse setzen
								
								lineStatus[i]:=0;  //neu anrollen in jedem fall
							
						
							ELSE
								preLineError:=57;		
								status:=95;	
						END_CASE;
					END_IF;
					step:=91;//freigabe des lespuffers und einsprung in Auswertung (line status wird betrachtet für weiteres routing)		
					FRM_read_0.enable:=0;
				ELSIF FRM_read_0.status <> frmERR_NOINPUT THEN
					preLineError:=60;
					status:=95;//60 fehler beim lesen
					step:=91;//freigabe des lespuffers und einsprung in Auswertung (line status wird betrachtet für weiteres routing)
					FRM_read_0.enable:=0;
				END_IF;	
			END_IF;	
			
			IF timeout_responseframe.Q THEN
				preLineError:=61;	// timeout responseframe
				status:=95;				
				step:=91;//freigabe des lespuffers und einsprung in Auswertung (line status wird betrachtet für weiteres routing)
				FRM_read_0.enable:=0;
			END_IF;	

		90	:	//freigabe des schreibpuffers nur bei schreibfehler,     Falls RAM Fehler weiterhin besteht, prüfen ob pauschale Freigabe auch bei normalem Schreibablauf ev. das Problem behebt

		
			FRM_robuf_0.ident:=ident;
			FRM_robuf_0.enable:=1;
			
			IF FRM_robuf_0.status <> ERR_FUB_BUSY AND FRM_robuf_0.status <> ERR_FUB_ENABLE_FALSE THEN
				CASE status OF 
					97:	
						CASE preLineError OF
							
							70:
								step:=2;
							
							71:	//nicht geöffnet
								step:=0;
								status:=0;
							
						END_CASE;		
						
						lineStatus[i]:=preLineError;
					
					98:		
						step:=91;	
					ELSE				
						lineStatus[i]:=63;						//   CASE unbehandelt bei frigabe des schreibpuffers
						status:=94;
						step:=0;
				END_CASE;
				FRM_robuf_0.enable:=0;
			END_IF;

		91: //freigabe des lesepuffers 

			FRM_rbuf_0.ident:=ident;
			FRM_rbuf_0.enable:=1;
			
			IF FRM_rbuf_0.status <> ERR_FUB_BUSY AND FRM_rbuf_0.status <> ERR_FUB_ENABLE_FALSE THEN
	
				CASE status OF 
										
					4:	//alles OK
						IF lineStatus[i]=0 THEN //markiert ordentlichen durchlauf der linie, ab ins line routing
							errorImage[i]:=0;
							step:=0;
						ELSE					//normale leseauswertung innnerhalb der linie
							step:=2;	
							status:=2;	
						END_IF;
					
					95:	//klemmenfehler lesen, timeout, inhaltsfehler	
						
						step:=0;
						lineStatus[i]:=preLineError;
		
					98:		//offen nach fehler
						step:=92;
						
					ELSE	//retrie ablauf, oder open error
						step:=0;
						status:=94;
						lineStatus[i]:=59;						//59   CASE unbehandelt bei pufferfreigabe
				END_CASE;
				FRM_rbuf_0.enable:=0;
			END_IF;	

		92: // schließen 
			FRM_close_0.enable:=1;
			FRM_close_0.ident:=FRM_xopen_0.ident;
			
			IF FRM_close_0.status <> ERR_FUB_BUSY AND FRM_close_0.status <> ERR_FUB_ENABLE_FALSE THEN
				step:=0;
				CASE status OF
					98:	//fehler beim öffnen, disabled
							
						status:=99;
					ELSE
						lineStatus[i]:=62;						//62   CASE unbehandelt bei close
						
				END_CASE;
				FRM_close_0.enable:=0;	
			END_IF;					
	END_CASE;

	
	TON_0(IN:=step=30,PT:=T#100ms);
	//im original Template war der timer auf 1.5 sek, durch die Anzahl an verbauten klemmen in 1142 wurde dies hierfür hochgesetzt
	//	timeout_responseframe(IN:=step=4,PT:=T#1s500ms);	
	timeout_responseframe(IN:=step=4,PT:=T#2s200ms);
	FRM_xopen_0();
	FRM_write_0();
	FRM_read_0();
	FRM_robuf_0();
	FRM_rbuf_0();
	FRM_close_0();
	
END_FUNCTION_BLOCK