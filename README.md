# [MFT_Browser](https://github.com/kacos2000/MFT_Browser/releases/latest)

<!-- ![MFT_Browser](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/MFTbrowser.jpg) -->
[![MFTbrowser Video](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/undefined-high.gif)](https://vimeo.com/890690247 "$MFT Browser - Click to Watch!")
<!-- ! ![MFTbrowser animation](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/b38GPgFsUh.gif) -->

- Recreates the File/Directory tree structure from an *(extracted)* $MFT file.
- Able to carve FILE records & recreate a Directory tree from a Raw Image *(v.60+)*
- Able to extract the $MFT & recreate the Directory tree from a mounted NTFS volume *(Volume must have a drive letter)* *(v.60+)*
- Supports both 1024 & 4096 byte long records
-----------------

==> **[Latest Version](https://github.com/kacos2000/MFT_Browser/releases/latest)** <==

[Dependencies] 
- [.NET Framework 4.8](https://dotnet.microsoft.com/en-us/download/dotnet-framework/net48)
- [Powershell Version:  5.1](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/install/windows-powershell-system-requirements?view=powershell-5.1)

-----------------
- 'Node Properties' right click option or Double clicking on any file/directory entry gets the full MFT details for that record
- Clicking on any detail of the record, shows the source of the detail in the Hex view grid.
- All timestamps are in UTC

-----------------
Standalone GUI Calc for Dataruns:<br>
=> [MFT_dataruns](https://github.com/kacos2000/MFT_dataruns)

-----------------
### Note:
Recreating the directory tree from large MFT files might take a lot of time, *(possibly hour(s))*, as it needs to map each child record to it's parent node, and as the structure grows, the time needed grows exponentially.

<!--    ![](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/m0.JPG)![](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/m2.JPG)![](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/m1.JPG)
 -->  
- [$MFT Structures *(pdf)*](https://github.com/kacos2000/MFT_Browser/blob/master/MFT%20Structures.pdf)
- [Using MFTbrowser *(pdf)*](https://github.com/kacos2000/MFT_Browser/blob/master/Using%20MFTBrowser.pdf) 
- [How to view a single record from a large MFT file *(pdf)*](https://github.com/kacos2000/MFT_Browser/blob/master/How%20to%20view%20a%20single%20record%20from%20a%20large%20MFT%20file.pdf)<br>
- [Reparse point examples *(pdf)*](https://github.com/kacos2000/MFT_Browser/raw/master/reparse%20point%20examples.pdf)<br>
- Small test $MFT files to play with, can be found [here](https://github.com/EricZimmerman/MFT/tree/3bed2626ee85e9a96a6db70a17407d0c3696056a/MFT.Test/TestFiles) and [here](https://github.com/msuhanov/dfir_ntfs/tree/master/test_data)






