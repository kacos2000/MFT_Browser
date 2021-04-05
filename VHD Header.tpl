template "VHD - Header/Footer"

// Costas Katsavounidis - 2021.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000
//
// To be applied to VHD files at
// offset 0 of the file, or at the start of the footer's 512 bytes 

description "VHD - Header/Footer"
applies_to file  
requires 0 "63 6F 6E 65 63 74 69 78" // Signature: 'conectix'
read-only           

// NOTE: All values, unless otherwise specified, are stored in big endian format.

// Ref: https://www.microsoft.com/en-us/download/details.aspx?id=23850

// Dynamic Disk header fields: 
// - Copy of hard disk footer (512 bytes) 
// - Dynamic Disk Header (1024 bytes) 
// - BAT (Block Allocation table) 
// - Data Block 1 
// - Data Block 2 
// - … 
// - Data Block n 
// - Hard Disk Footer (512 bytes) 


// Header
begin
	Section "VHD - Hard Disk Footer (or copy = Header)"
        char[8] "Signature" // Microsoft call this 'cookie' :-D
        hex 4 "Features"
        move -1
        uint_flex "1" "- Bit 1 - Reserved" // This bit must always be set to 1
        move -4
        uint_flex "0" "- Bit 0 - Temporary"
        move -3
        big-endian uint16 "File Format Major version"
        big-endian uint16 "File Format Minor version"
        big-endian hexadecimal int64 "Data Offset (hex)" //  absolute byte offset  to the next structure
        move -8
        big-endian int64 "Data Offset (dec)" // For fixed disks, this field should be set to 0xFFFFFFFF
        big-endian uint32 "Creation Timestamp (sec since 1/1/2000)" //  Hard disk image creation Time Stamp (seconds since January 1, 2000 12:00:00 AM in UTC/GMT)
        char[4] "Creator Application"
        big-endian uint16    "Creator Major version"
        big-endian uint16    "Creator Minor version"
        char[4] "Creator Host OS"
        big-endian int64 "Original Size"
        big-endian int64 "Current Size"
        big-endian uint16 "Geometry: Cylinders"
        uint8 "Geometry: Heads"
        uint8 "Geometry: Sectors (per track/cylinder)"
        big-endian uint32 "Disk Type:"
        move -4
        ifEqual "Disk Type:" 0
            big-endian hexadecimal uint32 " => None"
        else
        ifEqual "Disk Type:" 1
            big-endian hexadecimal uint32 " => Reserved (deprecated) "
        else
        ifEqual "Disk Type:" 2
            big-endian hexadecimal uint32 " => Fixed hard disk"
        else
        ifEqual "Disk Type:" 3
            big-endian hexadecimal uint32 " => Dynamic hard disk"
        else
        ifEqual "Disk Type:" 4
            big-endian hexadecimal uint32 " => Differencing hard disk"
        else
        ifEqual "Disk Type:" 5
            big-endian hexadecimal uint32 " => Reserved (deprecated)"
        else
        ifEqual "Disk Type:" 6
            big-endian hexadecimal uint32 " => Reserved (deprecated)"
        endIf
        hex 4 "Checksum"
        hex 16 "Unique ID (hex)"
        move -16
        GUID "Unique ID"
         // 427 bytes of Reserved space (zeros)
    endSection

    ifEqual "Disk Type:" 3
        gotoex "Data Offset (dec)"
    else
    ifEqual "Disk Type:" 4
        gotoex "Data Offset (dec)"
    else
        end
    endIf

    Section "VHD - Dynamic/Differencing Disk Header"
        char[8] "Dynamic header signature" // usually "cxsparse"
        hex 8   "Data Offset (hex)" // currently unused, should be 0xFFFFFFFF
        big-endian hexadecimal int64 "Block Allocation Table Offset (hex)" //  absolute byte offset to the Block Allocation Table
        move -8
        big-endian int64  "Block Allocation Table Offset (dec)"
        big-endian uint16 "Header Major version"
        big-endian uint16 "Header Minor version"
        big-endian uint32 "Max_Table_Entries" //This should be equal to the number of blocks in the disk (disk size/block size)
        big-endian uint32 "Block Size (sector size in bytes)"    // The sectors per block must always be a power of two
        hex 4 "Checksum"
        hex 16 "Parent Unique ID (hex)"
        move -16
        GUID "Parent Unique ID"
        big-endian uint32 "Parent Timestamp (sec since 1/1/2000)"
        move 4 // skip 4 reserved bytes
        big-endian string16 256 "Parent Unicode Name"
        endSection
        
        ifEqual "Disk Type:" 4
            move 0
        else
            end
        endIF

        ifGreater "Max_Table_Entries" 0
            numbering 0 {
                Section "Parent Locator Entry #~"
                    char[4] "Platform Code"
                    big-endian uint32 "Number of 512-byte sectors"         // Platform Data Space
                    big-endian uint32 "Size of Parent HD locator in bytes" // Platform Data Length
                    move 4 // skip 4 reserved bytes
                    big-endian hexadecimal int64 "Platform Data Offset (hex)" 
                    move -8
                    big-endian int64 "Platform Data Offset (dec)" 
                endSection
            }[Max_nr_of_BAT_entries]
        endIf    
End



