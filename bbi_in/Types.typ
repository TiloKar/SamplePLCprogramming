
TYPE
	faceplate_PV_typ : 	STRUCT 
		RTDP : UDINT := 1;
		RTDP_cLcommon : UINT; (*RTDP zum einsprung auf reglerseite und titel*)
		RTDP_enableInterface : UINT; (*RTDP für enable serieller schnittstellen*)
		RTDP_scale : UINT; (*RTDP der waagenspezifischen controls*)
		RTDP_cL_enable : UINT; (*RTDP des regler enables*)
		RTDP_CALjump : USINT;
		RTDPw : UINT; (*RTDP des sollwertes*)
		open : BOOL;
		index_cI : USINT;
		criticalIfOn : USINT;
		noticeIfOn : USINT;
		currentcIisRealRuntime : UINT;
		currentcIisBoolRuntime : UINT;
		cI_read : cI_read_typ;
		cI : cI_rem_typ;
		alertButtonImageIndex : BOOL;
		unit : UINT;
		sumTriggered : BOOL;
		notAllAck : BOOL;
		index_CL : USINT; (*index des angeschlossenen reglers*)
		CALjump : BOOL; (*Einsprung in Kalibriermenü auslösen*)
		CLjump : BOOL; (*Einsprung in reglerseite auslösen*)
		zeroTG : USINT; (*tara/zero (Typenabhängig) textgruppenindex*)
		close : BOOL; (*schließen des faceplates*)
	END_STRUCT;
	cI_read_typ : 	STRUCT 
		tag : STRING[24];
		raw : REAL; (*Rohwert*)
		in : REAL; (*skaliertes Einganssignal (standardisierte Verknüpfungsvariable wurde auf den in outMin und outMax definierten Bereich skaliert) *)
		inMin : REAL; (*untere Skalierungsgrenze Messwert*)
		inMax : REAL; (*obere Skalierungsgrenze Messwert*)
		unit : USINT; (*einheitenindex für AlarmRangesFenster *)
		status : USINT; (*statusausgang der klemme (für verarbeitung bei abgesetztem HMI ausserhalb des Fehlerarrays)*)
		typeCL : USINT; (*Type der angehängten Reglerlogik (0=unverknüpft)*)
		type : USINT; (*Type der angehängten IO logik*)
		error : BOOL; (*Eingang gestört*)
		isControlled : BOOL; (*Eingang wird einem aktivem Regelkreis zugeführt*)
		unitStr : STRING[10]; (*Einheitenstring*)
		indexSlotCL : USINT; (*Slot des angehängten Reglers*)
		indexCL : USINT; (*Index des angehängten Reglers*)
		valid : BOOL; (*wird gesetzt wenn wert das erste mal vom seriellen Protokoll geschrieben wurde*)
	END_STRUCT;
	cI_rem_typ : 	STRUCT 
		alertRanges : ARRAY[0..3]OF REAL; (*untere Grenzen Alarmbereich alarm bei x>range 0-notice 1-critical  alarm bei x<range 2-notice 3-critical (out-skaliert)*)
		alertActive : ARRAY[0..3]OF BOOL; (*Schalter für Ein/Ausschalten der Alarme von 0 bis 3*)
	END_STRUCT;
	visu_cI_typ : 	STRUCT 
		conText : STRING[30]; (*index für Anschlusstext*)
		CalRuntimeSER : UINT;
		CalRuntimeAll : UINT;
		ColorTitle : INT; (*ColorDatenpunkt Titel*)
		ColorNumeric : INT; (*ColorDatenpunkt Ein/Ausgabefeld*)
		indexSymbol : USINT; (*Symbolindex für bitmapgruppe 0-aus; 1;aktiv; 2-fehler*)
		conSymbol : USINT; (*index für Anschlusssymbol*)
		active : BOOL; (*Eingang aktiv (gesetzt bei in>inMin)*)
	END_STRUCT;
END_TYPE
