template "INFO2 Structure"

// Costas Katsavounidis - 2021 v.1
// kacos2000 [at] gmail.com
// https://github.com/kacos2000
//
// To be applied to INFO2 files at
// offset 0 of the file

description "INFO2 Structure"
applies_to file  
read-only

// ref: https://github.com/libyal/dtformats/blob/main/documentation/Windows%20Recycler%20file%20formats.asciidoc        

begin
   Section "Header"
       uint32 "Version"
       uint32 "Number_of_file_entries"
       uint32 "Previous Number of file entries"
       uint32 "Record_Size"
       hex 4  "Unknown"
   endSection

   ifGreater  Number_of_file_entries 0
       move 0
   else
       end
   endIF
   numbering 1{
   Section "File Entry #~"
       char[260]  "Original filename [ASCII]"
       uint32 "Index within INFO2"
       uint32 "Drive Number"
       FileTime "Deletion date and time"
       uint32 "Original File size"
       ifGreater Record_Size 280
           string16 260 "Original filename [UTF-16]"
       endIf
   endSection
   }[Number_of_file_entries]
end