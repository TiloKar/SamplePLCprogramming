
FUNCTION_BLOCK fcI_DI
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : {REDUND_UNREPLICABLE} BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		clamp : {REDUND_UNREPLICABLE} BOOL;
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ;
	END_VAR
	VAR
		init : BOOL;
	END_VAR
END_FUNCTION_BLOCK

{REDUND_UNREPLICABLE} FUNCTION_BLOCK fcI_DO_clark
	VAR_INPUT
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : {REDUND_UNREPLICABLE} BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		ar_cI : {REDUND_UNREPLICABLE} ARRAY[0..ncI] OF cI_read_typ; (*Für offset setzen*)
	END_VAR
	VAR_OUTPUT
		mw_itk : {REDUND_UNREPLICABLE} REAL; (*nA nach kompensation*)
	END_VAR
	VAR_IN_OUT
		cal : cCal_typ; (*Kalibrierparameter*)
		cI : cI_read_typ; (*Kalibrierter CommonInput*)
	END_VAR
	VAR
		value : {REDUND_UNREPLICABLE} REAL;
		c2 : {REDUND_UNREPLICABLE} REAL;
		c1 : {REDUND_UNREPLICABLE} REAL;
		compX2 : {REDUND_UNREPLICABLE} REAL;
		compX1 : {REDUND_UNREPLICABLE} REAL;
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		init : {REDUND_UNREPLICABLE} BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_from_cO
	VAR_INPUT
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		cO_read : {REDUND_UNREPLICABLE} cO_read_typ;
		cO : {REDUND_UNREPLICABLE} cO_rem_typ;
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ;
	END_VAR
	VAR
		init : BOOL;
	END_VAR
END_FUNCTION_BLOCK

{REDUND_UNREPLICABLE} FUNCTION_BLOCK fcI_LEVEL
	VAR_INPUT
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : {REDUND_UNREPLICABLE} BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
	END_VAR
	VAR_IN_OUT
		cal : cCal_typ; (*Kalibrierparameter*)
		cI : cI_read_typ;
	END_VAR
	VAR
		TON_0 : {REDUND_UNREPLICABLE} TON;
		MTFilterMovingAverage_0 : {REDUND_UNREPLICABLE} MTFilterMovingAverage;
		init : {REDUND_UNREPLICABLE} BOOL;
	END_VAR
	VAR CONSTANT
		RMAX : REAL := 30000000;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_lin_Ptx
	VAR_INPUT
		hd : BOOL := TRUE; (*1=DINT register wird verwendet für hochauflösende AT2311*)
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : {REDUND_UNREPLICABLE} BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		cal : {REDUND_UNREPLICABLE} cCal_typ; (*cI Array*)
		clampDINT : DINT;
		clamp : {REDUND_UNREPLICABLE} INT;
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ;
	END_VAR
	VAR
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		init : {REDUND_UNREPLICABLE} BOOL;
	END_VAR
END_FUNCTION_BLOCK

{REDUND_UNREPLICABLE} FUNCTION_BLOCK fcI_lin_mA
	VAR_INPUT
		sumError : {REDUND_UNREPLICABLE} BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		cIMin : {REDUND_UNREPLICABLE} REAL; (*untere Wertebereichsgrenze*)
		cIMax : {REDUND_UNREPLICABLE} REAL; (*obere Wertebereichsgrenze*)
		unit : {REDUND_UNREPLICABLE} USINT; (*Einheiten index*)
		clamp : {REDUND_UNREPLICABLE} INT;
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ;
		cal : cCal_typ; (*cI Array*)
	END_VAR
	VAR
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		init : {REDUND_UNREPLICABLE} BOOL;
		fgetUnitString_0 : {REDUND_UNREPLICABLE} fgetUnitString;
	END_VAR
END_FUNCTION_BLOCK

