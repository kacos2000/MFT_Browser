template "MBR Partition Table"

// Based on Template by Stefan Fleischmann
// X-Ways Software Technology AG
//
// modified by
//
// Costas Katsavounidis - 2021 v.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to sector 0 of a physical hard disk

description "MBR Partition Table"
applies_to disk
sector-aligned
requires 510 "55 AA"
read-only

begin
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
	        uint_flex "5,4,3,2,1,0" "Start sector"
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
                    hex 1 " => IFS partition"
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
	        uint_flex "5,4,3,2,1,0" "End sector"
	        move -4
	        uint_flex "7,6,15,14,13,12,11,10,9,8" "End cylinder"
	        move -2
	        uint32	"Sectors preceding partition ~"
	        uint32	"Sectors in partition ~"
       endsection
	} [4]

	hex 2 "MBR Boot Signature" //describes whether the intent of a given sector is for it to be a Boot Sector (=AA55h) or not
    // End of Master Boot Record (MBR)
end