
FUNCTION_BLOCK statusStack
	VAR_INPUT
		in : USINT;
	END_VAR
	VAR_OUTPUT
		toString : STRING[80];
	END_VAR
	VAR
		i : USINT;
		hlpstr : STRING[80];
		next : USINT;
	END_VAR
	VAR CONSTANT
		MAXSIZE : USINT := 10;
	END_VAR
	VAR
		size : USINT;
		stack : ARRAY[0..MAXSIZE] OF USINT;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION fLoadConfig : BOOL
	VAR_INPUT
		info : core_non_typ;
		src : config_file_typ;
	END_VAR
	VAR_IN_OUT
		dst : config_rem_typ;
	END_VAR
	VAR
		i : USINT;
	END_VAR
END_FUNCTION

FUNCTION fReplaceChar : INT
	VAR_INPUT
		charOld : USINT;
		charNew : USINT;
		strlen : INT;
		pString : UDINT;
	END_VAR
	VAR
		i : INT;
		aChar : REFERENCE TO USINT;
	END_VAR
END_FUNCTION

FUNCTION fFindLastChar : INT
	VAR_INPUT
		char : USINT;
		strlen : INT;
		pString : UDINT;
	END_VAR
	VAR
		i : INT;
		aChar : REFERENCE TO USINT;
	END_VAR
END_FUNCTION

FUNCTION fFindFirstChar : UDINT
	VAR_INPUT
		char : USINT;
		strlen : UDINT;
		pString : UDINT;
	END_VAR
	VAR
		i : UDINT;
		aChar : REFERENCE TO USINT;
	END_VAR
END_FUNCTION

FUNCTION finvertBytes : USINT
	VAR_INPUT
		pValue : UDINT;
		bytecount : USINT;
	END_VAR
	VAR
		raw : ARRAY[0..1] OF USINT;
		aUDINT : REFERENCE TO ARRAY[0..3] OF USINT;
		aUINT : REFERENCE TO ARRAY[0..1] OF USINT;
	END_VAR
END_FUNCTION

FUNCTION_BLOCK fScale
	VAR_INPUT
		enable : BOOL;
		x : REAL;
		x1 : REAL;
		y1 : REAL;
		x2 : REAL;
		y2 : REAL;
	END_VAR
	VAR_OUTPUT
		y : REAL;
	END_VAR
	VAR
		b : REAL;
		a : REAL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fAlertExportGET
	VAR_INPUT
		visu : STRING[100] := 'Visu';
	END_VAR
	VAR_OUTPUT
		buf_out_len : DINT;
		buf_out : ARRAY[0..ALERTBUFSIZE] OF USINT;
		status : UINT;
	END_VAR
	VAR
		VC_HANDLE : UDINT;
		CRLF : ARRAY[0..1] OF USINT := [13,10];
		byStep : USINT;
		status_int : UINT;
		len_int : DINT;
		hlpstr : STRING[100] := '#################################################################################################';
		error_status : UINT;
		error_stp : USINT;
		header : STRING[67] := 'DD.MM.YY_HH:MM:SS;Group-Nr;Alarm-Nr;Alarmtext;ACK-State;Alarm-State';
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK fAlertExportWRITE
	VAR_INPUT
		device : STRING[100] := 'Visu';
		visu : STRING[100] := 'Visu';
	END_VAR
	VAR_OUTPUT
		status : UINT;
	END_VAR
	VAR_IN_OUT
		export : BOOL;
	END_VAR
	VAR
		FileOpen_0 : FileOpen;
		FileClose_0 : FileClose;
		FileCreate_0 : FileCreate;
		FileWrite_0 : FileWrite;
		FileDelete_0 : FileDelete;
		byStep : USINT;
		fAlertExportGET_0 : fAlertExportGET;
		error : BOOL;
		error_status : UINT;
		error_step : USINT;
		delFile : BOOL;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION fDisableAll : BOOL
	VAR_IN_OUT
		non : core_non_typ;
		rem : core_rem_typ;
	END_VAR
	VAR
		i : USINT;
	END_VAR
END_FUNCTION

FUNCTION fGetUnit : UINT
	VAR_INPUT
		raw : USINT;
		setup : setup_units_typ;
	END_VAR
END_FUNCTION

FUNCTION_BLOCK fgetUnitString
	VAR_INPUT
		unit : USINT;
	END_VAR
	VAR_OUTPUT
		out : STRING[24];
	END_VAR
END_FUNCTION_BLOCK

FUNCTION fTrunc_DINT : DINT (*nimmt einen anteil der Auflösung durch Division und anschließende multiplikation mit d*)
	VAR_INPUT
		IN : DINT;
		d : DINT;
	END_VAR
END_FUNCTION

FUNCTION hexexp : UDINT
	VAR_INPUT
		in : USINT;
	END_VAR
END_FUNCTION

FUNCTION hexstr4todec : UDINT
	VAR_INPUT
		pString : UDINT;
	END_VAR
	VAR
		hlp : ARRAY[0..3] OF USINT;
	END_VAR
END_FUNCTION

FUNCTION crcmodbus : UINT
	VAR_INPUT
		pmem : UDINT;
		plen : UINT;
	END_VAR
	VAR
		crc_input : UINT;
		i : UINT;
		n : UINT;
		mem : REFERENCE TO USINT;
	END_VAR
END_FUNCTION

FUNCTION fFindLastNumber : UDINT
	VAR_INPUT
		strlen : UDINT;
		pString : UDINT;
	END_VAR
	VAR
		i : UDINT;
		aChar : REFERENCE TO USINT;
	END_VAR
END_FUNCTION

FUNCTION fFindFirstNumber : UDINT
	VAR_INPUT
		strlen : UDINT;
		pString : UDINT;
	END_VAR
	VAR
		i : UDINT;
		aChar : REFERENCE TO USINT;
	END_VAR
END_FUNCTION

FUNCTION BITCLR : BOOL
	VAR_INPUT
		pIN : UDINT;
		setPos : UDINT;
	END_VAR
	VAR
		aIN : REFERENCE TO USINT;
		exponent : UDINT;
		targetBlockMask : USINT;
		targetBlock : UDINT;
	END_VAR
END_FUNCTION

FUNCTION BITSET : BOOL
	VAR_INPUT
		pIN : UDINT;
		setPos : UDINT;
	END_VAR
	VAR
		aIN : REFERENCE TO USINT;
		exponent : UDINT;
		targetBlockMask : USINT;
		targetBlock : UDINT;
	END_VAR
END_FUNCTION

FUNCTION BITTST : BOOL
	VAR_INPUT
		pIN : UDINT;
		tstPos : UDINT;
	END_VAR
	VAR
		aIN : REFERENCE TO USINT;
		exponent : UDINT;
		targetBlockMask : USINT;
		targetBlock : UDINT;
	END_VAR
END_FUNCTION

FUNCTION BITCNT : USINT
	VAR_INPUT
		pIN : UDINT;
		cntLen : UDINT;
	END_VAR
	VAR
		BITCNT32 : UDINT;
		i : UDINT;
		v : UDINT;
		lastBlockMask : UDINT;
		lastBlock : UDINT;
		aIN : REFERENCE TO UDINT;
		scount : SINT;
	END_VAR
END_FUNCTION

FUNCTION CRC32 : UDINT
	VAR_INPUT
		plen : UDINT;
		pmem : UDINT;
		gen : UDINT;
	END_VAR
	VAR
		n : UDINT;
		i : USINT;
		indata : USINT;
		crc_input : UDINT;
		mem : REFERENCE TO USINT;
	END_VAR
END_FUNCTION
