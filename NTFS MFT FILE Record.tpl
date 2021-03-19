template "NTFS MFT FILE Record"

// Costas Katsavounidis - 2021.1a
// kacos2000 [at] gmail.com
// https://github.com/kacos2000
//
// To be applied to the NTFS Master File Table's (MFT's) FILE records.
// Fix-up values are not corrected/replaced which will result in errors.

description "Applicable to MFT FILE Records"
applies_to file/disk //Can be used with MFT file only
sector-aligned 
read-only           //Just in case
//multiple 1024

// -------------------------HEADER---------------------------------
begin
	Section "Header"
    char[4]	"Signature" // eg. FILE, BAAD, etc
	uint16	"Offset to update sequence"
	uint16	"Number of fix up byte pairs" // usually 3
	int64	"Logfile sequence number"     // LSN
	uint16	"Record Sequence Number"      // Number of times this record was re-used
	uint16 	"Hard-link count"
	uint16	"Offset_to_first_attribute"
	hex 2   "Flags"
	move -2
	uint_flex "0" "-Bit 15 - In Use"
    move -4
    uint_flex "1" "-Bit 14 - 0 = File, 1 = Directory" // Directory =  has Index_Root attribute
    move -4
    uint_flex "2" "-Bit 13 - Is in Extend Directory"	
    move -4
    uint_flex "3" "-Bit 12 - Has View_Index" //(other than I30)
    move -2
    uint32	"Logical_size_of_this_record"
    uint32	"Physical_size_of_this_record"
    uint48	"Base record (0= itself)"
    uint16	"Base record Sequence Number"
    uint16	"Next_available_attribute_ID"   // The ID nr that will be assigned to the next attribute
    move 2
    uint32 "MFT record Nr"                  // MFT record Number
	
	goto "Offset to update sequence"
    hex 2       "FixUp"
    move -2
	uint16		"Update sequence number"
	hex 2       "Fixup_Value 1" // replaces 0x1FE
    hex 2       "Fixup_Value 2" // replaces 0x3FE
    endsection // End of Header section
	
    // ------------------------ATTRIBUTES--------------------------------------
    //Process General Attribute info
    goto Offset_to_first_attribute
    numbering 1
	{   
        Section "Attribute"

        hexadecimal uint32 "Attribute_type"
		IfEqual "Attribute_type" 4294967295 // "FFFFFFFF" = end of Attributes
            endsection
			ExitLoop
		EndIf
        IfEqual "Attribute_type" 0 // "00000000" = unused or invalid Attribute type
            endsection
			ExitLoop
		EndIf
        
		uint16 "Attribute_length" // Get the Length of the attribute

        IfEqual "Attribute_length" 0  // Skip loop if Length is 0
            endsection
			ExitLoop
		EndIf

		move 2
		uint8   "Resident_(1=non-resident)"
        uint8   "Length_of_Stream_Name" // Nr. of Unicode characters 
        uint16  "Offset_to_Stream_Name" // From start of the Attribute
        uint16  "Attribute Flags"
		uint16  "Attribute ID"
        uint32  "Size_of_Resident_Content"
        uint16  "Content_offset"
        uint8   "Indexed flag (1= Indexed)"
        move    -23 // Go back to start of the Attribute

        // Get NON-RESIDENT Attribute info
        // ................................................................
        IfEqual "Resident_(1=non-resident)"  1
            move    (Content_offset+(16))            
            int64   "Start VCN"
            int64   "End VCN"
            uint16  "Datarun_Offset"
            uint16  "Compression Unit Size"
            move 4  // Skip padding bytes
            int64   "Allocated size"
            int64  "Actual size"
            int64   "Initialized size"
            move    -64 // Return to start of the Content
            move    "Datarun_Offset"   // Jump to Datarun offset
            hex     ((Attribute_length)-(Datarun_Offset)) "Datarun"
            move    (Datarun_Offset*(-1))
            move    (((Attribute_length)-(Datarun_Offset))*(-1))
            move    (Content_offset*(-1)) // Return to start of the Attribute
        EndIf

        // Get RESIDENT Attribute specific info
        // ................................................................
        IfGreater "Length_of_Stream_Name" 0 // Get Attribute's Stream Name
            move Offset_to_Stream_Name
            little-endian string16 "Length_of_Stream_Name" "Stream Name"
            move (Length_of_Stream_Name*(-2)) // Move back (Stream name length * 2) bytes
            move (Offset_to_Stream_Name*(-1)) // move back to Start of the Attribute
        EndIf
        
        // .......................
        IfEqual "Resident_(1=non-resident)"  0
            //Attribute type 0x10: Standard_Information
		    IfEqual "Attribute_type" 16 
			    move Content_offset
			    FileTime "Creation in UTC"
			    FileTime "Modification in UTC"
			    FileTime "Record change in UTC"
			    FileTime "Last access in UTC"
			    hexadecimal uint32 Flags // https://docs.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants
			    uint32 "Max Nr. of Versions"
                uint32 "Version Nr."
                uint32 "Class ID"
                uint32 "Owner ID"
                uint32 "Security ID"
                int64 "Quota Charged"
                int64 "Update sequence number"
                move -72
                move (Content_offset*(-1))
           EndIf
    
            //Attribute type 0x30: File_Name
    	    IfEqual "Attribute_type" 48 
			    move Content_offset
			    uint48	"Parent FILE record"
			    uint16	"Parent Sequence Nr"
			    FileTime "Creation in UTC"
			    FileTime "Modification in UTC"
			    FileTime "Record change in UTC"
			    FileTime "Last access in UTC"
                int64 "File Allocated Size"
                int64 "File Real Size"
                hex 4 "File Flags" // https://docs.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants
                                   // 0x10000000 = Directory
							       // 0x20000000 = Has Index_view
                hex 4 "Used by EAs and Reparse"
                uint8 "File_name_length" //Nr of unicode characters
                uint8 "Filename type"   //Namespace
			    little-endian string16 "File_name_length" "Filename"
                move -66
			    move (File_name_length*(-2))
                move (Content_offset*(-1))
		    EndIf
    
            //Attribute type 0x40: Object_ID
            IfEqual "Attribute_type" 64 
                move Content_offset
                guid "Object ID"   // Get only the main ObjectID
                move -16
                move (Content_offset*(-1))
            EndIf
    
            //Attribute type 0x60: Volume_Name
            IfEqual "Attribute_type" 96 
                move Content_offset
                little-endian string16 "Size_of_Resident_Content" "Volume Name"
                move (Size_of_Resident_Content*(-1))
                move (Content_offset*(-1))
            EndIf
    
            //Attribute type 0x70: Volume_Information
            IfEqual "Attribute_type" 112 
                move Content_offset
                move 8
                uint8 "Major Version"
                uint8 "Minor Version"
                hex 2 "Volume Flags"
                move -12
                move (Content_offset*(-1))
            EndIf
    
            //Attribute type 0x90: Index_Root
            IfEqual "Attribute_type" 144 
                move Content_offset
                hex 4 "Index_Attribute_type"
                hex 4 "Collation_Sorting_Rule"
                // "00000000" = "Binary"
			    // "00000001" = "File Name"
			    // "00000002" = "Unicode String"
			    // "00000010" = "Unsigned Long"
			    // "00000011" = "SID"
			    // "00000012" = "Security Hash"
			    // "00000013" = "Multiple Unsigned Longs"
                uint32 "Size of Index Record"
                uint8  "Nr of Clusters"
                move 3
                uint32 "Offset_to_1st_Entry"
                uint32 "Offset_to_end_of_used_buffer"
                uint32 "Offset_to_end_of_allocated_buffer"
                uint8  "Flag (0:Index fits in 0x90, 1:Index in 0xA0)"
                move -29
                move (Content_offset*(-1))
            EndIf
    
            //Attribute type 0xC0: Reparse_Point
            IfEqual "Attribute_type" 192 
                move Content_offset
                hex 4  "Reparse type"
                uint16 "Size of reparse data" 
                move -6
                move (Content_offset*(-1))
            EndIf
    
            //Attribute type 0xD0: EA_Information
            IfEqual "Attribute_type" 208 
                move Content_offset
                uint16 "Size of the EA entry"
                uint16 "Nr of EAs which NEED_EA set"
                uint32 "Size of EA data"
                move -8
                move (Content_offset*(-1))
            EndIf
         // --------------------------------------------------------------
        EndIf // End non-resident Attribute part	
       move "Attribute_length"
      endsection //End Attribute section
	}[Next_available_attribute_ID] 
	// --------------------------------------------------------------------------
	Goto 0
	Move 1024 // can also use 'Physical_size_of_this_record' but this will stop the move if record is blank/unused
end