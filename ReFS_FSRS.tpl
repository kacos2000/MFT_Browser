template "ReFS FSRS Structure (VBR)"
// on-disk file system recognition information stored in the
// volume's boot sector (logical disk sector zero)

// Costas Katsavounidis - 2021 v.2
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to first sector (sector 0) of a Volume, OR
// to the last sector of a Volume

description "ReFS - File system recognition information"
applies_to disk
sector-aligned
read-only
requires 16 "46 53 52 53"  //FSRS signature

begin
    Section "ReFS - Volume Boot Record"
        hex 3		"Jump instruction"       // not included in the Checksum
        char[8]     "File system name"       // ASCII
        hex 5       "Must be null"           // Must be null
        char[4]     "Structure Identifier"   // Must be FSRS or 0x46535253
        uint16      "Structure Size (bytes)" // Number of bytes in this structure, from the beginning to the end, including the Jump data
        hex 2       "Checksum"               // calculated over the bytes starting at the FsName data member and ending at the last byte of this structure, 
                                             // excluding the Jmp and Checksum
        // not MS Documented:
        int64       "Sectors_in_volume"
        uint32      "Bytes_per_sector"
        uint32      "Sectors per cluster"
        uint8       "File system major version"
        uint8       "File system minor version"
        move 14
        hex 8       "Volume Serial Number"
        // Source:    https://www.sciencedirect.com/science/article/pii/S1742287619301252
    endsection // End of ReFS Volume Boot Record

	ifGreater "Sectors_in_volume" 0
        goto ((Sectors_in_volume)*(Bytes_per_sector)-(Bytes_per_sector)) //Go to the last sector of the volume and read the backup copy
	    
        Section "ReFS - Backup Volume Boot Record"
            hex 3		"Jump instruction"       // not included in the Checksum
            char[8]     "File system name"       // ASCII
            hex 5       "Must be null"           // Must be null
            char[4]     "Structure Identifier"   // Must be FSRS or 0x46535253
            uint16      "Structure Size (bytes)" // Number of bytes in this structure, from the beginning to the end, including the Jump data
            hex 2       "Checksum"               // calculated over the bytes starting at the FsName data member and ending at the last byte of this structure, 
                                                 // excluding the Jmp and Checksum
            int64       "Sectors in volume"
            uint32      "Bytes per sector"
            uint32      "Sectors per cluster"
            uint8       "File system major version"
            uint8       "File system minor version"
            move 14
            hex 8       "Volume Serial Number"
        endsection // End of ReFS backup Volume Boot Record
	EndIf
end

// Reference:
// https://docs.microsoft.com/en-us/windows/win32/fileio/file-system-recognition-structure
// https://docs.microsoft.com/en-us/windows/win32/fileio/computing-a-file-system-recognition-checksum
// https://patents.google.com/patent/US8200895B2/en