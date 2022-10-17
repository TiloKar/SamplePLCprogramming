
FUNCTION fFileFilter : BOOL
	VAR_INPUT
		filter : USINT;
		strlen : INT;
		pString : UDINT;
	END_VAR
	VAR
		i : INT;
		aChar : REFERENCE TO USINT;
		lastPoint : INT;
		aString : REFERENCE TO STRING[40];
	END_VAR
END_FUNCTION

FUNCTION_BLOCK fMakeTrendData
	VAR_INPUT
		ncCLthis : USINT;
		ncOthis : USINT;
		ncIthis : USINT;
		stack : trendStack_typ;
		time : DATE_AND_TIME;
		new : BOOL;
	END_VAR
	VAR_OUTPUT
		data : ARRAY[0..1023] OF USINT;
		dataLen : UDINT;
	END_VAR
	VAR
		dataLineTrend : batchf_max_data_typ;
		oldstack : trendStack_typ;
		CRC : REFERENCE TO UDINT;
		aUDINT : REFERENCE TO UDINT;
		aReal : REFERENCE TO REAL;
		aCRLF : REFERENCE TO ARRAY[0..3] OF USINT;
		count : USINT;
		i : USINT;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fTrendRead
	VAR_IN_OUT
		c : trendReadCtrl_typ;
		y : ARRAY[0..nTRENDCHANNELS] OF trend_read_channel_typ;
	END_VAR
	VAR
		cCLmax : USINT;
		cOmax : USINT;
		cImax : USINT;
		allChannelsMax : USINT; (*Anzahl!! aller kanäle in erster Datenzeile (Vollbelegung)*)
		allchannelsThisSample : USINT; (*Anzahl der Kanäle im neuen Sample*)
		curAge : REAL; (*batchage in der gerade geschriebene CSV Zeile*)
		DirCreate_0 : DirCreate;
		FileCreate_0 : FileCreate;
		FileOpen_0 : FileOpen;
		FileWriteEx_0 : FileWriteEx;
		FileClose_0 : FileClose;
		identCSV : UDINT;
		CRCB : UDINT;
		CRCA : UDINT;
		copyHeader : {REDUND_UNREPLICABLE} batchf_header_typ;
		aHead : REFERENCE TO batchf_header_typ;
		aDataA : REFERENCE TO batchf_max_dataA_typ;
		aCRC : REFERENCE TO UDINT;
		aReal : REFERENCE TO REAL;
		hlpstr2 : STRING[5];
		hlpstr : STRING[100];
		dataDel : ARRAY[0..3] OF USINT := [DATA_LINE_STARTCHAR1,DATA_LINE_STARTCHAR2,DATA_LINE_STARTCHAR3,DATA_LINE_STARTCHAR4]; (*Datenpaket Markierung*)
		targetTimeOffsetMsec : UDINT; (*Msec Übertrag aus letztem Plotting als Offset für nächtes Plotten*)
		targetTimeIncMsec : UDINT; (*Increment für Zielzeit in Msec*)
		targetTimeSecAbs : UDINT; (*!!absolute!! Zielzeit in Sekunden für Trendobjekt Sample*)
		dT : UDINT; (*Rohsample Zeitdifferen in Msec*)
		tx : UDINT; (*Interpolationspunkt in Msec zwischen den Rohsamples*)
		bufReadTrend : UDINT; (*fertig verarbeitete bytes im aktuellen Trend Puffer Block*)
		buflenCSV : UDINT; (*fertig aufbereitet bytes im CSV Schreibpuffer*)
		lastV : ARRAY[0..ALLCHANNELS] OF REAL; (*letzte entpackte Datenzeile *)
		curV : ARRAY[0..ALLCHANNELS] OF REAL; (*aktuell entpackte Datenzeile *)
		bufCSV : ARRAY[0..CSV_W_BUFSIZE] OF USINT; (*Schreibepuffer für CSV Datei*)
		skip : BOOL;
		lastT : UDINT;
		curT : UDINT;
		dY : ARRAY[0..nTRENDCHANNELS] OF REAL;
		Y2 : ARRAY[0..nTRENDCHANNELS] OF REAL;
		Y1 : ARRAY[0..nTRENDCHANNELS] OF REAL;
		i : USINT;
	END_VAR
	VAR CONSTANT
		SEMI : USINT := 59;
		CRLF : ARRAY[0..1] OF USINT := [13,10];
	END_VAR
	VAR
		timeGapRawSamples : UDINT; (*workaround zur ausreißererkennung*)
		indexOffset : USINT;
		STEP : USINT;
		offsetCSVFile : UDINT; (*Offset in der Augabedatei für Blockweises schreiben*)
		offsetTrendFile : UDINT;
		draw : BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fTrendWrite
	VAR_INPUT
		time : DATE_AND_TIME;
		freeMem : UDINT;
		filename : STRING[40]; (*Dateiname*)
		indexUnit : USINT;
		pATbuf : UDINT;
		pNon : UDINT;
		pRem : UDINT;
		enable : BOOL;
	END_VAR
	VAR_IN_OUT
		c : trendWriteCtrl_typ;
	END_VAR
	VAR
		lastFullSample : UDINT;
		hlpstr : STRING[100];
		aDel : REFERENCE TO ARRAY[0..3] OF USINT;
		bufoff : ARRAY[0..BATCH_OFFSETSEARCH] OF USINT;
		bufh_event_out : eventRecordHeader_typ;
		bufh_event_in : eventRecordHeader_typ;
		bufh_out : batchf_header_typ;
		bufh_in : batchf_header_typ;
		difOffset : UDINT;
		i : UDINT;
		gotOffset : BOOL;
		FileCreate_0 : FileCreate;
		FileClose_0 : FileClose;
		fMakeEventData_0 : fMakeEventData;
		fMakeTrendData_0 : fMakeTrendData;
		FileWrite_0 : FileWrite;
		debug1 : UDINT;
		FileReadEx_0 : FileReadEx;
	END_VAR
	VAR
		DirCreate_0 : DirCreate;
		FileOpen_0 : FileOpen;
		fileIdentEvent : UDINT;
		fileIdent : UDINT;
		fileOpenLenEvent : UDINT;
		fileOpenLen : UDINT;
		aNon : REFERENCE TO core_non_typ;
		aRem : REFERENCE TO config_rem_typ;
		countCloseRaw : USINT;
		countOpenRaw : USINT;
		STEP : USINT;
		stack : statusStack;
		ebuf : REFERENCE TO trail_buffer_typ;
		lastPop : UDINT;
		eventsToPop : UINT;
		e : trail_buffer_entry_typ;
		debug : USINT;
	END_VAR
END_FUNCTION_BLOCK
