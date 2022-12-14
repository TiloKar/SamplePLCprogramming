FUNCTION addEvent
	
	(*
		Design einer array queue mit eventstrukturen
		buf.nextPush ist n?chster g?ltiger index f?r n?chstes element, n?chsten push dort anh?ngen
		buf.firstPushed ist zuerst hinzugef?gtes element = ?ltestes, pop dort entnehmen
	*)

	buf ACCESS pBuf;
	e:=event;
	IF NOT enable THEN
		addEvent:=ERR_FUB_ENABLE_FALSE;	
	ELSIF pBuf = 0 THEN
		addEvent:=90;		//nullpointer
	ELSE
		IF (buf.firstPushed = buf.nextPush) THEN
			count:=0;
		ELSIF buf.firstPushed > buf.nextPush THEN
			count := TRAIL_ENTRIES - buf.firstPushed + 1 + buf.nextPush;
		ELSE
			count := buf.nextPush - buf.firstPushed;
		END_IF;	
		IF count = TRAIL_ENTRIES THEN
			addEvent:=91;		//puffer voll, keine neuen entragungen m?glich, ein eintrag muss frei bleiben um leere queue von komplett voller zu unterscheiden
		ELSE
			IF count + 1 = TRAIL_ENTRIES THEN //nur noch ein eintrag (eigentlich zwei) im puffer vorhanden
				e.ID:=18;		//letzter m?glicher eintrag, eventuell weitere Events verloren!!!
			END_IF;
			buf.value[buf.nextPush]:=e;
			buf.nextPush := (buf.nextPush + 1)  MOD TRAIL_ENTRIES_COUNT;
			addEvent:=ERR_OK;	
		END_IF;	
	END_IF;	
END_FUNCTION

