[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate?hosted_button_id=69L3MWGCKVMA6)

# [MFT_Browser](https://github.com/kacos2000/MFT_Browser/releases/latest)

<!-- ![MFT_Browser](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/MFTbrowser.jpg) -->
![MFTbrowser animation](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/b38GPgFsUh.gif)

- Recreates the File/Directory tree structure based on an offline *(extracted)* $MFT file.
- 'Node Properties' right click option or Double clicking on any file/directory entry gets the full MFT details for that record
- Clicking on any detail of the record, shows the source of the detail in the Hex view grid.
- All timestamps are in UTC

==> **[Latest Version](https://github.com/kacos2000/MFT_Browser/releases/latest)** <==

### Note:
You'll need a previously extracted $MFT or $MFTMirr file by another tool *(eg. [FTK Imager](https://accessdata.com/product-download))*

Recreating the directory tree from large MFT files might take a lot of time, *(possibly hour(s))*, as it needs to map each child record to it's parent node, and as the structure grows, the time needed grows exponentially.

<!--    ![](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/m0.JPG)![](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/m2.JPG)![](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/m1.JPG)
 -->  
- [Using MFTbrowser](https://github.com/kacos2000/MFT_Browser/blob/master/Using%20MFTBrowser.pdf) 
- [How to view a single record from a large MFT file](https://github.com/kacos2000/MFT_Browser/blob/master/How%20to%20view%20a%20single%20record%20from%20a%20large%20MFT%20file.pdf)<br>
- [Reparse point examples (pdf)](https://github.com/kacos2000/MFT_Browser/raw/master/reparse%20point%20examples.pdf)<br>
- Small test $MFT files to play with, can be found [here](https://github.com/EricZimmerman/MFT/tree/3bed2626ee85e9a96a6db70a17407d0c3696056a/MFT.Test/TestFiles) and [here](https://github.com/msuhanov/dfir_ntfs/tree/master/test_data)

*Based on [$MFT Record Viewer](https://github.com/kacos2000/MFT_Record_Viewer)*<br>

Note: *WinHex/XWF templates were moved [here](https://github.com/kacos2000/WinHex_Templates)*<br>


