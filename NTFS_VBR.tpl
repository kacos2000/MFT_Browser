template "NTFS VBR"

// Costas Katsavounidis - 2021 v.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to sector 0 of an NTFS Volume
// Template also reads the last sector of the Volume (Backup Boot Record)

description "NTFS - Volume Boot Record Structure"
applies_to disk
sector-aligned
read-only  

requires 0x03  "4E 54 46 53 20 20 20 20" // ID must be NTFS, including trailing spaces
requires 0x1FE "55 AA"                   //Valid boot sector signature

begin
	section	"NTFS Boot Sector & BPB Structure"
        hex 3	"JMP instruction"			
	    char[8]	"File System Name"
	    uint16	"Bytes_per_sector"
	    uint8	"Sectors_per_cluster"
	    uint16	"Reserved sectors"
        move 5  // skip 3* always zero bytes & 2* unused by NTFS bytes
	    hex 1	"Media descriptor (hex)" //Range: F0, F8, F9, FA, FB, FC, FD, FE, and FF
	    move 2  // skip unused by NTFS bytes
	    uint16	"Sectors per track"
	    uint16	"Nr of Heads"	
	    uint32	"Nr of Hidden sectors"
	    move 4  // skip 4 unused by NTFS bytes
	    move 4	// skip 4 unused by NTFS bytes (always 80 00 80 00)
	    int64	"Total_sectors_excl_backup_boot_sector"
	    int64	"LCN of $MFT"	
	    int64	"LCN of $MFTMirr"	
	    uint32	"Clusters Per File Record Segment"
        uint8   "Clusters Per Index Buffer"
	    move 3  // skip unused by NTFS bytes
	    hex 4	"32-bit serial number (hex)"
	    move -4
	    hexadecimal uint32 "32-bit SN (hex, reversed)"
	    move -4
	    hex 8	"64-bit serial number (hex)"
	    uint32	"Checksum" 
	    goto 0x1FE			
	    hex 2 "Boot Signature" //describes whether the intent of a given sector is for it to be a Boot Sector (=AA55h) or not
    endSection
    
    //Read the backup boot sector 

    ifGreater ((Bytes_per_sector)*(Total_sectors_excl_backup_boot_sector)) 0
        goto ((Bytes_per_sector)*(Total_sectors_excl_backup_boot_sector))
        section	"[Backup] NTFS Boot Sector & BPB Structure"
            hex 3	"JMP instruction"			
	        char[8]	"File System Name"
	        uint16	"Bytes_per_sector"
	        uint8	"Sectors_per_cluster"
	        uint16	"Reserved sectors"
            move 5  // skip 3* always zero bytes & 2* unused by NTFS bytes
	        hex 1	"Media descriptor (hex)" //Range: F0, F8, F9, FA, FB, FC, FD, FE, and FF
	        move 2  // skip 2 unused by NTFS bytes
	        uint16	"Sectors per track"
	        uint16	"Nr of Heads"	
	        uint32	"Nr of Hidden sectors"
	        move 4  // skip 4 unused by NTFS bytes
	        move 4	// skip 4 unused by NTFS bytes (always 80 00 80 00)
	        int64	"Total sectors (excl. backup boot sector)"
	        int64	"LCN_of_$MFT"	
	        int64	"LCN_of_$MFTMirr"	
	        uint32	"Clusters Per File Record Segment"
            uint8   "Clusters Per Index Buffer"
	        move 3  // skip unused by NTFS bytes
	        hex 4	"32-bit serial number (hex)"
	        move -4
	        hexadecimal uint32 "32-bit SN (hex, reversed)"
	        move -4
	        hex 8	"64-bit serial number (hex)"
	        uint32	"Checksum" 
	        move 426			
	        hex 2 "Boot Signature" //describes whether the intent of a given sector is for it to be a Boot Sector (=AA55h) or not
        endSection
    endIf
end