
TYPE
	batchf_headerA_typ : 	STRUCT 
		del : ARRAY[0..1]OF USINT := [2(35)]; (*Delimeter Head A start*)
		firstDat : DATE_AND_TIME; (*first Time Stamp in File*)
		lastDat : DATE_AND_TIME; (*last Time Stamp in File*)
		lineCount : UDINT; (*count of Data lines*)
		samplingRate : UDINT := 30; (*sec*)
		ident : UDINT; (*specific xCUBIO Identifier, wird nicht geprüft*)
		isAT : USINT; (*specific structure revision, obsolet*)
		treshold : USINT := 1; (*treshold (decay, not used)*)
		batchState : USINT; (*0 = running 255 = finalized*)
		anzcI : USINT := ncI; (*count of input channels on xCUBIO*)
		anzcCL : USINT := ncCL; (*count of Control loops on xCUBIO*)
		anzcO : USINT := ncO; (*count of output channels on xCUBIO*)
		tag : STRING[40]; (*filename of trend on xCUBIO*)
		comment : STRING[252] := 'init comment'; (*comment for user*)
		inoculumDat : DATE_AND_TIME;
		variant : ARRAY[0..1023]OF USINT;
	END_STRUCT;
	batchf_headerB_typ : 	STRUCT  (*variable größe*)
		del1 : ARRAY[0..3]OF USINT := [4(40)]; (*Delimeter Head B start*)
		tags : trend_units_typ; (*Channel name strings*)
		CRLF : ARRAY[0..3]OF USINT := [40,40,13,10]; (*cosmetic break*)
		units : trend_units_typ; (*Channel unit strings*)
		CRC_B : UDINT; (*Checksum Head B*)
		endB : ARRAY[0..3]OF USINT := [40,40,13,10];
	END_STRUCT;
	batchf_header_typ : 	STRUCT  (*HEAD A with a fixed data range*)
		A : batchf_headerA_typ;
		CRC_A : UDINT; (*Checksum head A*)
		endA : ARRAY[0..3]OF USINT := [35,35,13,10]; (*Delimeter Head A end*)
		B : batchf_headerB_typ; (*HEAD B with variable data range based on Information in HEAD A*)
	END_STRUCT;
	batchf_max_dataA_typ : 	STRUCT  (*DATA LINE fixed header A*)
		del : ARRAY[0..3]OF USINT := [DATA_LINE_STARTCHAR1,DATA_LINE_STARTCHAR2,DATA_LINE_STARTCHAR3,DATA_LINE_STARTCHAR4]; (*Delimeter Data line start*)
		t : DATE_AND_TIME; (*Time Stamp Data line*)
		cI_changed : ARRAY[0..1]OF UDINT; (*32 Bit Arrray for input channels 1=changed 0 = use value from last data line*)
		cCL_changed : ARRAY[0..1]OF UDINT; (*32 Bit Arrray for control loop channels 1=changed 0 = use value from last data line*)
		cO_changed : ARRAY[0..1]OF UDINT; (*32 Bit Arrray for output channels 1=changed 0 = use value from last data line*)
	END_STRUCT;
	batchf_max_dataB_typ : 	STRUCT  (*variable data line*)
		value_cI : ARRAY[0..63]OF REAL; (*variable count of 4 byte float values (as much as bits set in Data Header)*)
		value_cCL : ARRAY[0..15]OF REAL; (*variable count of 4 byte float values (as much as bits set in Data Header)*)
		value_cO : ARRAY[0..63]OF REAL; (*variable count of 4 byte float values (as much as bits set in Data Header)*)
		CRC : UDINT; (*Checksum for Data*)
		end : ARRAY[0..3]OF USINT := [DATA_LINE_ENDCHAR,DATA_LINE_ENDCHAR,13,10]; (*End delimeter*)
	END_STRUCT;
	batchf_max_data_typ : 	STRUCT  (*DATA LINE with maximal data range*)
		A : batchf_max_dataA_typ;
		B : batchf_max_dataB_typ;
	END_STRUCT;
	file_diag_ctrl_typ : 	STRUCT 
		pathValid : BOOL; (*wird gesetzt wenn, gültiger Pfad erzeugt wurde*)
		aborted : BOOL; (*wird mit Nutzerabbruch gesetzt*)
		read : BOOL; (*Datei und Ordnernamen lesen*)
		dirPath : STRING[255];
		fileName : STRING[100];
		PAR : USINT; (*0=Import von USB 1= wählen von INTERN für CSVfull 4= Löschen Trendfiles INTERN 5=wählen von INTERN für visu füllen 6=wählen von INTERN für Export*)
		STATUS : USINT;
		pageRuntime : UINT := 1;
		offset : USINT;
		evaluate : BOOL;
	END_STRUCT;
	file_diag_list_typ : 	STRUCT 
		type : BOOL;
		filename : STRING[100];
		tim : DATE_AND_TIME;
		size : UDINT;
	END_STRUCT;
	fTrendExportBar_typ : 	STRUCT 
		bar : USINT;
		barXValue : USINT;
		barXStart : USINT;
		barXEnd : USINT;
	END_STRUCT;
	rem_trend_typ : 	STRUCT 
		tag : STRING[19] := 'unused'; (*Template name*)
		Ymax : ARRAY[0..nTRENDCHANNELS]OF REAL;
		Ymin : ARRAY[0..nTRENDCHANNELS]OF REAL;
		index : ARRAY[0..nTRENDCHANNELS]OF USINT;
		type : ARRAY[0..nTRENDCHANNELS]OF USINT;
		range : UDINT; (*obsolet, x-achsen einstellungen nicht mehr teil der config*)
		offset : UDINT; (*obsolet, x-achsen einstellungen nicht mehr teil der config*)
		autoRange : BOOL; (*obsolet, x-achsen einstellungen nicht mehr teil der config*)
		autoOffset : BOOL; (*obsolet, x-achsen einstellungen nicht mehr teil der config*)
		changed : BOOL;
	END_STRUCT;
	scale_typ : 	STRUCT 
		scroll : REAL;
		zoom : REAL;
	END_STRUCT;
	trendCtrlError_typ : 	STRUCT 
		errorString : STRING[100];
		errorSta : USINT;
		errorFub : UINT;
		errorStep : USINT;
		openerrors : USINT;
		openErrorCode : UINT;
	END_STRUCT;
	trendReadCtrl_typ : 	STRUCT 
		error : trendCtrlError_typ;
		CMD : USINT;
		STATUS : USINT;
		IDLE : BOOL;
		numSkippedRawBytes : UDINT;
		numSkippedRawSamplesCRC : UDINT;
		numSkippedRawSamplesTimeErr : UDINT;
		numSkippedTimeouts : UDINT;
		lastFileOpenLen : UDINT;
		pAllocated : UDINT; (*startzeiger auf DRAM Block der die Trend Rohdaten enthällt*)
		partPercentFree : USINT;
		partIdent : UDINT; (*zeiger auf handle für nutzerpartition*)
		offset : DATE_AND_TIME; (*offset als absolutzeit ab dem geplottet werden soll*)
		range : UDINT; (*range in sekunden über den geplottet werden soll*)
		selectedTypeY : ARRAY[0..nTRENDCHANNELS]OF USINT; (*gewählter Kanaltyp auf Y-Achse (Vorfilter)*)
		selectedIndexY : ARRAY[0..nTRENDCHANNELS]OF USINT; (*gewählter Kanalindex auf Y-Achse*)
		minPlotted : ARRAY[0..nTRENDCHANNELS]OF REAL; (*autoscale wertebereichsgrenze*)
		maxPlotted : ARRAY[0..nTRENDCHANNELS]OF REAL; (*autoscale wertebereichsgrenze*)
		CSVfilesMade : UDINT;
		CSVlinesWritten : UDINT;
		trendSamplesPlotted : UDINT;
		rawBuffersRead : UDINT;
		rawSamplesRead : UDINT;
		percentRead : USINT;
	END_STRUCT;
	trendStack_typ : 	STRUCT 
		cI : ARRAY[0..ncI]OF REAL;
		cCL : ARRAY[0..ncCL]OF REAL;
		cO : ARRAY[0..ncO]OF REAL;
	END_STRUCT;
	trendWriteCtrl_typ : 	STRUCT 
		samplingRate : UDINT := 30;
		comment : STRING[255] := 'Kommentar einfügen';
		isAT : BOOL;
		inoculate : BOOL;
		dumpCtrl : USINT;
		error : trendCtrlError_typ;
		CMD : USINT;
		STATUS : USINT;
		eventsInFile : UDINT;
		info : batchf_headerA_typ;
	END_STRUCT;
	trendXrange_typ : 	STRUCT 
		minScaled : UDINT;
		currentSliderRTDP : UINT;
		currentSliderScaled : UDINT;
		maxScaled : UDINT;
		completion : BOOL;
		RTDP : UINT;
		usedValue : UDINT;
		auto : BOOL;
		autoCompletion : BOOL;
	END_STRUCT;
	trendXoffset_typ : 	STRUCT 
		currentSliderRTDP : UINT;
		currentSliderScaled : UDINT;
		maxScaled : UDINT;
		completion : BOOL;
		RTDP : UINT;
		inoValue : DATE_AND_TIME;
		relValue : DATE_AND_TIME;
		absValue : DATE_AND_TIME;
		usedValue : UDINT;
		auto : BOOL;
		autoCompletion : BOOL;
	END_STRUCT;
	trendX_typ : 	STRUCT 
		cursorHistSetPositionSlider : UDINT;
		cursorHistSetPositionCompletion : BOOL;
		cursorAgeVisuIno : REAL; (*berechnete Relativzeit in Sekunden am Cursor bezogen auf Ino*)
		cursorAgeVisu : UDINT; (*berechnete Relativzeit in Sekunden am Cursor bezogen auf Start*)
		cursorTimeDT : DATE_AND_TIME; (*Absolutzeit am cursor*)
		inoAxisRTDP : UINT;
		inoCursorRTDP : UINT;
		cursorInoSetPositionDP : REAL; (*An trendobjekt anschließen (manipulation der position)*)
		cursorHistSetPositionDP : REAL; (*An trendobjekt anschließen (manipulation der position)*)
		calcLastSampleTime : DATE_AND_TIME;
		autoXRTDP : UINT;
		winX : window_typ;
		range : trendXrange_typ;
		offset : trendXoffset_typ;
	END_STRUCT;
	trendY_typ : 	STRUCT 
		autoscale : BOOL;
		indexYaxis : USINT := 0; (*index der Y-Achse auf die die Pseudoreferenz zeigt*)
		winY : window_typ;
		countForAll : UINT := TRENDITEMS+1; (*statisch für alle Achsen*)
		channelY : ARRAY[0..nTRENDCHANNELS]OF trend_recorder_channel_typ; (*alle Datenpunkte die für jede Achse existieren*)
		Ymin_min : REAL;
		Ymax_max : REAL;
		Ymin : REAL;
		Ymax : REAL;
		Ycompletion : BOOL;
		unit : UINT;
		samplingRateMSec : UDINT;
	END_STRUCT;
	trend_read_channel_typ : 	STRUCT 
		item : ARRAY[0..TRENDITEMS]OF REAL;
	END_STRUCT;
	trend_recorder_channel_typ : 	STRUCT 
		historical : REAL; (*direkt an TrendCurveY Cursor Datenpunkt anschließen, gleiche refUnit wie Y-Werte*)
		current : REAL; (*aktueller Wert des Kanals aus core*)
		min : REAL := 0; (*TrendData minDatapoint, muss mit Kanalgrenze aus core beschrieben sein, gleiche refUnit wie Y-Werte*)
		max : REAL := 100; (*TrendData maxDatapoint, muss mit Kanalgrenze aus core beschrieben sein, gleiche refUnit wie Y-Werte*)
		bgYruntime : UINT := 1; (*RTDP für Hintergrund der Ziel der Y-Achspseudoreferenz anzeigt*)
		indexUnit : UINT; (*refUnit Y-Achse Datenpunkt*)
		cI_image_index : BOOL; (*Datenpunkt für Bitmapgruppe am Vorfilter-Button*)
		cCL_image_index : BOOL; (*Datenpunkt für Bitmapgruppe am Vorfilter-Button*)
		hide_image_index : BOOL; (*Datenpunkt für Bitmapgruppe am Vorfilter-Button*)
		cO_image_index : BOOL; (*Datenpunkt für Bitmapgruppe am Vorfilter-Button*)
		cI_ListRuntime : UINT; (*Datenpunkt für selektive Anzeige von Y-Achssteuerelementen je nach Vorfilter*)
		cCL_ListRuntime : UINT; (*Datenpunkt für selektive Anzeige von Y-Achssteuerelementen je nach Vorfilter*)
		cO_ListRuntime : UINT; (*Datenpunkt für selektive Anzeige von Y-Achssteuerelementen je nach Vorfilter*)
		ScrollY : REAL := 0; (*tatsächlicher DP zum Anschluss an Trendobjekt*)
		ZoomY : REAL := 1; (*tatsächlicher DP zum Anschluss an Trendobjekt*)
		hideRTDP : UINT; (*RTDP zum kompletten verstecken von Steuerelementen wenn vorFilter deaktiviert*)
	END_STRUCT;
	trend_units_typ : 	STRUCT 
		cI : ARRAY[0..63]OF STRING[24];
		cO : ARRAY[0..63]OF STRING[24];
		cCL : ARRAY[0..15]OF STRING[24];
	END_STRUCT;
	window_recConfig_typ : 	STRUCT 
		load : BOOL;
		windowNewTag : window_typ;
		window : window_typ;
		index : USINT;
		tags : ARRAY[0..9]OF STRING[19];
	END_STRUCT;
END_TYPE
