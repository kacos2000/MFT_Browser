template "VHDX Header"

// Costas Katsavounidis - 2021 v.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000

// To be applied to byte 0 of a vhdx file

description "VHDX Header"
applies_to file
requires 0 "76 68 64 78 66 69 6C 65" // Signature: 'vhdxfile'
read-only

// Reads:
// Header #1 & #2
// Region Table headers #1 & #2 
// Region table #1 entries
// Metadata table header & entries.
// (Manual parsing of metadata entry values needed, due to template limitations)
//
// Reference: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-vhdx/f0efbb98-f555-4efc-8374-4e77945ad422

begin
    section "VHDX - File Type Identifier"
        goto 0
        char[8] "File Signature"
        char16[256] "Creator"
    endSection
  
    goto 65536 // Goto Header #1

    section "VHDX - Header #1"
        hex 4 "Header #1 Signature (hex)"
        IfEqual "Header #1 Signature (hex)" 0x68656164
            move -4
            char[4] "Header #1 Signature"
            hex 4 "Checksum (CRC-32C hash)"
            int64 "Sequence Number"
            GUID "File Write Guid" 
            GUID "Log Guid"
            move 16
            uint16 "LogVersion"  // Must be set to zero
            uint16 "Version"     // Must be set to 1
            uint32 "Log Length"  // Must be multiple of 1 MB
            uint32 "Log Offset"  // Must be multiple of 1 MB and at least 1 MB
            //Reserved 4016 bytes
            goto 131072 // Header #2
        else
            end
        EndIf
    endSection

    section "VHDX - Header #2"
        hex 4 "Header #2 Signature (hex)"
        IfEqual "Header #2 Signature (hex)" 0x68656164
            move -4
            char[4] "Header #1 Signature"
            hex 4 "Checksum (CRC-32C hash)"
            int64 "Sequence Number"
            GUID "File Write Guid" 
            GUID "Log Guid"
            move 16
            uint16 "LogVersion"  // Must be set to zero
            uint16 "Version"     // Must be set to 1
            uint32 "Log Length"  // Must be multiple of 1 MB
            uint32 "Log Offset"  // Must be multiple of 1 MB and at least 1 MB
            //Reserved 4016 bytes
            goto 196608 //Region table #1
        else
            end
        EndIf
    endSection

    Section "VHDX - Region Table #1 [Header]"
        hex 4 "Region Table #1 Signature (hex)"
        IfEqual "Region Table #1 Signature (hex)" 0x72656769
            move -4
        else
            endSection
            end
        EndIf  
        char[4] "Region Table #1 Signature"
        hex 4 "Checksum (CRC-32C hash)"
        uint32 "Region_Table_#1_Entry_Count" // Must be less than or equal to 2,047
        move 4 // Skip Reserved 4 bytes
        endSection
        IfGreater "Region_Table_#1_Entry_Count" 0
            move 0
        else
            goto 262144 //Region table #2
        EndIf
        numbering 1 {
            Section "VHDX - Region Table #1 [Entry #~]"
                hex 16 "Guid (hex)"
                move -16
                ifEqual "Guid (hex)" 0x6677C22D23F600429D64115E9BFD4A08
                        GUID " => Block Allocation Table Region Guid" // Must be unique within the table
                        hexadecimal int64 "File Offset (hex)"
                        move -8
                        int64  "BAT Offset" // Must be a multiple of 1 MB and MUST be at least 1 MB
                        uint32 "BAT Length"      // Must be a multiple of 1 MB
                        uint32 "BAT Required (1 = 'Yes')"
                        EndSection
                else
                ifEqual "Guid (hex)" 0x06A27C8B90479A4BB8FE575F050F886E
                        GUID " => Metadata Region Guid" // Must be unique within the table
                        hexadecimal int64 "File Offset (hex)"
                        move -8
                        int64  "Metadata Offset" // Must be a multiple of 1 MB and MUST be at least 1 MB
                        uint32 "Metadata Length"      // Must be a multiple of 1 MB
                        uint32 "Metadata Required (1 = 'Yes')"
                        EndSection
                endIf
         }[Region_Table_#1_Entry_Count]
       
        goto 262144 //Region table #2

    Section "VHDX - Region Table #2 [Header]"
        hex 4 "Region Table #2 Signature (hex)"
        IfEqual "Region Table #2 Signature (hex)" 0x72656769
            move -4
        else
            endSection
            end
        EndIf
                char[4] "Region Table #1 Signature"
        hex 4 "Checksum (CRC-32C hash)"
        uint32 "Region_Table_#2_Entry_Count" // Must be less than or equal to 2,047
        move 4 // Skip Reserved 4 bytes
        endSection
        IfGreater "Region_Table_#2_Entry_Count" 0
            move 0
        else
            EndSection
            end
        EndIf
        numbering 1 {
            Section "VHDX - Region Table #2 [Entry #~]"
                hex 16 "Guid (hex)"
                move -16
                ifEqual "Guid (hex)" 0x6677C22D23F600429D64115E9BFD4A08
                        GUID " => Block Allocation Table Region Guid" // Must be unique within the table
                else
                ifEqual "Guid (hex)" 0x06A27C8B90479A4BB8FE575F050F886E
                        GUID " => Metadata Region Guid" // Must be unique within the table
                endIf
                hexadecimal int64 "File Offset (hex)"
                move -8
                int64  "File Offset" // Must be a multiple of 1 MB and MUST be at least 1 MB
                uint32 "Length"      // Must be a multiple of 1 MB
                uint32 "Required (1 = 'Yes')"
            EndSection
        }[Region_Table_#2_Entry_Count]

        goto  "Metadata Offset" // Offset from Region table #1
        Section "VHDX - Metadata Table [Header]"
            char[8] "Metadata Signature" // Must be 0x617461646174656D ("metadata")
            move 2  // skip 2 unused bytes
            uint16 "Metadata_Entry_Count" // Must be less than or equal to 2,047
            move 20 // // skip 20 unused bytes
        endSection
            numbering 1 {
                Section "VHDX - Metadata Table - [Entry #~]"
                    hex 16 "ItemID (hex)"
                    ifEqual "ItemID (hex)" 0x3767A1CA36FA434DB3B633F0AA44E76B
                       move -16
                       GUID " => File Parameters" // https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-vhdx/ec0e9d25-69e4-439e-806a-e0c23f0e1ae6
                    else
                    ifEqual "ItemID (hex)" 0x2442A52F1BCD7648B2115DBED83BF4B8
                       move -16
                       GUID " => Virtual Disk Size" // https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-vhdx/bb51c7bc-63be-4be6-a77c-f1684573033c
                    else
                    ifEqual "ItemID (hex)" 0x1DBF41816FA90947BA47F233A8FAAB5F
                       move -16
                       GUID " => Logical Sector Size" // https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-vhdx/e45dcf18-f45b-4507-8760-e76fa538a61b
                    else
                    ifEqual "ItemID (hex)" 0xC748A3CD5D4471449CC9E9885251C556
                       move -16
                       GUID " => Physical Sector Size" // https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-vhdx/17729765-008b-42c9-9aa7-3cfc595ee1d2
                    else                    
                        ifEqual "ItemID (hex)" 0xAB12CABEE6B2234593EFC309E000C746
                       move -16
                       GUID " => Virtual Disk ID" // https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-vhdx/a0a7450d-551b-46f6-9025-485121aa6aab
                    else
                    ifEqual "ItemID (hex)" 0x2D5FD3A80BB34D45ABF7D3D84834AB0C
                       move -16
                       GUID " => Parent Locator" // https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-vhdx/4f4449cf-af59-45da-9045-c4950b9438b2
                    endIf
                    hexadecimal uint32 "(Relative to metadata) Offset (hex)"
                    move -4
                    uint32 "(Relative to metadata) Offset (dec)" // Relative to the beginning of the metadata region
                    uint32 "Entry #~ Length"
                    move 8
                endSection
            }[Metadata_Entry_Count]
        endIF

end