template "NTFS - MFT FILE Record"

// Costas Katsavounidis - 2021.1a
// kacos2000 [at] gmail.com
// https://github.com/kacos2000
//
// To be applied to the NTFS Master File Table's (MFT's) FILE records.
// Fix-up values are not corrected/replaced which will result in errors.

description "NTFS - MFT FILE Record"
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
	uint16	"MFT Record Sequence Nr."     // Number of times this record was re-used
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
    uint32 "MFT Record Nr"                  // MFT record Number
	
	goto "Offset to update sequence"
    hex 2       "FixUp"                     // Check or fixup. Must match bytes at 0x1FE & 0x3FE
    move -2
	uint16		"Update sequence number"    // Nr if times the record was updated
	hex 2       "Fixup_Value 1" // replaces 0x1FE
    hex 2       "Fixup_Value 2" // replaces 0x3FE
    endsection // End of Header section
	
    // ------------------------ATTRIBUTES--------------------------------------
    //Process General Attribute info
    goto Offset_to_first_attribute
    numbering 1
	{   
        Section "Attribute #~"

        uint32 "Attribute_type"
		IfEqual "Attribute_type" 4294967295 // "FFFFFFFF" = end of Attributes
            endsection
			ExitLoop
		EndIf
        IfEqual "Attribute_type" 0 // "00000000" = unused or invalid Attribute type
            endsection
			ExitLoop
		EndIf
        move -4
        hex 4 "Attribute type (Hex)"
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
        IfEqual "Attribute_type" 48
            uint8   "Indexed flag (1= Indexed)"
            move    -23 // Go back to start of the Attribute
        else
            move    -22 // Go back to start of the Attribute
        endIf

        // Get Stream Name
        // ................................................................
        IfGreater "Length_of_Stream_Name" 0 // Get Attribute's Stream Name
            move Offset_to_Stream_Name
            little-endian string16 "Length_of_Stream_Name" "Stream Name (Unicode)"
            move (Length_of_Stream_Name*(-2))
            hex ((Length_of_Stream_Name)*2) "Stream Name (Hex)"
            move (Length_of_Stream_Name*(-2)) // Move back (Stream name length * 2) bytes
            move (Offset_to_Stream_Name*(-1)) // move back to Start of the Attribute
        EndIf

        // Get Stream specific content
        // ................................................................

        // Stream Name $Info (only in the $UpCase file) since Win 8 
        IfEqual "Stream Name (Hex)" 0x240049006E0066006F00
            move Content_offset
            uint32 "Stream content size"
            move 4
            hex 8  "CRC64"
            uint32 "OS Version (Major)"
            uint32 "OS Version (Minor)"
            uint32 "Windows Build Nr."
            uint16 "Service Pack (Major)"
            uint16 "Service Pack (Minor)"
            move -32
            move (Content_offset*(-1))
         EndIf

        // Stream Name $Max (only in the $UsnJrnl file)
        IfEqual "Stream Name (Hex)" 0x24004D0061007800
            move Content_offset
            int64 "Change Journal - Maximum Size"
            int64 "Change Journal - Alloc. Delta Size"
            filetime "Change Journal - Creation Time"
            int64 "Lowest Valid USN"
            move -32
            move (Content_offset*(-1))
         EndIf

        // Stream Name $TXF_DATA 
        IfEqual "Stream Name (Hex)" 0x24005400580046005F004400410054004100
            move Content_offset
            uint48 "$MFT Record Nr of RM root"
            uint16 "$MFT Record Sequence Nr of RM root"
            hex 8 "Flags"
            int64 "TxF file ID"
            int64 "LSN for NTFS Metadata"
            int64 "LSN for User Data"
            int64 "LSN for Directory Index"
            int64 "USN index"
            move -56
            move (Content_offset*(-1))
         EndIf

        // Stream Name $DSC 
        IfEqual "Stream Name (Hex)" 0x2400440053004300
            move Content_offset
            uint32 "Storage Tier Class"
            uint32 "Flags"
            move (Size_of_Resident_Content*(-1))
            move (Content_offset*(-1))
         EndIf

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
        // .........................................................
        IfEqual "Resident_(1=non-resident)"  0

            // Attribute type 0x10: $Standard_Information
            // Always Resident
		    IfEqual "Attribute_type" 16 
			    move Content_offset
			    FileTime "Creation in UTC"
			    FileTime "Modification in UTC"
			    FileTime "Record change in UTC"
			    FileTime "Last access in UTC"
			    hexadecimal uint32 Flags // https://docs.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants
			    uint32 "Max Nr. of Versions"
                uint32 "Version Nr."
                move -4
                uint8 "1 = Is Case Sensitive"
                uint_flex "3,2,1,0" "Reserve Storage ID"
                move -1
                uint32 "Class ID"
                uint32 "Owner ID"
                uint32 "Security ID"
                int64 "Quota Charged"
                int64 "Update sequence number"
                move -72
                move (Content_offset*(-1))
           EndIf

            // Attribute type 0x20: $Attribute_List
            IfEqual "Attribute_type" 32
                move Content_offset
                hex  Size_of_Resident_Content "Resident Content"
                move (Content_offset*(-1))
                move (Size_of_Resident_Content*(-1))
            endIf 
    
            // Attribute type 0x30: $File_Name
            // Always Resident
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
                                   // +
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
    
            // Attribute type 0x40: $Object_ID
            // Always Resident
            IfEqual "Attribute_type" 64 
                move Content_offset
                guid "Object ID"   // Get only the main ObjectID
                move -16
                move (Content_offset*(-1))
            EndIf

            // Attribute type 0x50: $Security_Descriptor
            IfEqual "Attribute_type" 80 
                move Content_offset
                hex  Size_of_Resident_Content "Resident Content"
                move (Content_offset*(-1))
                move (Size_of_Resident_Content*(-1))
            EndIf
    
            // Attribute type 0x60: $Volume_Name
            // Always Resident
            IfEqual "Attribute_type" 96 
                move Content_offset
                little-endian string16 (Size_of_Resident_Content/2) "Volume Name"
                move (Size_of_Resident_Content*(-1))
                move (Content_offset*(-1))
            EndIf
    
            // Attribute type 0x70: $Volume_Information
            // Always Resident
            IfEqual "Attribute_type" 112 
                move Content_offset
                move 8
                uint8 "NTFS Major Version"
                uint8 "NTFS Minor Version"
                hex 2 "Volume Flags"
                move -12
                move (Content_offset*(-1))
            EndIf
            
            // Attribute type 0x80: $Data
            IfEqual "Attribute_type" 128 
                move Content_offset
                hex  Size_of_Resident_Content "Resident Content"
                move (Content_offset*(-1))
                move (Size_of_Resident_Content*(-1))
            EndIf

            // Attribute type 0x90: $Index_Root
            // Always Resident
            // template does not support nested if loops to get index nodes
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
                uint32  "Nr of Clusters"
                uint32 "Offset_to_1st_Entry"
                uint32 "Offset_to_end_of_used_buffer"
                uint32 "Offset_to_end_of_allocated_buffer"
                uint32  "Flag: Index [0] in 0x90, [1] in 0xA0"
                move -16
                move Offset_to_1st_Entry
                hex ((Offset_to_end_of_used_buffer)-(Offset_to_1st_Entry)) "Index Root content"
                move (((Offset_to_end_of_used_buffer)-(Offset_to_1st_Entry))*(-1))
                move -32
                move (Offset_to_1st_Entry*(-1))
                move (Content_offset*(-1))
            EndIf

            // Attribute type 0xA0: $Index_Allocation
            // Might be resident (according to $AttrDef)
            IfEqual "Attribute_type" 160 
                move Content_offset
                hex  Size_of_Resident_Content "Resident Content"
                move (Content_offset*(-1))
                move (Size_of_Resident_Content*(-1))
            EndIf  

            // Attribute type 0xB0: $Bitmap
            // Resident (usually when paired with a stream name)
            IfEqual "Attribute_type" 176 
                move Content_offset
                hex  Size_of_Resident_Content "Resident Content"
                move (Content_offset*(-1))
                move (Size_of_Resident_Content*(-1))
            EndIf
    
            // Attribute type 0xC0: Reparse_Point
            IfEqual "Attribute_type" 192 
                move Content_offset
                hexadecimal uint32  "Reparse Point Tag"
                uint16 "Reparse_Point_Data_Size"
                move 2
                hex "Reparse_Point_Data_Size" "Reparse Point Data"
                move -8
                move (Reparse_Point_Data_Size*(-1))
                move (Content_offset*(-1))
            EndIf
    
            // Attribute type 0xD0: $EA_Information
            // Always Resident
            IfEqual "Attribute_type" 208 
                move Content_offset
                uint16 "Size of the EA entry"
                uint16 "Nr of EAs which NEED_EA set"
                uint32 "Size of EA data"
                move -8
                move (Content_offset*(-1))
            EndIf

            // Attribute type 0xE0: $EA
            IfEqual "Attribute_type" 224 
                move Content_offset
                hex  Size_of_Resident_Content "Resident Content"
                move (Content_offset*(-1))
                move (Size_of_Resident_Content*(-1))
            EndIf

            // Attribute type 0x100: $LOGGED_UTILITY_STREAM
            // Always Resident
            IfEqual "Attribute_type" 256 
                move Content_offset
                hex  Size_of_Resident_Content "Resident Content"
                move (Content_offset*(-1))
                move (Size_of_Resident_Content*(-1))
            EndIf


         // --------------------------------------------------------------
        EndIf // End non-resident Attribute part	
       move "Attribute_length"
      endsection //End Attribute section
	}[((Next_available_attribute_ID)-1)] 
	// --------------------------------------------------------------------------
	Goto 0
    ifGreater "Physical_size_of_this_record" 0
        move "Physical_size_of_this_record"
    else
	    Move 1024
    endIf
end