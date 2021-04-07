template "$I File Structure"

// Costas Katsavounidis - 2021 v.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000
//
// To be applied to $I files at
// offset 0 of the file

description "$I File Structure"
applies_to file  
read-only

// ref: https://github.com/libyal/dtformats/blob/main/documentation/Windows%20Recycle.Bin%20file%20formats.asciidoc        

begin
   Section "Header"
       int64  "Version"
       int64  "Original File Size"
       FileTime "Deletion date and time"

       ifEqual Version 1 // Introduced in Windows Vista
           string16 256 "Original filename"
       else
       ifEqual Version 2 // Introduced in Windows 10
          uint32 "Nr_of_Filename_Characters"  
          string16 Nr_of_Filename_Characters "Original filename [UTF-16]"
       endIF

   endSection
end