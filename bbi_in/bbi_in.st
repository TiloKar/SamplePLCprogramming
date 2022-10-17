FUNCTION_BLOCK fcI_DRAM
	IF NOT init THEN
		init:=1;
		cI.inMax:=1000;
		cI.type:=101;
		cI.unit:=7; 
		cI.inMin:=0;
		cI.unitStr:='MByte';
	END_IF;
	
	CASE step OF
		0:
			IF TON_0.Q THEN
				TON_0.IN:=1;
				step:=1;
			END_IF;
		1:	
			IF MEMxInfo_0.status <> ERR_FUB_BUSY THEN
				
				IF MEMxInfo_0.status = 0 THEN
					freeDRAM:=UDINT_TO_REAL(MEMxInfo_0.FreeMemSize) / 1024 / 1024;		//ram in MByte
					cI.in:=freeDRAM;						
				END_IF;	
				MEMxInfo_0.enable:=0;
				step:=99;	
			END_IF;
		99:	
			IF MEMxInfo_0.status = ERR_FUB_ENABLE_FALSE THEN
				step:=0;
			END_IF;		
		ELSE		
	END_CASE
	MEMxInfo_0(mem_typ:=brDRAM, enable:=enable);
	TON_0(PT:=T#10s, IN:=(step=0) AND enable);	
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_pH_clas_MT_dis
(*
für klassische pH Elektrode am knick verstärker
	Sonderfall im disposable bag,
	-X1 ist a in mV/pH
	-X2 ist b in pH

parINT[0] = index + 1 des Kanals gegegen den kompensiert wird
parREAL[0] = Puffertemperatur beim kalibrieren
parREAL[1] = manuelle Kompensationstemperatur bei parINT[0] = 0 (manuell)			
*)
	IF NOT init THEN
		cI.type:=88;
		cI.unit:=7; 
		cI.inMax:=14;
		cI.inMin:=0;
		cI.unitStr:='-';
		init:=1;
	END_IF;
	
	//to do: pseudoinits bei unbelegten cal werten
	IF cal.X1=0 THEN
		cal.X1:=-58.6;
		cal.X2:=7.42;
	END_IF;	
	
	IF enable THEN
		IF 	cal.parInt[0] = 0 AND (cal.parReal[1]+273.15) <> 0  THEN	
			helper:=(cal.parReal[0]+273.15)/(cal.parReal[1]+273.15)*cI.raw;
		ELSIF cal.parInt[0]<= ncI + 1 THEN
			IF (ar_cI[cal.parInt[0] - 1].in+273.15) <> 0 THEN
				helper:=(cal.parReal[0]+273.15)/(ar_cI[cal.parInt[0] - 1].in+273.15) *cI.raw;
			END_IF;
		END_IF;	
		
		IF cal.X1 <> 0 THEN
			helper:=helper / cal.X1;
		END_IF;
		
		helper:=helper + cal.X2;

		IF helper>cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF helper < cI.inMin THEN
			cI.in:=cI.inMin;
		ELSE
			cI.in:=helper;
		END_IF;
		cI.error:=sumError;	
	ELSE
		cI.error:=0;	
	END_IF;	
	
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_ext
	//für Werte die "fertig" von seriellen MV oder anderen Quellen kommen und nur auf einen Kanal abstrahiert werden
	IF NOT init THEN
		init:=1;
		CASE par OF
			0://knick DS cond bis 1000S/m
				cI.inMax:=1000;
				cI.inMin:=0;
				cI.type:=33;
				cI.unit:=12;
				cI.unitStr:='S/m';
			1://Temp vom seriellen MV
				cI.inMax:=150;
				cI.inMin:=0;
				cI.type:=107;
				cI.unit:=9;
				cI.unitStr:='°C';	
			2://redox (ORP) vom seriellen MV
				cI.inMax:=1000;
				cI.inMin:=-1000;
				cI.type:=109;
				cI.unit:=21; 
				cI.unitStr:='mV';		
			ELSE
		END_CASE	
	END_IF;
	IF enable THEN
		CASE par OF 
			1:	//parameter mit zusätzlicher xCUBIO Skalierung
				IF cal.X2 = 0 THEN
					cal.X1:=0;
					cal.X2:=1;
					cal.Y1:=0;
					cal.Y2:=1;
				END_IF;	
				fScale_0.x1:=cal.X1;
				fScale_0.x2:=cal.X2;
				fScale_0.y1:=cal.Y1;
				fScale_0.y2:=cal.Y2;
				fScale_0.x:=cI.raw;
				cI.in:=fScale_0.y;
			0:	// filter für leitfähigkeit	
				IF enableFilter THEN
					MTFilterMovingAverage_0.Enable:=1;
					MTFilterMovingAverage_0.In:=cI.raw;
					cI.in:=MTFilterMovingAverage_0.Out;
				ELSE	
					MTFilterMovingAverage_0.Enable:=0;
					cI.in:=cI.raw;
				END_IF;
			ELSE
				cI.in:=cI.raw;
		END_CASE	
		
		IF cal.DISABLED THEN
			cI.in:=0;
		ELSIF cI.in > cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF cI.in < cI.inMin THEN
			cI.in:=cI.inMin;	
		END_IF;
		cI.error:=sumError;
	ELSE
		cI.error:=0;
		MTFilterMovingAverage_0.Enable:=0;
	END_IF;	
	
	MTFilterMovingAverage_0(WindowLength:=50);
	fScale_0(enable:=enable);
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_RQ
(*  
	RQ berechnung aus O2/CO2
	CER/OUR je nach pointervergabe optional
*)	
	
	IF NOT init THEN
		init:=1;	
		IF pOUR <> 0 THEN
			cIOUR ACCESS pOUR;
			cIOUR.type:=31;
			cIOUR.unit:=20;
			cIOUR.inMax:=1000;	
			cIOUR.unitStr:='mmol/L/h';
		END_IF;		
		IF pCER <> 0 THEN
			cICER ACCESS pCER;
			cICER.type:=32;
			cICER.unit:=20;
			cICER.inMax:=1000;
			cICER.unitStr:='mmol/L/h';
		END_IF;
		IF pRQ <> 0 THEN
			cIRQ ACCESS pRQ;
			cIRQ.inMax:=5;
			cIRQ.inMin:=-5;
			cIRQ.type:=30;
			cIRQ.unit:=7;
			cIRQ.unitStr:='-';
		END_IF;		
	END_IF;
		
	
	IF enable THEN
		
		h1:= 100 - oe - ce;
		h2:= 100 - oa - ca;
		IF h2 <> 0 THEN
			k := h1/h2;
		END_IF;
	
		our:=(oe / 100) - (oa / 100 * k);
		our:=our * vpunkt (*/ 1000*) * 60;		//ml/min in l/h umrechen   mol --> mmol
		IF vr<>0 THEN	
			our:=our / 22.4 / vr	; //mol/l/h
		END_IF;	
		IF pOUR <> 0 THEN
			cIOUR.in := our;
		END_IF;
	
		cer:=(ca / 100 * k) - (ce / 100);
		cer:=cer * vpunkt (*/ 1000*) * 60;		//ml/min in l/h umrechen   mol --> mmol
		IF vr<>0 THEN	
			cer:=cer / 22.4 / vr	; //mol/l/h
		END_IF;	
		IF pCER <> 0 THEN
			cICER.in:=cer;
		END_IF;

		IF our <> 0 THEN
			rq:=cer / our;
		END_IF;	
		IF pRQ <> 0 THEN
			cIRQ.in:=rq;
		END_IF;
		
	END_IF;
END_FUNCTION_BLOCK	
		
FUNCTION_BLOCK fcI_DI
	
//- nimmt einen DI entgegen und wandelt in einen common input
	IF NOT init THEN
		cI.type:=4;
		cI.inMax:=1.5;
		cI.inMin:=-0.5;
		cI.unit:=14; //bool
		init:=1;
		cI.unitStr:='';
	END_IF;
	IF enable THEN
		cI.in:=BOOL_TO_REAL(clamp);
		cI.error:=sumError;
	ELSE
		cI.error:=0;
	END_IF;	
	
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_LEVEL
	(*
	nimmt einen widerstandswert(real) und 
	eine widerstandsschwelle (real) entgegen und schaltet einen cI 
	falls die konfiguriete schwelle überschritten wird
	*)
	IF NOT init THEN
		cI.inMax:=1.5;
		cI.inMin:=-0.5;
		cI.type:=5;
		cI.unit:=14; //bool
		MTFilterMovingAverage_0.WindowLength:=50;
		init:=0;
		cI.unitStr:='-';
	END_IF;
	IF enable THEN
		IF cal.parInt[0] = 0 THEN
			cal.parInt[0]:=1;
		END_IF;	
		IF cal.parReal[0] = 0 THEN
			cal.parReal[0]:=3000000;
		END_IF;
		//ein mittelwertfilter wird verwendet
		MTFilterMovingAverage_0.Enable:=1;
		TON_0.IN:=MTFilterMovingAverage_0.Out < cal.parReal[0];
		cal.X1:=MTFilterMovingAverage_0.Out; //neu an cal.x1 kann der aktuelle wert nach dm filter angezeigt werden....
		IF cI.raw <= RMAX AND cI.raw >=0 THEN	//Im normalen messbereich an filter durchreichen	
			MTFilterMovingAverage_0.In:=cI.raw;
		ELSIF cI.raw < 0 THEN					//Unterschreitung abfangen
			MTFilterMovingAverage_0.In:=0;
		ELSE	
			MTFilterMovingAverage_0.In:=RMAX;  //Überschreitung abfangen
		END_IF;		
		cI.in:=BOOL_TO_REAL(TON_0.Q);
		cI.error:=sumError;
	ELSE
		cI.error:=0;
		MTFilterMovingAverage_0.Enable:=0;
	END_IF;	
	MTFilterMovingAverage_0();
	TON_0(PT:=DINT_TO_TIME(UINT_TO_DINT(cal.parInt[0]*1000)));
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_Gr_Flow
//differenzierer

	IF NOT init THEN
		init:=1;
		cI.type:=2;
		cI.inMax:=1000000;
		cI.inMin:=-1000000;
		cI.unit:=15;
		cI.unitStr:='g/h';
		MTBasicsDT1_0.TimeConstant:=cal.X1;
		MTFilterMovingAverage_0.WindowLength:=200;
		oldConst:=cal.X1;
		MTBasicsDT1_0.Gain:=3600;
		cI.tag:=CONCAT('Gr.Fl. ',in.tag);		//eigenen dynamischen tag gepollt erzeugen
	END_IF;
	
	IF cal.X1=0 THEN
		cal.X1:=20;
	END_IF;
	internalEnable:=0;
	IF in.type=17 THEN //für Waagen zusätzlich auf valid prüfen
		internalEnable:=enable AND in.valid;
	ELSE
		internalEnable:=enable;
	END_IF;

	IF internalEnable THEN 
		cI.tag:=CONCAT('Gr.Fl. ',in.tag);		//eigenen dynamischen tag gepollt erzeugen
		MTBasicsDT1_0.In:=in.raw;
		IF cal.parInt[0]>0 THEN		//optionale betragsbildung
			MTFilterMovingAverage_0.In:=ABS(MTBasicsDT1_0.Out);
		ELSE
			MTFilterMovingAverage_0.In:=MTBasicsDT1_0.Out;
		END_IF;
		cI.in:=MTFilterMovingAverage_0.Out;
		MTBasicsDT1_0.Enable:=1;
		cI.error:=in.error;
		IF MTBasicsDT1_0.UpdateDone THEN 
			MTBasicsDT1_0.Update:=0;
		END_IF;
		IF oldConst <> cal.X1 THEN
			oldConst:=cal.X1;
			MTBasicsDT1_0.TimeConstant:=cal.X1;	
			MTBasicsDT1_0.Update:=1;
		END_IF;	
	ELSE
		cI.error:=0;
	END_IF;
		
	MTBasicsDT1_0(Enable:=internalEnable);
	MTFilterMovingAverage_0(Enable:=internalEnable);
	
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_VL_INT
	(*
- Integrator nimmt Volumen/MIN entgegen und erzeugt das volumenintegral
 - parBool[0] --> Auslöser für tara
//parReal[0] --> ml/min bei cO.outMax
//parReal[1] --> 0 Eigangsintegrator / 1 Ausgangsintegrator
//parINT[0] --> index im cO Array der integriert wird
//funktioniert für cO.outMin = 0 und outMax>outMin
//über serviceparameter anpassbarer maximaler integratorwert in L auf diesem kanal
//für Volumenströme
	*)
	IF NOT init THEN   
		cI.type:=1;
		cI.inMin:=0;
		cI.unit:=2; //volume mL
		cI.unitStr:='ml';
		MTBasicsIntegrator_0.Gain:= 1;
		init:=TRUE;
		cI.inMax:=10000000;
	END_IF;
	//ständiges forcing eines autocorrects der cal-paramter
	IF cal.Y2 > 10000000 THEN
		cal.Y2 := 10000000;
	ELSIF cal.Y2 <= 0 THEN
		cal.Y2 := 10000;
	END_IF;	
	
	IF cal.parReal[0]<=0 THEN
		cal.parReal[0]:=100;
	END_IF;	

	IF enable THEN
		//Flanke bei enable, holen des gespeicherten wertes aus dem remanenten speicher
		IF NOT enabled THEN
			enabled:=1;
			MTBasicsIntegrator_0.OutPresetValue:= rem;
			MTBasicsIntegrator_0.SetOut:=TRUE;
		END_IF;	
		cI.inMax:=cal.Y2;
		rem:=MTBasicsIntegrator_0.Out; //im normalen lauf, ausgang mit jedem takt sichern
		IF cal.parBool[0] THEN   //	reset
			MTBasicsIntegrator_0.OutPresetValue:=0;
			MTBasicsIntegrator_0.SetOut:=1;
			cal.parBool[0]:=0;
		END_IF;
		
		IF cal.parReal[1]= 0 THEN	//Eingang wird integriert
			IF cal.parInt[0] <= ncI THEN
				//negativ verhindern
				IF ar_cI[cal.parInt[0]].in < 0 THEN 
					MTBasicsIntegrator_0.In := 0;
				ELSE
					IF ar_cI[cal.parInt[0]].inMax <> 0 THEN
						MTBasicsIntegrator_0.In :=cal.parReal[0] * ar_cI[cal.parInt[0]].in / ar_cI[cal.parInt[0]].inMax /60;
					END_IF;		
				END_IF
				cI.error:=ar_cI[cal.parInt[0]].error;					
				cI.tag:=CONCAT('Vol. ',ar_cI[cal.parInt[0]].tag);		//eigenen dynmischen tag gepollt erzeugen
			END_IF;
		ELSE
			IF cal.parInt[0] <= ncO THEN
				//negativ verhindern
				IF ar_cO[cal.parInt[0]].out < 0 THEN 
					MTBasicsIntegrator_0.In:=0; 
				ELSE
					IF ar_cO_read[cal.parInt[0]].outMax <> 0 THEN
						MTBasicsIntegrator_0.In:=cal.parReal[0] * ar_cO[cal.parInt[0]].out / ar_cO_read[cal.parInt[0]].outMax / 60;
					END_IF;	
				END_IF	
				cI.error:=ar_cO_read[cal.parInt[0]].error;
				cI.tag:=CONCAT('Vol. ',ar_cO_read[cal.parInt[0]].tag);		//eigenen dynamischen tag gepollt erzeugen
			END_IF;
		END_IF;	
		cI.in:=MTBasicsIntegrator_0.Out;
	ELSE
		enabled:=0;
		cI.error:=0;
	END_IF;
	MTBasicsIntegrator_0(Enable:=enable);
	MTBasicsIntegrator_0.SetOut:=0;

END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_VL_press
	(*
Volumenbestimmung aus druckdifferenz im zyl. Kessel mit Klöpperboden
	CLR 1112
	
	unstetige Funktion:
	
	- Betrag aus p1-p2 ist dP
	-solange dP<cal.x1:
		- V=dP*cal.y1
	für dP >=cal.x1:
		- V=cal.x2+(dP-cal.x1)*cal.y1
	
	-Ständig für visu: out. bar in % dP/cal.y2 berechnen (Bargraph)
	
	*)
	IF NOT init THEN   // holen des remanenzen werts beim hochfahren
		cI.type:=35;
		cI.inMin:=-1000000;
		cI.inMax:=3000000;
		cI.unit:=2; //volume mL
		cI.unitStr:='ml';
		init:=TRUE;
	END_IF;

	IF cal.X1 = 0 THEN
		cal.X1 := 20;	//	mbar bei erreichen des zyl teils
		cal.X2 := 94;	//	L bei erreichen von X1
		cal.Y1 := 7; 	//	L/mbar
		cal.Y2 := 1900; //	maximale Füllhöhe
	END_IF;	

	IF enable THEN
		dP:=ABS(p1-p2);
		IF dP < cal.X1 THEN	//im klöpperboden
			cI.in:=dP*cal.Y1*1000;
		ELSE
			cI.in:=(cal.X2 +((dP-cal.X1)*cal.Y1))*1000;
		END_IF;	
		IF 	cal.Y2 <> 0 THEN
			bar:=REAL_TO_USINT(cI.in/cal.Y2/10);
			IF bar > 100 THEN
				bar:=100;
			END_IF;
		END_IF;			
	ELSE
		cI.error:=0;
	END_IF;

END_FUNCTION_BLOCK
	
FUNCTION_BLOCK fcI_lin_mV

	IF NOT init THEN
		init:=1;
		cI.inMin:=cIMin;
		cI.inMax:=cIMax;
		cI.type:=100;
		cI.unit:=unit; //unit wird von FUN beschrieben
		fgetUnitString_0(unit:=unit);
		cI.unitStr:=fgetUnitString_0.out;
	END_IF;	
	
	IF enable THEN
		cI.raw:=INT_TO_REAL(clamp) * 10000 / 32767;
			
		fScale_0.x1:=cal.X1;
		fScale_0.x2:=cal.X2;
		fScale_0.y1:=cal.Y1;
		fScale_0.y2:=cal.Y2;
		fScale_0.x:=cI.raw;
		
		cI.in:=fScale_0.y;
		
		IF cI.in > cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF cI.in < cI.inMin THEN
			cI.in:=cI.inMin;	
		END_IF;
		cI.error:=sumError;
	ELSE	
		cI.error:=0;	
	END_IF;	
	
	fScale_0(enable:=enable);
END_FUNCTION_BLOCK
	
FUNCTION_BLOCK fcI_lin_mA
	IF NOT init THEN
		init:=1;
		cI.inMin:=cIMin;
		cI.inMax:=cIMax;
		cI.type:=101;
		cI.unit:=unit; //unit wird von FUN beschrieben
		fgetUnitString_0(unit:=unit);
		cI.unitStr:=fgetUnitString_0.out;
	END_IF;	
	
	IF enable THEN
	
		cI.raw:=INT_TO_REAL(clamp) * 20 / 32767;
			
		fScale_0.x1:=cal.X1;
		fScale_0.x2:=cal.X2;
		fScale_0.y1:=cal.Y1;
		fScale_0.y2:=cal.Y2;
		fScale_0.x:=cI.raw;
		IF fScale_0.y > cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF fScale_0.y < cI.inMin THEN
			cI.in:=cI.inMin;	
		ELSE
			cI.in:=fScale_0.y;
		END_IF;
		cI.error:=sumError;
	ELSE	
		cI.error:=0;	
	END_IF;
	
	fScale_0(enable:=enable);
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_lin_Ptx
	IF NOT init THEN
		init:=1;
		cI.inMin:=0;
		cI.inMax:=150;
		cI.type:=102;
		cI.unit:=9; 
		cI.unitStr:='°C';
	END_IF;	
	IF enable THEN
		IF hd THEN
			cI.raw:=DINT_TO_REAL(clampDINT) * 0.001;
			cI.unit:=9; 
			cI.unitStr:='°C';
		ELSE
			cI.raw:=INT_TO_REAL(clamp) * 0.1;
			cI.unit:=9; 
			cI.unitStr:='°C';
			
		END_IF;	
		fScale_0.x1:=cal.X1;
		fScale_0.x2:=cal.X2;
		fScale_0.y1:=cal.Y1;
		fScale_0.y2:=cal.Y2;
		fScale_0.x:=cI.raw;
	
		IF fScale_0.y > cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF fScale_0.y < cI.inMin THEN
			cI.in:=cI.inMin;	
		ELSE
			cI.in:=fScale_0.y;
		END_IF;
		cI.error:=sumError;
	ELSE
		cI.error:=0;
	END_IF;	
	
	fScale_0(enable:=enable);
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_lin_DMS
	IF NOT init THEN
		init:=1;
		cI.inMin:=cIMin;
		cI.inMax:=cIMax;
		cI.type:=103;
		cI.unit:=unit; //unit wird von FUN beschrieben	
		fgetUnitString_0(unit:=unit);
		cI.unitStr:=fgetUnitString_0.out;
	END_IF;
	IF enable THEN

		cI.raw:=DINT_TO_REAL(clamp) * USINT_TO_REAL(gain) * 5.5 / 8388607;
		fScale_0.x1:=cal.X1;
		fScale_0.x2:=cal.X2;
		fScale_0.y1:=cal.Y1;
		fScale_0.y2:=cal.Y2;
		fScale_0.x:=cI.raw;
		value:=fScale_0.y;
		
		//mit acc kann die dargestellte genauigkeit in den ausgangs basiseinheiten angegebn werden
		IF acc > 0 THEN
			IF brmfmod(value,ABS(acc)) > 0.5 * acc THEN
				value:=value - brmfmod(value,ABS(acc)) + acc;	
			ELSE
				value:=value - brmfmod(value,ABS(acc));	
			END_IF;	
		END_IF;

		IF cal.parBool[0] THEN	//tara
			cal.parBool[0]:=0;
			cal.parReal[0]:=-value; //offset aus übergebenem Wert mit negativem vorzeichen
			calChanged:=1;
		END_IF;

		value:=value + cal.parReal[0];	//tara
		cI.in:=value;
		IF cI.in > cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF cI.in < cI.inMin THEN
			cI.in:=cI.inMin;	
		END_IF;
		cI.error:=sumError;
	ELSE
		cI.error:=0;
	END_IF;	
	
	fScale_0(enable:=enable);
	
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_pCO2
(*
	- übernimmt die skalierung eines mV Signals auf einen pH Wert nach NERNST und dann auf %CO2
	- inklusive temperaturkompensation des  pH signals
	- X/Y Kalibrierpaar
	- parINT[0] = index + 1 des Kanals gegegen den kompensiert wird
	- parREAL[0] = Puffertemperatur beim kalibrieren
	- parREAL[1] = manuelle Kompensationstemperatur bei parINT[0] = 0 (manuell)	
*)	
	
	IF NOT init THEN
		init:=1;
		cI.type:=6;
		cI.unit:=5; //pCO2
		cI.inMax:=300;
		cI.inMin:=-100;
		cI.unitStr:='%';
	END_IF;	
	IF enable THEN
		fScale_0.x1:=cal.X1;
		fScale_0.x2:=cal.X2;
		fScale_0.y1:=cal.Y1;
		fScale_0.y2:=cal.Y2;

		IF 	cal.parInt[0] = 0 AND (cal.parReal[1]+273.15) <> 0  THEN	
			fScale_0.x:=(cal.parReal[0]+273.15)/(cal.parReal[1]+273.15)*cI.raw;
		ELSIF cal.parInt[0]<= ncI + 1 THEN
			IF (ar_cI[cal.parInt[0] - 1].in+273.15) <> 0 THEN
				fScale_0.x:=(cal.parReal[0]+273.15)/(ar_cI[cal.parInt[0] - 1].in+273.15) *cI.raw;
			END_IF;
		END_IF;	
		
		pH:=fScale_0.y;
	
		value:=pCO2_a1 * 2.71828183**(pCO2_a2 * pH);
		cI.in:=value;
		IF cI.in > cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF cI.in < cI.inMin THEN
			cI.in:=cI.inMin;
		END_IF;
	
		cI.error:=sumError;	
	ELSE
		cI.error:=0;	
	END_IF;
	
	fScale_0(enable:=enable);
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_from_cO
	(*
	holt alle informationen von einem ausgang und stellt ihn als eingang zur verfügung
	*)
	IF NOT init THEN
		init:=1;
		cI.type:=7;
	END_IF;
	
	IF enable THEN
		cI.unitStr:=cO_read.unitStr;
		cI.inMax:=cO_read.outMax;
		cI.inMin:=cO_read.outMin;
		cI.in:=cO.out;
		cI.unit:=cO_read.unit;
	END_IF;

END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_pH_clas
(*
für klassische pH Elektrode am knick verstärker
-skaliert einen real rohwert mV auf einen commonInput pH und beschränkt diesen 
- lineare skalierung, static pairs mit temp kompensation	
XY Kalibrierpaar
parINT[0] = index + 1 des Kanals gegegen den kompensiert wird
parREAL[0] = Puffertemperatur beim kalibrieren
parREAL[1] = manuelle Kompensationstemperatur bei parINT[0] = 0 (manuell)			
*)
	IF NOT init THEN
		cI.type:=8;
		cI.unit:=7; 
		cI.inMax:=14;
		cI.inMin:=0;
		cI.unitStr:='-';
	END_IF;
	
	//to do: pseudoinits bei unbelegten cal werten
	IF cal.X1=0 AND cal.X2 = 0 THEN
		cal.X1:=0;
		cal.Y2:=7;
		cal.X2:=177.58;
		cal.Y2:=4;
	END_IF;	
	
	IF enable THEN
		fScale_0.x1:=cal.X1;
		fScale_0.x2:=cal.X2;
		fScale_0.y1:=cal.Y1;
		fScale_0.y2:=cal.Y2;

		IF 	cal.parInt[0] = 0 AND (cal.parReal[1]+273.15) <> 0  THEN	
			fScale_0.x:=(cal.parReal[0]+273.15)/(cal.parReal[1]+273.15)*cI.raw;
		ELSIF cal.parInt[0]<= ncI + 1 THEN
			IF (ar_cI[cal.parInt[0] - 1].in+273.15) <> 0 THEN
				fScale_0.x:=(cal.parReal[0]+273.15)/(ar_cI[cal.parInt[0] - 1].in+273.15) *cI.raw;
			END_IF;
		END_IF;	
		
		value:=fScale_0.y;
		cI.in:=value;
		IF cI.in > cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF cI.in < cI.inMin THEN
			cI.in:=cI.inMin;
		END_IF;
		cI.error:=sumError;	
	ELSE
		cI.error:=0;	
	END_IF;	
	
	fScale_0(enable:=enable);
	
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_DO_clark
(*
für klassische po2 Sonde am knick MV
-skaliert einen real rohwet nA auf einen po2 Eingang und beschränkt diesen
- lineare skalierung, static pairs mit temp kompensation nach knick: 
-----------------------------------------------------------------------------
 lib_oxGetSensorstromTk()

\brief       Berechnung des temperaturkompensierten Sensorstroms
\attention   Ergebnis kann je nach Bezugstemperatur sehr unterschiedlich sein

\par Formeln:
\code
     T  = abs. Kalibriertemperatur (273.15°C + Bezugstemperatur)   --> fix auf 25° C gesetzt
     Tm = abs. Meßtemperatur (273.15°C + Temperatur)
     +-----------------------------------------------------------------------------------------+
     |                                               mw_i                             
     | mw_itk = ----------------------------------------------------------------------------
     |                 EXP^{ 2220 * ((Tm-T)(T*Tm)) * Membrankorrekturfaktor }
     +-----------------------------------------------------------------------------------------+
\endcode


\param[in]  mw_i      <PRE>- Sensorstrom (unkompensiert)           [nA]    | Messwert <PRE>
\param[in]  mw_tpc    <PRE>- Temperatur                                      [°C]    | Messwert <PRE>
\param[in]  p_bzgtpc  <PRE>- Bezugstemperatur                           [°C]    | Parametrierung <PRE>
\param[in]  p_memfkt  <PRE>- Membrankorrekturfaktor                  []     | Parametrierung <PRE>

\retval mw_itk <PRE>- Sensorstrom temperaturkompensiert           [nA]    | Messwert <PRE>
	
XY Kalibrierpaar
parINT[0] = index + 1 des Kanals gegegen den kompensiert wird
parREAL[0] = Membrankorrekturfaktor
parREAL[1] = manuelle Kompensationstemperatur bei parINT[0] = 0 (manuell)	(Messtemperatur/Temperatur)		

*)	
	IF NOT init THEN
		init:=1;
		cI.type:=9;
		cI.unit:=5; 
		cI.inMax:=300;
		cI.inMin:=-100;
		cI.unitStr:='%';
	END_IF;
	IF cal.parReal[0]=0 THEN
		cal.parReal[0]:=37;
	END_IF;
	IF cal.X2=0 THEN
		cal.X2:=-67;
	END_IF;
	IF cal.Y2=0 THEN
		cal.Y2:=1;
	END_IF;

	IF enable THEN
		IF cal.parInt[0]<= ncI + 1 THEN
			IF 	cal.parInt[0] = 0 THEN
				IF cal.parReal[1]+273.15 <> 0 THEN
					c1 := EXP(2220 *(cal.parReal[1]+273.15 - 298.15) / (cal.parReal[1]+273.15) / 298.15 * cal.Y2 );	
				END_IF;
			ELSE
				IF (ar_cI[cal.parInt[0] - 1].in+273.15) <> 0 THEN
					c1:= EXP(2220 *(ar_cI[cal.parInt[0] - 1].in + 273.15 - 298.15) / (ar_cI[cal.parInt[0] - 1].in+273.15) / 298.15 * cal.Y2 );
				END_IF;
			END_IF;
			//rückrechen auf kompensierte X werte zum Kalibrierzeitpunkt
			IF cal.parReal[0] + 273.15 <> 0 THEN 
				c2:=EXP(2220 *(cal.parReal[0]+273.15 - 298.15) / (cal.parReal[0]+273.15) / 298.15 * cal.Y2 );	
				IF c2 <> 0 THEN
					compX1:=cal.X1/c2;
					compX2:=cal.X2/c2;
					IF  (compX2-compX1)<>0 AND c1<> 0 THEN
						mw_itk:=cI.raw / c1;
						fScale_0.x:=mw_itk;
						fScale_0.x1:=compX1;
						fScale_0.x2:=compX2;
						fScale_0.y1:=0;
						fScale_0.y2:=100;
						value:=fScale_0.y;
					END_IF;	
				END_IF;
			END_IF;	
		END_IF;
		IF value>cI.inMax THEN 
			cI.in:=cI.inMax;
		ELSIF value < cI.inMin THEN
			cI.in:=cI.inMin;
		ELSE
			cI.in:=value;
		END_IF;
		cI.error:=sumError;	
	ELSE
		cI.error:=0;
	END_IF;	
	
	fScale_0(enable:=enable);
END_FUNCTION_BLOCK
	
FUNCTION_BLOCK fcI_ODens
(*------------------------------------------------------fSCALE_OD-------------------------------------------------------------------------------------*)
//übernimmt die normierung des OD  signals EXTINKTION = log(I0/I)
//inklusive temperaturkompensation
	IF NOT init THEN
		init:=1;
		cI.inMax:=3;
		cI.inMin:=-3;
		cI.type:=3;
		cI.unit:=11;//keine unit_2 kommastellen
		cI.unitStr:='-';
		MTBasicsPT1_0.TimeConstant:=cal.X1;
		MTBasicsPT1_0.Gain:=1;
	END_IF;

	IF enable THEN	
		
		MTBasicsPT1_0.In:=10000 / 32767 * INT_TO_REAL(clamp);
		
		IF cal.X1 > 0 THEN
			cI.raw:=MTBasicsPT1_0.Out;
		ELSE
			cI.raw:=MTBasicsPT1_0.In;
		END_IF;	
		
		IF cal.X2 <= 0 THEN
			cal.X2:=1;
		END_IF;	
	
		IF cI.raw <>0 THEN 
			cI.in:=LOG(cal.X2/cI.raw);
		END_IF;
		
		IF cI.in > cI.inMax THEN 
			cI.in := cI.inMax;
		ELSIF  cI.in < cI.inMin THEN
			cI.in := cI.inMin;
		END_IF;	
		
		//löst einfach nur das triggersignal für die Lichtschrankenplatine us
		IF cal.parBool[0] THEN
			IF NOT TON_0.IN THEN
				TON_0.IN:=1;
				zero:=1;
			ELSIF TON_0.Q THEN 
				zero:=0;
				cal.parBool[0]:=0;
				TON_0.IN:=0;
			END_IF;		
		END_IF;
		cI.error:=sumError;	
	ELSE	
		cI.error:=0;
		zero:=0;
		TON_0.IN:=0;
	END_IF;
	
	TON_0(PT:=T#1s);
	MTBasicsPT1_0(Enable:=cal.X1>0 AND enable);
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_Optek
(*------------------------------------------------------fcI_Optek-------------------------------------------------------------------------------------
- übernimmt die normierung des OD  signals EXTINKTION = LOG(I0/I) I0=X2 wenn bool[0] ausgelöst
- Rohwert von DMS klemme 
- optionale pt 1 dämpfung T1 in X1 
- offset der intensität in Y1 (Hardwarewert bei totalauslöschung)
- Zero in x2
- 256mV/V für Horst/optek Platine bit 6 im config register auf 1 setzen
*)
	IF NOT init THEN
		init:=1;
		cI.inMax:=6;
		cI.inMin:=-6;
		cI.type:=10;
		cI.unit:=11;//keine unit _ 2 kommastellen
		cI.unitStr:='-';
		MTBasicsPT1_0.TimeConstant:=cal.X1;
		MTBasicsPT1_0.Gain:=1;
		oldTimeConst:=cal.X1;
	END_IF;
	
	//pseudoinit
	IF cal.X2 <= 0 THEN
		cal.X2:=5.5 * V;
	END_IF;	
	
	IF enable THEN
		IF oldTimeConst <>  cal.X1 THEN
			MTBasicsPT1_0.Update:=1;
			MTBasicsPT1_0.TimeConstant:=cal.X1;
			oldTimeConst:=cal.X1;
		END_IF;
		MTBasicsPT1_0.In:=DINT_TO_REAL(clamp)/8388607 * 5.5 * V;
	
		IF cal.X1 > 0 THEN
			cI.raw:=MTBasicsPT1_0.Out;
		ELSE
			cI.raw:=MTBasicsPT1_0.In;
		END_IF;	

		value:=cI.raw - cal.Y1; //immer erstmal mit hardware-offset verrechnen
	
		IF value <= 0 THEN
			value := 0.0001;
		ELSE
			cI.in:=LOG(cal.X2/value);
		END_IF;
		
		IF cI.in > cI.inMax THEN 
			cI.in := cI.inMax;
		ELSIF  cI.in < cI.inMin THEN
			cI.in := cI.inMin;
		END_IF;	
		
		//zero holen
		IF cal.parBool[0] THEN
			cal.parBool[0]:=0;
			cal.X2:=value;
			calChanged:=1;
		END_IF;
		
		//offset bei Totalauslöschung übernehemen (nullstrom-> Das ist nicht der tara-Wert, sondern ein hardwarebedingter offset)
		IF cal.parInt[0] > 0 THEN
			cal.parInt[0]:=0;
			cal.Y1:=DINT_TO_REAL(clamp)/8388607 * 5.5 * V;
			calChanged:=1;
		END_IF;
		cI.error:=sumError;	
	ELSE
		cI.error:=0;	
	END_IF;	
		
	MTBasicsPT1_0(Enable:=cal.X1>0 AND enable);
	MTBasicsPT1_0.Update:=0;
END_FUNCTION_BLOCK