{REDUND_UNREPLICABLE} FUNCTION_BLOCK fcI_lin_mV
	VAR_INPUT
		sumError : {REDUND_UNREPLICABLE} BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		cIMin : {REDUND_UNREPLICABLE} REAL; (*untere Wertebereichsgrenze*)
		cIMax : {REDUND_UNREPLICABLE} REAL; (*obere Wertebereichsgrenze*)
		unit : {REDUND_UNREPLICABLE} USINT; (*Einheiten index*)
		clamp : {REDUND_UNREPLICABLE} INT;
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ;
		cal : cCal_typ; (*cI Array*)
	END_VAR
	VAR
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		init : {REDUND_UNREPLICABLE} BOOL;
		fgetUnitString_0 : {REDUND_UNREPLICABLE} fgetUnitString;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_lin_DMS
	VAR_INPUT
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		acc : {REDUND_UNREPLICABLE} REAL;
		sumError : {REDUND_UNREPLICABLE} BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		clamp : {REDUND_UNREPLICABLE} DINT;
		gain : {REDUND_UNREPLICABLE} USINT := 2; (*Verstärkung in mV/V*)
		cIMin : {REDUND_UNREPLICABLE} REAL; (*untere Wertebereichsgrenze*)
		cIMax : {REDUND_UNREPLICABLE} REAL; (*obere Wertebereichsgrenze*)
		unit : {REDUND_UNREPLICABLE} USINT; (*Einheiten index*)
	END_VAR
	VAR_IN_OUT
		calChanged : BOOL;
		cal : cCal_typ; (*cI Array*)
		cI : cI_read_typ;
	END_VAR
	VAR
		value : {REDUND_UNREPLICABLE} REAL;
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		init : BOOL;
		fgetUnitString_0 : {REDUND_UNREPLICABLE} fgetUnitString;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_ODens (*wandelt mV Realwert in eine Extinktion um, setzt ausgang bei cal.zero:=true*)
	VAR_INPUT
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		clamp : INT; (*Messwert des Verstärkers*)
	END_VAR
	VAR_OUTPUT
		zero : BOOL; (*Kontakt für nullpunktabgleich anschließen (1 sec)*)
	END_VAR
	VAR_IN_OUT
		cal : cCal_typ; (*Kalibrierparameter*)
		cI : cI_read_typ; (*Kalibrierter CommonInput*)
	END_VAR
	VAR
		TON_0 : TON;
		MTBasicsPT1_0 : MTBasicsPT1;
		init : {REDUND_UNREPLICABLE} BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_Optek (*wandelt mV Realwert in eine Extinktion um, setzt ausgang bei cal.zero:=true*)
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		V : REAL := 256.0; (*Verstärkungsfaktor in mv/V für Anzeige des Rohwertes*)
		sumError : BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		clamp : DINT; (*Messwert des Verstärkers*)
	END_VAR
	VAR_IN_OUT
		calChanged : BOOL;
		cal : cCal_typ; (*Kalibrierparameter*)
		cI : cI_read_typ; (*Kalibrierter CommonInput*)
	END_VAR
	VAR
		value : REAL;
		init : {REDUND_UNREPLICABLE} BOOL;
		MTBasicsPT1_0 : MTBasicsPT1;
		oldTimeConst : REAL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_pCO2 (*wandelt mV Realwert in einen pH commoninput um*)
	VAR_INPUT
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		ar_cI : ARRAY[0..ncI] OF cI_read_typ; (*Für offset setzen*)
		cal : cCal_typ; (*Kalibrierparameter*)
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ; (*Kalibrierter CommonInput*)
	END_VAR
	VAR
		pH : REAL;
		value : REAL;
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		init : {REDUND_UNREPLICABLE} BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_pH_clas
	VAR_INPUT
		enable : {REDUND_UNREPLICABLE} BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		ar_cI : ARRAY[0..ncI] OF cI_read_typ; (*Für offset setzen*)
	END_VAR
	VAR_IN_OUT
		cal : cCal_typ; (*Kalibrierparameter*)
		cI : cI_read_typ; (*Kalibrierter CommonInput*)
	END_VAR
	VAR
		value : REAL;
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		init : BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_RQ
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		vr : REAL; (*reaktionsvolumen in L*)
		vpunkt : REAL; (*eingangsvolumenstrom in ml/min*)
		oa : REAL; (*sauerstoff in % vol von abgasanalyse*)
		ca : REAL; (*co2 in % vol von abgasanalyse*)
		pOUR : UDINT; (*zeiger auf OUR eingangskanal*)
		pCER : UDINT; (*zeiger auf CER eingangskanal*)
		pRQ : UDINT; (*zeiger auf RQ eingangskanal*)
		oe : REAL := 21; (*O2 vol % zuluft*)
		ce : REAL := 0.04; (*CO2 vol % zuluft*)
	END_VAR
	VAR
		cIRQ : REFERENCE TO cI_read_typ; (*common input zeiger variable*)
		cICER : REFERENCE TO cI_read_typ; (*common input zeiger variable*)
		cIOUR : REFERENCE TO cI_read_typ; (*common input zeiger variable*)
		rq : REAL;
		cer : REAL;
		our : REAL;
		h2 : REAL;
		h1 : REAL;
		k : REAL;
		init : BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_VL_INT (*Integriert einen Stellausgang und erzeugt einen Messeingang*)
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		ar_cI : ARRAY[0..ncI] OF cI_read_typ; (*Eingang der Integriert werden soll*)
		ar_cO_read : ARRAY[0..ncO] OF cO_read_typ; (*Ausgang der Integriert werden soll*)
		ar_cO : ARRAY[0..ncO] OF cO_rem_typ; (*Ausgang der Integriert werden soll*)
	END_VAR
	VAR_IN_OUT
		cal : cCal_typ; (*Calibrationsdatentyp INTEGRATOR*)
		cI : cI_read_typ; (*allgemeiner Eingangsdatentyp*)
		rem : REAL;
	END_VAR
	VAR
		MTBasicsIntegrator_0 : MTBasicsIntegrator;
		init : BOOL;
		enabled : BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_ext (*Integriert einen Stellausgang und erzeugt einen Messeingang*)
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		enableFilter : BOOL;
		sumError : BOOL; (*Eingang der Integriert werden soll*)
		cal : cCal_typ; (*cI Array*)
		par : USINT; (*0=COND knick bis 100 mS*)
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ; (*allgemeiner Eingangsdatentyp*)
	END_VAR
	VAR
		init : BOOL;
		fScale_0 : {REDUND_UNREPLICABLE} fScale;
		MTFilterMovingAverage_0 : MTFilterMovingAverage;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_pH_clas_MT_dis
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		sumError : BOOL; (*Summeneingang für Fehler, die cI.Error auslösen*)
		ar_cI : ARRAY[0..ncI] OF cI_read_typ; (*Für offset setzen*)
	END_VAR
	VAR_IN_OUT
		cal : cCal_typ; (*Kalibrierparameter*)
		cI : cI_read_typ; (*Kalibrierter CommonInput*)
	END_VAR
	VAR
		helper : REAL;
		init : BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_Gr_Flow
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		in : cI_read_typ;
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ; (*allgemeiner Eingangsdatentyp*)
		cal : cCal_typ; (*Calibrationsdatentyp INTEGRATOR*)
	END_VAR
	VAR
		init : BOOL;
		MTFilterMovingAverage_0 : MTFilterMovingAverage;
		MTBasicsDT1_0 : MTBasicsDT1;
		oldConst : REAL;
		internalEnable : BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_DRAM (*Integriert einen Stellausgang und erzeugt einen Messeingang*)
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
	END_VAR
	VAR_OUTPUT
		freeDRAM : REAL; (*Eingang der Integriert werden soll*)
	END_VAR
	VAR_IN_OUT
		cI : cI_read_typ; (*allgemeiner Eingangsdatentyp*)
	END_VAR
	VAR
		init : BOOL;
		step : USINT;
		MEMxInfo_0 : MEMxInfo;
		TON_0 : TON;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fcI_VL_press (*Integriert einen Stellausgang und erzeugt einen Messeingang*)
	VAR_INPUT
		enable : BOOL; (*enable Eingang des FUBs, single/twin=immer 1, multi=an unitOK hängen*)
		p2 : REAL; (*Druck 1 in mbar*)
		p1 : REAL; (*Druck 2 in mbar*)
	END_VAR
	VAR_OUTPUT
		bar : USINT; (*ausgang 0-110 % für bargraph*)
	END_VAR
	VAR_IN_OUT
		cal : cCal_typ; (*Kal parameter*)
		cI : cI_read_typ; (*allgemeiner Eingangsdatentyp*)
	END_VAR
	VAR
		init : BOOL;
		dP : REAL;
	END_VAR
END_FUNCTION_BLOCK
