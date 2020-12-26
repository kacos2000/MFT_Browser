[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate?hosted_button_id=69L3MWGCKVMA6)

# [MFT_Browser](https://github.com/kacos2000/MFT_Browser/releases/latest)

Based on [$MFT Record Viewer](https://github.com/kacos2000/MFT_Record_Viewer)

- Recreates the File/Directory tree structure based on an offline *(extracted)* $MFT file.
- Double clicking on any file/directory entry gets the full MFT details for that record
- Clicking on any detail of the record, shows the source of the detail in a Hex view grid.

Note: Opening large MFT records might take a lot of time *(possibly hour(s))*, as it needs to map each child record to it's parent, and as the structure grows, the time needed to search is grown exponentially. A couple of $MFT files s to play with can be found [here](https://github.com/EricZimmerman/MFT/tree/3bed2626ee85e9a96a6db70a17407d0c3696056a/MFT.Test/TestFiles)

![MFT_Browser](https://raw.githubusercontent.com/kacos2000/MFT_Browser/master/I/MFTbrowser.jpg)
