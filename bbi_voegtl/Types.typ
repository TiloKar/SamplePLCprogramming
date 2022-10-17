
TYPE
	voegtl_data_frame_typ : 	STRUCT 
		slave : USINT;
		code : USINT;
		count : USINT;
		data : ARRAY[0..255]OF USINT;
	END_STRUCT;
	voegtl_write_frame_typ : 	STRUCT 
		slave : USINT;
		code : USINT;
		register0 : USINT;
		register1 : USINT;
		num0 : USINT;
		num1 : USINT;
		byteCount : USINT;
		data : ARRAY[0..99]OF USINT;
	END_STRUCT;
	voegtl_read_frame_typ : 	STRUCT 
		slave : USINT;
		code : USINT;
		register0 : USINT;
		register1 : USINT;
		num0 : USINT;
		num1 : USINT;
		crc16_0 : USINT;
		crc16_1 : USINT;
	END_STRUCT;
END_TYPE
