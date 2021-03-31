template "MBR & GPT Partition Table"

// Based on Template by Stefan Fleischmann
// X-Ways Software Technology AG
//
// modified by
//
// Costas Katsavounidis - 2021 v.2
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to sector 0 of a physical hard disk

// Checks for GPT Partition, and if found, 
// reads the GPT Partition entries too
// Updated to work with both 512 & 4096 byte sector

description "MBR & GPT Partition Table"
applies_to disk
sector-aligned
requires 510 "55 AA"
read-only

begin
	goto 239
    char[4] "Hardware Supports TPM (=TCPA)" //TCPA = "Trusted Computing Platform Alliance" => tests for the existence of a TPM chip 
    // https://thestarman.pcministry.com/asm/mbr/W7MBR.htm#INTRO
    goto 440 
    section "MBR - Disk Signature"
	    hex 4 "Disk Signature (hex)"
	    move -4
	    hexadecimal uint32 "Same reversed (hex)" // as seen in Windows Registry
    endSection
	move 2

    // MBR Partitions list
	numbering 1
	{
	section	"MBR - Partition Entry #~"
	    hex 1     "Boot Indicator (0x80=Bootable)" //If TRUE (0x80), the partition is active and can be booted
	    uint8     "Start head"
	    uint_flex "5,4,3,2,1,0" "Start sector" // sectors start counting at 1
	    move -4
	    uint_flex "7,6,15,14,13,12,11,10,9,8" "Start cylinder"
	    move -2
	    hex 1	  "Partition type indicator (hex)"
        ifEqual   "Partition type indicator (hex)" 0xEE
            move -1
            hex 1 " => Protective MBR (GPT part. follows)" //Protective MBR area exists on a GPT partition layout for backward compatibility
            else
            // ref: https://docs.microsoft.com/en-us/windows/win32/fileio/basic-and-dynamic-disks
            
            ifEqual "Partition type indicator (hex)" 0x00
                move -1
                hex 1 " => Unused Partition"
            else
            ifEqual "Partition type indicator (hex)" 0x05
                move -1
                hex 1 " => Extended Partition"
            else
            ifEqual "Partition type indicator (hex)" 0x01
                move -1
                hex 1 " => FAT12 partition"
            else
            ifEqual "Partition type indicator (hex)" 0x04
                move -1
                hex 1 " => FAT16 partition"
            else
            ifEqual "Partition type indicator (hex)" 0x0B
                move -1
                hex 1 " => FAT32 partition"
            else
            ifEqual "Partition type indicator (hex)" 0x07
                move -1
                hex 1 " => IFS partition" //NTFS
            else
            ifEqual "Partition type indicator (hex)" 0x42
                move -1
                hex 1 " => logical disk manager (LDM) partition"
            else  
            ifEqual "Partition type indicator (hex)" 0x80
                move -1
                hex 1 " => NTFT partition"
            else  
            ifEqual "Partition type indicator (hex)" 0xC0
                move -1
                hex 1 " => NTFT mirror or striped array"
            else
            // upto here ref: https://docs.microsoft.com/en-us/windows/win32/fileio/disk-partition-types
            // and
            // https://docs.microsoft.com/en-us/windows/win32/api/vds/ns-vds-create_partition_parameters
            
            ifEqual "Partition type indicator (hex)" 0x0E
                move -1
                hex 1 " => FAT (LBA-mapped*) - (FAT16)" //Extended-INT13 equivalent of 0x06 (FAT16 formated from Win10)
            else
            ifEqual "Partition type indicator (hex)" 0x06
                move -1
                hex 1 " => UDF partition" //UDF formated from Win10 
            else
            ifEqual "Partition type indicator (hex)" 0x0C
                move -1
                hex 1 " => FAT32 (LBA-mapped*) " //FAT32 formated from Win10 - Extended-INT13 equivalent of 0x0B
            else
            ifEqual "Partition type indicator (hex)" 0x0F
                move -1
                hex 1 " => Extended partition (LBA-mapped*)" //Extended-INT13 equivalent of 0x05
            else
                move -1
                hex 1 " => https://www.win.tue.nl/~aeb/partitions/partition_types-1.html <=" 
                //*Full list: https://www.win.tue.nl/~aeb/partitions/partition_types-1.html
        EndIf
        uint8     "End head"
	    uint_flex "5,4,3,2,1,0" "End sector" // Max value = 63
	    move -4
	    uint_flex "7,6,15,14,13,12,11,10,9,8" "End cylinder"
	    move -2
	    uint32	"Sectors preceding partition ~"
	    uint32	"Sectors in partition ~"
	} [4]

	endsection

	hex 2 "MBR Boot Signature" //describes whether the intent of a given sector is for it to be a Boot Sector (=AA55h) or not
    // End of Master Boot Record (MBR)
    // **********************************************************
   Section "GPT - Signature (512 byte sector)"
    // Check if there is a GUID (GPT) Partition Table
        char[8] "GPT Signature at 0x200"
        ifEqual "GPT Signature at 0x200" "EFI PART"
        move 0
    endSection
    else
        goto 4096
        Section "GPT - Signature (4096 byte sector)"
        // Check if there is a GUID (GPT) Partition Table at 0x1000
        char[8] "GPT Signature at 0x1000"
        ifEqual "GPT Signature at 0x1000" "EFI PART"
        move 0
    endSection
    else
        end
    endif

    section	"GPT - Header"
		hex 4	"Revision (hex)"
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
		int64		"Partition_Entry_LBA" // Always 2 in the Primary GPT
		uint32		"(Max) Nr of Partition Entries"
		uint32		"Size of Partition Entries (bytes)"
		hexadecimal uint32	"Partition Entry Array CRC32"
	endsection
    // https://www.ntfs.com/guid-part-table.htm
    
    ifEqual "GPT Signature at 0x200" "EFI PART"
	    goto  ((Partition_Entry_LBA)*512)
    else
    ifEqual "GPT Signature at 0x1000" "EFI PART"
        goto  ((Partition_Entry_LBA)*4096)
    endIf

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
                // Note: Partition size = 
                // ((Ending LBA - Starting LBA)+1)*(sector size)
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