FUNCTION_BLOCK fMakeEventData //pop f?r alle werte im puffer
	//start parsing buffer to additional events data in output buffer...
	ebuf ACCESS pATbuf;
	IF (ebuf.firstPushed = ebuf.nextPush) THEN
		eventsToPop:=0;
	ELSIF ebuf.firstPushed > ebuf.nextPush THEN
		eventsToPop := TRAIL_ENTRIES - ebuf.firstPushed + 1 + ebuf.nextPush;
	ELSE
		eventsToPop := ebuf.nextPush - ebuf.firstPushed;
	END_IF;	
	
	
	IF eventsToPop > 0 THEN //falls eintr?ge vorhanden
		//alle puffereintr?ge abarbeiten
		indexBuf:=ebuf.firstPushed;
		offset:=0;
		FOR i:=0 TO eventsToPop - 1 BY 1 DO
			//start delimeter erzeugen
			aCRLF ACCESS ADR(data)+offset;
			aCRLF[0]:=DATA_LINE_STARTCHAR5;
			aCRLF[1]:=DATA_LINE_STARTCHAR5;
			aCRLF[2]:=DATA_LINE_STARTCHAR5;
			aCRLF[3]:=DATA_LINE_STARTCHAR5;
			offset:=offset + 4;
				
			e:=ebuf.value[indexBuf]; //abbild des aktuellen eintrags in e anlegen
			//zeitstempel
			aUDINT ACCESS ADR(data)+offset;
			aUDINT:=DT_TO_UDINT(e.dat); //f?r alle typen zeit ?bernehmen
			offset:=offset + 4;
			//f?r alle typen id schreiben
			aUDINT ACCESS ADR(data)+offset;
			aUDINT:=e.ID; 
			offset:=offset + 4;
			payloadCountPosition:=offset; //position des registers der payloadl?nge sichern
			offset:=offset + 4;
			
			CASE e.ID OF
				14,//Reboot
				18,//puffer ?berlauf (task-?bergabe)
				19://puffer ?berlauf (datei schreiben)
					//keine payload
					1,//login succesfull
					2,//failed
					3,//logout
					5,//PW changed
					6,//reason critical login
					26,//reason cO faceplate
					36,//reason cI fceplate
					37,//reason Cl page
					10,//AT-Start
					70,//Sequenz fordert eingabe an
					75,//Inokulation markiert
				11://AT Stop, 
					//par 1			par2		string1
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par1;
					offset:=offset + 4;
					
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par2; 
					offset:=offset + 4;
					
					brsmemcpy(ADR(data)+offset,ADR(e.string1),brsstrlen(ADR(e.string1))+1); //string1;
					offset:=offset + brsstrlen(ADR(e.string1))+1;	
					//		aUDINT ACCESS ADR(data)+payloadCountPosition; //l?nge der payload sichern
					//		aUDINT := offset - payloadCountPosition - 4; //exklusive payload count
					20,//Ausgang ge?ndert 
					30,//sollwert aus faceplate ausg?nge
				31,34://sollwert aus reglerseite, aus faceplate eing?nge
				
					//par 1			new
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par1; 
					offset:=offset + 4;
				
					aReal ACCESS ADR(data)+offset;
					aReal:=e.new1; 
					offset:=offset + 4;
				
					22,//lockOff change 
					23,//lockman change 
					33,//enable regler aus reglerseite
					32,//enable regler aus ausgangsfaceplate
					35,//enable aus eingangsfaceplate
					71,// sequenzdialog OK
					72,// sequenzdialog abbruch
					73,// sequenzdialog timeout
					74,// sequenzdialog minimiert
					40,//profil start/stop
					100,101,102,//alarmsystem
					110,111,112,
					120,121,122,
					130,131,132,
					140,141,142,
					150,151,152,
				160,161,162:
					//par 1			par2	
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par1; 
					offset:=offset + 4;
					
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par2; 
					offset:=offset + 4;	
					50,//sequenz manuell gestartet
					51,//sequenz manuell zum herunterfahren aufgefordert
					52,//sequenz zum harten abbruch gezwungen	
					55,//sequenz meldet start des herunterfahrens
					56,//hilfs sequenz meldet automatischen start des herunterfahrens nach beenden der muttersequenz
					57,//sequenz meldet erfolg des herunterfahrens
				41://profil ende nach selbstst?ndigem durchlauf	
					//par 1		
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par1; 
					offset:=offset + 4;
					60,//globaler par ge?ndert vor start der sequenz
				61://globaler par ge?ndert bei laufender sequenz
					//par 1			par2	new 1	string1
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par1;
					offset:=offset + 4;
					
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.par2; 
					offset:=offset + 4;
					
					aReal ACCESS ADR(data)+offset;
					aReal:=e.new1; 
					offset:=offset + 4;
					
					brsmemcpy(ADR(data)+offset,ADR(e.string1),brsstrlen(ADR(e.string1))+1); //string1;
					offset:=offset + brsstrlen(ADR(e.string1))+1;	
				ELSE //unhandled ID forced to ID 12
					aUDINT ACCESS ADR(data)+offset;
					aUDINT:=e.ID; //unbekannte ID auf par 1 schreiben
					offset:=offset + 4;
					aUDINT ACCESS ADR(data)+offset - 12 ;	//zur?ckgehen zu e.ID und auf 12 setzen
					aUDINT:=12;	
			END_CASE;
			aUDINT ACCESS ADR(data)+payloadCountPosition; //l?nge der payload sichern
			aUDINT := offset - payloadCountPosition - 4; //exklusive payload count
			//CRC anh?ngen
			CRC ACCESS ADR(data) + offset;
			CRC:=CRC32(offset - payloadCountPosition + 8,ADR(data) + payloadCountPosition - 8,BATCH_GENERATOR);
			offset:=offset + 4;
			//f?r jedes event einen  end delimiter erzeugen
			//gleicher end delim wie trenddata, damit offset korrektur kompatibel bleibt
			aCRLF ACCESS ADR(data)+offset;
			aCRLF[0]:=DATA_LINE_ENDCHAR;
			aCRLF[1]:=DATA_LINE_ENDCHAR;
			aCRLF[2]:=13;
			aCRLF[3]:=10;
			offset:=offset + 4;
			//mit jedem  abgearbeitetn eintrag pr?fen ob offset + 60 > MAXTRENDDATASIZE, 
			toMuchData:=0;
			IF offset + 70 > 1023 THEN //wenigstens platz f?r einen weiteren eintrag muss noch da sein 
				toMuchData:=1;
				i:=eventsToPop;//abort loop
			END_IF;
			
			//mit einem index f?r trail buffeer durch die entr?ge  gehen
			IF indexBuf+1 > TRAIL_ENTRIES THEN
				indexBuf:=0;
			ELSE	
				indexBuf:=indexBuf+1;	
			END_IF;
		END_FOR;
		IF toMuchData THEN//falls zu viele daten, nur ein event mit ID 19 anlegn 
			offset:=0;
			//start delimeter erzeugen
			aCRLF ACCESS ADR(data);
			aCRLF[0]:=DATA_LINE_STARTCHAR5;
			aCRLF[1]:=DATA_LINE_STARTCHAR5;
			aCRLF[2]:=DATA_LINE_STARTCHAR5;
			aCRLF[3]:=DATA_LINE_STARTCHAR5;
			offset:=offset + 4;
			//zeitstempel
			aUDINT ACCESS ADR(data)+offset;
			aUDINT:=DT_TO_UDINT(time); //zeit dieses fehlers ?bernehmen
			offset:=offset + 4;
			aUDINT ACCESS ADR(data)+offset;
			aUDINT:=19; 
			offset:=offset + 4;
			payloadCountPosition:=offset; //position des registers der payloadl?nge sichern
			aUDINT ACCESS ADR(data)+offset;
			aUDINT:=0; //f?r diese event ist payload 0
			offset:=offset + 4;
			//CRC anh?ngen
			CRC ACCESS ADR(data) + offset;
			CRC:=CRC32(offset - payloadCountPosition + 8,ADR(data) + payloadCountPosition - 8,BATCH_GENERATOR);
			offset:=offset + 4;
			aCRLF ACCESS ADR(data)+offset;
			aCRLF[0]:=DATA_LINE_ENDCHAR;
			aCRLF[1]:=DATA_LINE_ENDCHAR;
			aCRLF[2]:=13;
			aCRLF[3]:=10;
			offset:=offset + 4;
		END_IF;	
		ebuf.firstPushed := (ebuf.firstPushed + eventsToPop) MOD (TRAIL_ENTRIES + 1); //puffer um alle gepoppten events bereinigen
	END_IF;
	
END_FUNCTION_BLOCK
