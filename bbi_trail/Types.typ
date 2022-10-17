
TYPE
	trail_buffer_entry_typ : 	STRUCT 
		dat : DATE_AND_TIME;
		ID : UDINT;
		new1 : REAL; (*neuer Prozesswert Real*)
		par1 : UDINT;
		par2 : UDINT;
		string1 : STRING[254];
	END_STRUCT;
	trail_buffer_typ : 	STRUCT 
		firstPushed : UINT;
		nextPush : UINT;
		value : ARRAY[0..TRAIL_ENTRIES]OF trail_buffer_entry_typ;
	END_STRUCT;
	eventRecordHeader_typ : 	STRUCT 
		deviceident : UDINT; (*Anlagen Id, Batchident*)
		maxBufCount : UDINT; (*Maxiamlanzahl der Events im buffer (statistik)*)
		maxBufSize : UDINT; (*Maximale Datengröße der dateiaktion(statistik)*)
		records : UDINT; (*anzahl der geschriebenen events*)
		crcHeader : UDINT; (*prüfsumme header*)
	END_STRUCT;
END_TYPE
