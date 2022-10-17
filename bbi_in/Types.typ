
TYPE
	faceplate_PV_typ : 	STRUCT 
		RTDP : UDINT := 1;
		RTDP_cLcommon : UINT; (*RTDP zum einsprung auf reglerseite und titel*)
		RTDP_enableInterface : UINT; (*RTDP f�r enable serieller schnittstellen*)
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
		CALjump : BOOL; (*Einsprung in Kalibriermen� ausl�sen*)
		CLjump : BOOL; (*Einsprung in reglerseite ausl�sen*)
		zeroTG : USINT; (*tara/zero (Typenabh�ngig) textgruppenindex*)
		close : BOOL; (*schlie�en des faceplates*)
	END_STRUCT;
	cI_read_typ : 	STRUCT 
		tag : STRING[24];
		raw : REAL; (*Rohwert*)
		in : REAL; (*skaliertes Einganssignal (standardisierte Verkn�pfungsvariable wurde auf den in outMin und outMax definierten Bereich skaliert) *)
		inMin : REAL; (*untere Skalierungsgrenze Messwert*)
		inMax : REAL; (*obere Skalierungsgrenze Messwert*)
		unit : USINT; (*einheitenindex f�r AlarmRangesFenster *)
		status : USINT; (*statusausgang der klemme (f�r verarbeitung bei abgesetztem HMI ausserhalb des Fehlerarrays)*)
		typeCL : USINT; (*Type der angeh�ngten Reglerlogik (0=unverkn�pft)*)
		type : USINT; (*Type der angeh�ngten IO logik*)
		error : BOOL; (*Eingang gest�rt*)
		isControlled : BOOL; (*Eingang wird einem aktivem Regelkreis zugef�hrt*)
		unitStr : STRING[10]; (*Einheitenstring*)
		indexSlotCL : USINT; (*Slot des angeh�ngten Reglers*)
		indexCL : USINT; (*Index des angeh�ngten Reglers*)
		valid : BOOL; (*wird gesetzt wenn wert das erste mal vom seriellen Protokoll geschrieben wurde*)
	END_STRUCT;
	cI_rem_typ : 	STRUCT 
		alertRanges : ARRAY[0..3]OF REAL; (*untere Grenzen Alarmbereich alarm bei x>range 0-notice 1-critical  alarm bei x<range 2-notice 3-critical (out-skaliert)*)
		alertActive : ARRAY[0..3]OF BOOL; (*Schalter f�r Ein/Ausschalten der Alarme von 0 bis 3*)
	END_STRUCT;
	visu_cI_typ : 	STRUCT 
		conText : STRING[30]; (*index f�r Anschlusstext*)
		CalRuntimeSER : UINT;
		CalRuntimeAll : UINT;
		ColorTitle : INT; (*ColorDatenpunkt Titel*)
		ColorNumeric : INT; (*ColorDatenpunkt Ein/Ausgabefeld*)
		indexSymbol : USINT; (*Symbolindex f�r bitmapgruppe 0-aus; 1;aktiv; 2-fehler*)
		conSymbol : USINT; (*index f�r Anschlusssymbol*)
		active : BOOL; (*Eingang aktiv (gesetzt bei in>inMin)*)
	END_STRUCT;
END_TYPE
