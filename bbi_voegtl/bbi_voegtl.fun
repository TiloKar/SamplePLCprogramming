
FUNCTION_BLOCK fVoegtl
	VAR_INPUT
		pcal : ARRAY[0..nVGTL] OF UDINT;
		pcO : ARRAY[0..nVGTL] OF UDINT;
		pcOr : ARRAY[0..nVGTL] OF UDINT;
		pcI : ARRAY[0..nVGTL] OF UDINT;
		deviceString : STRING[80] := 'SL1.SS1.IF1.ST2.IF1'; (*Parameterstring Schnittstelle*)
		enable : BOOL;
	END_VAR
	VAR_OUTPUT
		errorImage : ARRAY[0..nVGTL] OF BOOL;
		status : USINT;
		error2 : ARRAY[0..nVGTL] OF UINT;
		error1 : ARRAY[0..nVGTL] OF UINT;
		lastErrorLine : ARRAY[0..nVGTL] OF USINT;
		lineStatus : ARRAY[0..nVGTL] OF USINT;
		slaveAdr : ARRAY[0..nVGTL] OF USINT;
	END_VAR
	VAR
		errorCount : ARRAY[0..nVGTL] OF USINT;
		preLineError : USINT;
		step : USINT;
		memIn : ARRAY[0..255] OF USINT;
		PV : ARRAY[0..nVGTL] OF REAL;
		SP : ARRAY[0..nVGTL] OF REAL;
		memOut : ARRAY[0..255] OF USINT;
		FRM_close_0 : FRM_close;
		FRM_xopen_0 : FRM_xopen;
		FRM_read_0 : FRM_read;
		lastValidIndex : USINT;
		FRM_rbuf_0 : FRM_rbuf;
		FRM_robuf_0 : FRM_robuf;
		FRM_write_0 : FRM_write;
		TON_0 : TON;
		timeout_responseframe : TON;
		XOPENCONFIG_0 : XOPENCONFIG;
		k : USINT;
		i : USINT;
		enabled : BOOL;
		acOr : REFERENCE TO cO_read_typ;
		acO : REFERENCE TO cO_rem_typ;
	END_VAR
	VAR CONSTANT
		STR_OPEN : STRING[255] := '/BD=9600 /PA=N /DB=8 /SB=2 /PHY=RS485 /TIT=8 /RIT=8';
	END_VAR
	VAR
		responseDebug41 : voegtl_data_frame_typ;
		responseDebug54 : voegtl_data_frame_typ;
		responseDebug43 : voegtl_data_frame_typ;
		response : voegtl_data_frame_typ;
		write : voegtl_write_frame_typ;
		read : voegtl_read_frame_typ;
		hlplen : UINT;
		crc : UINT;
		acI : REFERENCE TO cI_read_typ;
		acal : REFERENCE TO cCal_typ;
		value : REAL;
		lineInit : ARRAY[0..nVGTL] OF BOOL;
		init : BOOL;
		ident : UDINT;
	END_VAR
END_FUNCTION_BLOCK
