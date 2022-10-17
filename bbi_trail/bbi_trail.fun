
FUNCTION_BLOCK fMakeEventData
	VAR_INPUT
		pATbuf : UDINT;
		time : DATE_AND_TIME;
	END_VAR
	VAR_OUTPUT
		data : ARRAY[0..1023] OF USINT; (*könnte aus sicht der aufrufenden instanz auch dataLen heißen*)
		offset : UDINT;
	END_VAR
	VAR
		payloadCountPosition : UDINT;
		CRC : REFERENCE TO UDINT;
		aUDINT : REFERENCE TO UDINT;
		aReal : REFERENCE TO REAL;
		aCRLF : REFERENCE TO ARRAY[0..3] OF USINT;
		i : UINT;
		ebuf : REFERENCE TO trail_buffer_typ;
		indexBuf : UINT;
		e : trail_buffer_entry_typ;
		toMuchData : BOOL;
		eventsToPop : UINT;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION addEvent : UINT (*an cal.isAT hängen*)
	VAR_INPUT
		enable : BOOL;
		pBuf : UDINT;
		event : trail_buffer_entry_typ;
	END_VAR
	VAR
		count : UINT;
		buf : REFERENCE TO trail_buffer_typ;
		e : trail_buffer_entry_typ;
	END_VAR
END_FUNCTION
