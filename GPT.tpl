template "GPT Partition Table"

// Based on Template by Stefan Fleischmann
// X-Ways Software Technology AG
//
// modified by
//
// Costas Katsavounidis - 2021 v.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to sector 0 of a physical hard disk

description "GPT Partition Table"
applies_to disk
sector-aligned
requires 512 "45 46 49 20 50 41 52 54" //EFI PART
read-only

begin
    goto 0
	move 446

	section	"Protective MBR (if Partition Type = 0xEE)"
		uint8		"Boot Indicator (0x80=Bootable)" //If TRUE (0x80), the partition is active and can be booted
		hex 1		"Starting Head"
		hex 1		"Starting Sector"
		hex 1		"Starting Cylinder"
		hex 1		"Partition Type (Should be 0xEE)" //Protective MBR area exists on a GPT partition layout for backward compatibility
		hex 1		"Ending Head"
		hex 1		"Ending Sector"
		hex 1		"Ending Cylinder"
		uint32		"Starting LBA"
		uint32		"Size in LBA"
	endsection
		
	move 50
	
	section	"GPT - Header"
		char[8] "GPT Signature"
		hex 4	"Revision No"
        move -2
        uint16  "- Revision: Major" 
        move -4 
        uint16  "- Revision: Minor"  
        move 2
		uint32		"Header Size (Nr of bytes)"
		hexadecimal uint32	"Header CRC32"
		move 4     // Skip 4 reserved bytes
		int64		"Primary LBA"
		int64		"Backup LBA"
		int64		"First Usable LBA"
		int64		"Last  Usable LBA"
		hex 16 		"Disk GUID (hex)"
		move -16
		GUID		"Disk GUID"
		int64		"Partition Entry LBA" // Always 2 in the Primary GPT
		uint32		"(Max) Nr of Partition Entries"
		uint32		"Size of Partition Entries (bytes)"
		hexadecimal uint32	"Partition Entry Array CRC32"
	endsection
    // https://www.ntfs.com/guid-part-table.htm

	move 420
    // GPT Partitions list
        numbering 1
	        {
	        section	"GPT - Partition Entry #~"
	        
		        hex 16	"Partition Type (hex)"
                IfEqual "Partition Type (hex)" 0x00000000000000000000000000000000 
			        ExitLoop
                else
                IfEqual "Partition Type (hex)" 0xA4BB94DED106404DA16ABFD50179D6AC
                    move -16
                    GUID    "=> MS Recovery Partition"
                else
                IfEqual "Partition Type (hex)" 0x28732AC11FF8D211BA4B00A0C93EC93B
                    move -16
                    GUID    "=> EFI System Partition"
                else
                IfEqual "Partition Type (hex)" 0x16E3C9E35C0BB84D817DF92DF00215AE
                    move -16
                    GUID    "=> MS Reserved Partition"
                else
                IfEqual "Partition Type (hex)" 0xA2A0D0EBE5B9334487C068B6B72699C7
                    move -16
                    GUID    "=> Basic data partition (Win)"
                else		        
                    move -16
		            GUID	"Partition Type GUID"
                EndIf
                // https://docs.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-partition_information_gpt
		        
		        GUID		"Unique Partition GUID"
		        int64		"Starting LBA"
		        IfEqual "Starting LBA" 0
			        ExitLoop
		        EndIf
		        int64		"Ending LBA"
		        hex 8 		"Attribute Bits (hex)"
                move -8
                    uint_flex "0" "- [0x01]: Platform Required" //0x0000000000000001
                    move 3
                    uint_flex "7" "- [0x80]: No Drive Letter"   //0x8000000000000000
                    move -4
                    uint_flex "6" "- [0x40]: Hidden"            //0x4000000000000000
                    move -4
                    uint_flex "5" "- [0x20]: Shadow Copy"       //0x2000000000000000
                    move -4
                    uint_flex "4" "- [0x10]: Read Only"         //0x1000000000000000
                move -3
                //  https://docs.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-partition_information_gpt
		        string16 36	"Partition #~ Name"
             endsection
	        }[128]
	
end