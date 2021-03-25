template "ReFS FSRS Structure (VBR)"
// on-disk file system recognition information stored in the
// volume's boot sector (logical disk sector zero)

// Costas Katsavounidis - 2021
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to sector 0 of a physical hard disk/Volume

description "ReFS - File system recognition information"
applies_to disk
sector-aligned
read-only
requires 16 "46 53 52 53"

begin
    hex 3		"Jump instruction"       // not included in the Checksum
    char[8]     "File system name"       // ASCII
    hex 5       "Must be null"           // Must be null
    char[4]     "Structure Identifier"   // Must be FSRS or 0x46535253
    uint16      "Structure Size (bytes)" // Number of bytes in this structure, from the beginning to the end, including the Jump data
    hex 2       "Checksum"               // calculated over the bytes starting at the FsName data member and ending at the last byte of this structure, 
                                         // excluding the Jmp and Checksum
end

// Reference:
// https://docs.microsoft.com/en-us/windows/win32/fileio/file-system-recognition-structure
// https://docs.microsoft.com/en-us/windows/win32/fileio/computing-a-file-system-recognition-checksum
// https://patents.google.com/patent/US8200895B2/en