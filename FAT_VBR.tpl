template "FAT12/16/32 VBR"

// Costas Katsavounidis - 2021 v.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to sector 0 of a FAT Volume
// If the Volume is FAT32, it also reads the Backup VBR, otherwise
// if the Volume is FAT12/16, the template must be applied to byte 0 of the backup VBR

description "FAT12/16/32 - Volume Boot Record Structure"
applies_to disk
sector-aligned
read-only

requires 0x1FE "55 AA" //Valid boot sector signature

begin
	section	"Boot Sector & BPB Structure"
        hex 3   "JMP instruction"      //Valid: 0xEB??90 or 0xE9????
	    char[8]	"OEM Name"             //Microsoft OSs don't pay any attention to this field.
	    uint16	"Bytes_per_sector"     //Range: 512, 1024, 2048 or 4096
	    uint8	"Sectors per cluster"
	    uint16	"Reserved sectors"     //This field must not be 0
	    uint8	"Nr of FATs"
	    uint16	"Nr of Root entries (12/16 bit)"
	    uint16	"Total Sectors (12/16 bit)"
	    hex 1	"Media descriptor (hex)" //Range: F0, F8, F9, FA, FB, FC, FD, FE, and FF
	    uint16	"Sectors per FAT (12/16 bit)"
	    uint16	"Sectors per track (for INT 13h)"
	    uint16	"Nr of Heads (for INT 13h)"
	    uint32	"Nr of Hidden sectors"
	    uint32	"Total Sectors (32 bit)"
	endSection

    // Read the rest of the structure according to the File System type
    // FAT12/16 specific structure

    ifGreater "Nr of Root entries (12/16 bit)" 0
        section	"FAT12/16 Section"
            hex 1    "Drive Select (INT 13h drive Nr)"
            move 1   //Skip reserved byte used by Windows NT
            hex 1    "Extended boot signature (12/16 bit)" //Specifies if the next 3 fields are used (= 0x29)
            hex 4    "Volume Serial Number"
            char[11] "Volume Label"
            char[8]  "File System type" //FAT12, FAT16 or FAT
            goto 0x1FE
            hex 2    "Boot Signature" //describes whether the intent of a given sector is for it to be a Boot Sector (=AA55h) or not
        endSection
    endIf

    // FAT32 specific structure + Backup VBR

    ifGreater "Total Sectors (32 bit)" 0
        goto 36
	    section	"FAT32 Section"
	        uint32	"Nr. of Sectors per FAT" //Sectors occupied by ONE FAT
	        hex 2	"Extended flags (hex)"
	        move -2
            uint_flex "0" "bit 0: FAT1 active"
	        move -4
            uint_flex "1" "bit 1: FAT2 active"
	        move -4
            uint_flex "2" "bit 2: FAT3 active"
	        move -4
            uint_flex "3" "bit 3: FAT4 active"
	        move -4
	        uint_flex "7" "bit 7: FAT mirroring off - only 1 FAT active"
	        move -2
	        uint8    "File system major version"
            uint8    "File system minor version"
	        uint32	 "Root Directory 1st cluster"    //Usually 2 but not required to be 2
	        uint16	 "Sector Nr of FSINFO structure" //Usually 1
	        uint16	 "Backup_boot_sector" //In the reserved area of the volume - Usually 6. No value other than 6 is recommended.
	        move 12  //Skip Reserved bytes - must be 0
            hex 1    "Drive Select (INT 13h drive Nr)"
            move 1   //Skip Reserved1 bytes
            hex 1    "Extended boot signature (0x29) (32bit)"  //Specifies if the next 3 fields are used (= 0x29)
            hex 4    "Volume Serial Number (32bit)"
            char[11] "Volume Label (32bit)"
            char[8]  "File System type (32bit)" //FAT32
            goto 0x1FE
            hex 2    "Boot Signature" //describes whether the intent of a given sector is for it to be a Boot Sector (=AA55h) or not
	    endsection

        //Read the backup VBR:

        goto ((Backup_boot_sector)*(Bytes_per_sector))
        section	"[Backup] Boot Sector & BPB Structure"
            hex 3   "JMP instruction"      //Valid: 0xEB??90 or 0xE9????
	        char[8]	"OEM Name"             //Microsoft OSs don't pay any attention to this field.
	        uint16	"Bytes_per_sector"     //Range: 512, 1024, 2048 or 4096
	        uint8	"Sectors per cluster"
	        uint16	"Reserved sectors"     //This field must not be 0
	        uint8	"Nr of FATs"
	        uint16	"Nr of Root entries (12/16 bit)"
	        uint16	"Total Sectors (12/16 bit)"
	        hex 1	"Media descriptor (hex)" //Range: F0, F8, F9, FA, FB, FC, FD, FE, and FF
	        uint16	"Sectors per FAT (12/16 bit)"
	        uint16	"Sectors per track (for INT 13h)"
	        uint16	"Nr of Heads (for INT 13h)"
	        uint32	"Nr of Hidden sectors"
	        uint32	"Total Sectors (32 bit)"
	    endSection
	    section	"[Backup] FAT32 Section"
	        uint32	"Nr. of Sectors per FAT" //Sectors occupied by ONE FAT
	        hex 2	"Extended flags (hex)"
	        move -2
            uint_flex "0" "bit 0: FAT1 active"
	        move -4
            uint_flex "1" "bit 1: FAT2 active"
	        move -4
            uint_flex "2" "bit 2: FAT3 active"
	        move -4
            uint_flex "3" "bit 3: FAT4 active"
	        move -4
	        uint_flex "7" "bit 7: FAT mirroring off - only 1 FAT active"
	        move -2
	        uint8    "File system major version"
            uint8    "File system minor version"
	        uint32	 "Root Directory 1st cluster"    //Usually 2 but not required to be 2
	        uint16	 "Sector Nr of FSINFO structure" //Usually 1
	        uint16	 "Backup boot sector" //In the reserved area of the volume - Usually 6. No value other than 6 is recommended.
	        move 12  //Skip Reserved bytes - must be 0
            hex 1    "Drive Select (INT 13h drive Nr)"
            move 1   //Skip Reserved1 bytes
            hex 1    "Extended boot signature (0x29) (32bit)"  //Specifies if the next 3 fields are used (= 0x29)
            hex 4    "Volume Serial Number (32bit)"
            char[11] "Volume Label (32bit)"
            char[8]  "File System type (32bit)" //FAT32
            move 420
            hex 2 "Boot Signature" //describes whether the intent of a given sector is for it to be a Boot Sector (=AA55h) or not
	    endsection
        goto 0
    endIf

end

//Reference (Hardware White Paper): 

//Title: Microsoft Extensible Firmware Initiative 
//       FAT32 File System Specification
//       FAT: General Overview of On-Disk Format
//Link:  https://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/fatgen103.doc