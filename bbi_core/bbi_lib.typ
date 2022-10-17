(********************************************************************
 * COPYRIGHT --  
 ********************************************************************
 * File: Global.typ
 * Author: tilo
 * Created: May 18, 2010
 ********************************************************************
 * Global data types of project MFC_Abgas
 ********************************************************************)

TYPE
	tipButton_typ : 	STRUCT 
		buttonRuntime : UINT;
		tip : BOOL;
		bar : UINT;
	END_STRUCT;
	tower_typ : 	STRUCT 
		moduleOK : BOOL; (*direkt an Buscontroller*)
		lost : BOOL; (*merker falls verbindung nicht da und Zentrale noch an*)
		lastSign : DATE_AND_TIME; (*Zeit beim Tower lost*)
		rawModuleOKX20 : ARRAY[0..nX20]OF BOOL; (*AlarmImage für X20 moduleOK register*)
		microNetInitBusy : BOOL; (*Für Acoposmicro inits*)
	END_STRUCT;
	ackAlerts_typ : 	STRUCT 
		alarmImage : ARRAY[0..nALERTS]OF BOOL; (*AlarmImage für projektspez. Alarme deren quittierung in die logik einfließt*)
		alarmImageSerial : ARRAY[0..nALERTS]OF BOOL; (*AlarmImages für alle seriellen Treiber*)
		alarmImageX20 : ARRAY[0..nX20]OF BOOL; (*AlarmImage für X20 moduleOK register*)
		user : arUserAlerts_typ;
	END_STRUCT;
	arUserAlerts_typ : 	STRUCT 
		HH : ARRAY[0..ncI]OF BOOL;
		H : ARRAY[0..ncI]OF BOOL;
		L : ARRAY[0..ncI]OF BOOL;
		LL : ARRAY[0..ncI]OF BOOL;
	END_STRUCT;
	arUSINT_cI_typ : 	STRUCT 
		slot : ARRAY[0..ncI]OF USINT;
	END_STRUCT;
	arUSINTT_cO_typ : 	STRUCT 
		slot : ARRAY[0..ncO]OF USINT;
	END_STRUCT;
	fileControl_typ : 	STRUCT 
		fileIndex : USINT; (*0=users; 1=valveSave; 2=setup; 10..19 configX (siehe data h)*)
		actFilename : STRING[30];
		Read : BOOL; (*löst einlesen in die in pStruct angegebene Variable aus "filename".csv aus, Flanke fällt mit writeCSVbusy*)
		Write : BOOL; (*löst ablage der in pStruct angegebenen Variablen in "filename".csv aus, Flanke fällt mit writeCSVbusy*)
	END_STRUCT;
	profile_rem_slot_typ : 	STRUCT 
		start : DATE_AND_TIME;
		indexRunning : USINT; (*index auf dem das profil läuft (linear)*)
		status : USINT; (*0-disabled, 1-started*)
		min : REAL;
		max : REAL;
		p1 : ARRAY[0..nPROFILELINPAR]OF UDINT;
		p2 : ARRAY[0..nPROFILELINPAR]OF REAL;
		factor : REAL := 1; (*Faktor mit dem alle p2 multipliziert werden*)
		tag : STRING[31];
		target : USINT; (*0=unbelegt, 1=ausgang, 2 =Sollwert*)
		index : USINT; (*kanal index nullbasiert*)
		type : USINT; (*0=linear*)
	END_STRUCT;
	profile_file_slot_typ : 	STRUCT 
		dat : DATE_AND_TIME;
		changed : BOOL;
		min : REAL;
		max : REAL;
		p1 : ARRAY[0..nPROFILELINPAR]OF UDINT;
		p2 : ARRAY[0..nPROFILELINPAR]OF REAL;
		factor : REAL := 1; (*Faktor mit dem alle p2 multipliziert werden*)
		tag : STRING[31];
		target : USINT; (*0=unbelegt, 1=ausgang, 2 =Sollwert*)
		index : USINT; (*kanal index nullbasiert*)
		type : USINT; (*0=linear*)
	END_STRUCT;
	config_rem_typ : 	STRUCT  (*remanente Kanalinformationen die global verfügbar sein müssen*)
		cCL : ARRAY[0..ncCL]OF cCL_rem_typ;
		cO : ARRAY[0..ncO]OF cO_rem_typ;
		cI : ARRAY[0..ncI]OF cI_rem_typ;
	END_STRUCT;
	config_file_typ : 	STRUCT  (*remanente Kanalinformationen die global verfügbar sein müssen*)
		dateStamp : DATE_AND_TIME; (*Erstellungsdatum*)
		user : USINT; (*NEU: Userlevel des erstellers, nur 2/3 zulässig, alt:Erstellerindex (userArray)*)
		tag : STRING[30]; (*titel*)
		cCL : ARRAY[0..ncCL]OF cCL_rem_typ;
		cO : ARRAY[0..ncO]OF cO_rem_typ;
		cI : ARRAY[0..ncI]OF cI_rem_typ;
		valveState : UDINT; (*legacy, abgelöst mit 64 Kanal erweiterung*)
		changed : BOOL;
	END_STRUCT;
	core_non_typ : 	STRUCT  (*flüchtige Kanalinformationen die global verfügbar sein müssen*)
		cCL : ARRAY[0..ncCL]OF cCL_read_typ;
		cO : ARRAY[0..ncO]OF cO_read_typ;
		cI : ARRAY[0..ncI]OF cI_read_typ;
		lastValidcIList : USINT;
		lastValidcOList : USINT;
		lastValidcCLList : USINT;
		lastValidcI : USINT;
		lastValidcO : USINT;
		lastValidcCL : USINT;
		alarmImage : ARRAY[0..nALERTS]OF BOOL; (*AlarmImage für projektspez. Alarme deren quittierung in die logik einfließt*)
		alarmImageSerial : ARRAY[0..nALERTS]OF BOOL; (*AlarmImage für alle seriellen Kanäle*)
		alarmImageX20 : ARRAY[0..nX20]OF BOOL; (*AlarmImage für X20 moduleOK register*)
		alarmImageUser : arUserAlerts_typ; (*HH,H,L,LL Alarme*)
	END_STRUCT;
	core_rem_typ : 	STRUCT  (*remanenter Anlagenstack der global verfügbar sein muss (Konfiguration und Sequenzstack)*)
		seq : ARRAY[0..nSEQparallel]OF rem_seq_typ; (*remanente infos der laufenden sequenz*)
		config : config_rem_typ; (*aktuelle Konfiguration der Kanäle*)
		profile : ARRAY[0..nPROFILE]OF profile_rem_slot_typ; (*aktuelle Konfiguration der Profile*)
	END_STRUCT;
	ntp_typ : 	STRUCT 
		enable : BOOL;
		serverName1 : STRING[30];
		serverName2 : STRING[30];
		serverName3 : STRING[30];
		serverName4 : STRING[30];
	END_STRUCT;
	netStorage_typ : 	STRUCT 
		enable : BOOL;
		folder : STRING[30];
		serverName : STRING[30];
		user : STRING[30];
		pw : STRING[30];
	END_STRUCT;
	setup_units_typ : 	STRUCT 
		unitPres : USINT;
		unitVol2 : USINT;
		unitVol : USINT;
		unitFlow : USINT;
		unitMass : USINT;
		unitTemp : USINT;
		unitCond : USINT := 1;
	END_STRUCT;
	file_setup_typ : 	STRUCT 
		scrBacklightTurnOffDelayScaled : UINT := 300; (*Delay(sek) bis zum ausschalten der hintergrundbeleuchtung (0=kein abschalten)*)
		enableRAMdebug : BOOL;
		enableRecovery : BOOL := TRUE; (*nur für anlagen ohne hauptschalterüberwachung*)
		enableBeep : BOOL := TRUE;
		enableCustomAlert : ARRAY[0..7]OF BOOL;
		recoveryDelayScaled : REAL := 5.0; (*recoveryzeit in minuten (0=kein recovery) nur für anlagen mit hauptschalterüberwachung*)
		gate : ARRAY[0..3]OF USINT := [192,168,123,214]; (*IP*)
		ip : ARRAY[0..3]OF USINT := [192,168,123,214]; (*IP*)
		snm : ARRAY[0..3]OF USINT := [3(255),0]; (*subnetmask*)
		dhcpActive : BOOL := FALSE; (*DHCP aktivieren*)
		OPC_enable : BOOL := TRUE;
		VNC_enable : BOOL := TRUE;
		VNC_pw_full : STRING[9] := 'bbi';
		VNC_pw_viewwonly : STRING[9] := '1234';
		gaspump : BOOL;
		mplexMeas : ARRAY[0..3]OF UDINT;
		mplexDead : ARRAY[0..3]OF UDINT;
		mplexDest : ARRAY[0..3]OF USINT;
		timeSampler : ARRAY[0..6]OF UDINT := [2000,500,1000,2000,10000,1000,0]; (*zeit für samplerschritte in msec*)
		counter : ARRAY[0..7]OF UDINT;
		netStorage : netStorage_typ;
		ntp : ntp_typ;
		units : setup_units_typ;
		trendAutoTag1 : STRING[23] := 'SIP';
		trendAutoTag2 : STRING[23] := 'FERM';
		trendAutoTag3 : STRING[23] := 'CIP';
		changed : BOOL;
	END_STRUCT;
	visu_tagsdef_typ : 	STRUCT 
		cI : ARRAY[0..64]OF STRING[24];
		cO : ARRAY[0..64]OF STRING[24];
		cCL : ARRAY[0..15]OF STRING[24];
	END_STRUCT;
	visu_tags_typ : 	STRUCT 
		cI : ARRAY[0..64]OF STRING[24];
		cO : ARRAY[0..64]OF STRING[24];
		cCL : ARRAY[0..15]OF STRING[24]; (*feste Anzahl wegen workaround zum erhalt der textgruppe cCL*)
		cCL_W : ARRAY[0..15]OF STRING[24];
		cCL_WCL : ARRAY[0..16]OF STRING[24];
	END_STRUCT;
	visu_typ : 	STRUCT  (*globale Status und Steuerungsdatenpunkte im HMI*)
		newPage : UINT; (*zur laufzeit hier seite anfordern*)
		jumpCL : USINT; (*>0 für Sprung auf Reglerseite noch nicht dynamisiert*)
		calFun1 : USINT; (*für Kalibrierroutine Funktion 1 hier 1/100 + Ein/Ausgangsindex übergeben*)
		activePage : UINT; (*aktuelle Seite von visu wird hier zurückgelesen*)
		ackImageMulti : ARRAY[0..nUNITS]OF ackAlerts_typ; (*Acknowledge image für lokale alarmlisten*)
		indexUNIT : USINT; (*zentraler Umschalter für Mehrfachanlage*)
		tags : visu_tags_typ; (*aktuelle Kanaltags*)
		curUserLevel : USINT; (*gerade angemeldete user ID*)
		curUserID : USINT; (*gerade angemeldete user ID*)
		curUserNick : STRING[30]; (*gerade angemeldeter user String*)
		currentUserBG : USINT; (*indizes für einheiten und hintergrund / sprache.... aktuell geladener Slot aus user.csv*)
		currentUserLanguage : USINT; (*indizes für einheiten und hintergrund / sprache.... aktuell geladener Slot aus user.csv*)
		freeMem : UDINT; (*Bytes freier Speicher partition F*)
		tagsLangAll : ARRAY[0..nLANGUAGES]OF visu_tagsdef_typ; (*projektspezifische Kanaltags für alle Sprachen (hat lokale Textgroups abgelöst)*)
		version : STRING[20]; (*aktuelle Softwareversion*)
		visuString : STRING[15]; (*B&R Pfadstring auf Visualisierungsobjekt für spezielle FUBS*)
		EthernetDevice : STRING[15]; (*B&R Pfadstring auf Ethernetschnittstelle für IP FUBS*)
		atRunning : ARRAY[0..nUNITS]OF BOOL; (*at aufzeichnung läuft*)
		atRunningOnAnyUnit : BOOL;
		blinkSlow : BOOL; (*Blinkgeber für animierte Steuerelemente*)
		blink : BOOL; (*Blinkgeber für animierte Steuerelemente*)
		seqLock : BOOL; (*gesetzt wenn eine Sequenz läuft, die eine Sperrung manueller Eingriffe erfordert*)
		massStorageConnected : BOOL; (*wird gesetzt wenn USB Stick erkannt*)
		filePartLinked : BOOL; (*wird gesetzt wenn SPS erkannt und FileDevices initialisiert wurden*)
		screenSaverActive : BOOL;
		valveToggleTrigger : ARRAY[0..nUNITS]OF USINT; (*usertrigger für manipulation der ventilmatrix in PV seite, einfach toggle index setzen...*)
		valveStateVisu : ARRAY[0..nValves]OF USINT; (*aktuelle Ventil symbol indizes an unit im visu fokus*)
		profileRunningOnThisUnit : BOOL;
		seqRunningOnThisUnit : BOOL;
		anyAlertActive : BOOL;
		anyMessageOpen : BOOL;
	END_STRUCT;
	window_typ : 	STRUCT 
		buttonRuntime : UDINT;
		pageRuntime : UDINT := 1;
		pageOK : BOOL;
		pageClose : BOOL;
		pageClick : BOOL;
	END_STRUCT;
END_TYPE
