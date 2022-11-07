#Requires -RunAsAdministrator

<#
	.SYNOPSIS
		Extracts master file table from volume.
		
		Version: 0.3
		Author : Costas Katsavounidis (@kacos2000)
		Fixed bug with negative dataruns
		Changed extracted Filename to more human friendly one (inc. Volume Serial & extracted timestamp in FileTimeUtc)
		Added Support for both 1K & 4K records
		Added extra info on extracted MFT (inc. MD5/SHA256 hashes)
		Updated output -> parameter CSV is now a switch (true/false)
		- Note: Remote Host features NOT tested
		
		Version: 0.1
		Author : Jesse Davis (@secabstraction)
		License: BSD 3-Clause
	
	.DESCRIPTION
		This module exports the master file table (MFT) and writes it to $env:TEMP.
		in the form of $MFT_g_48D72F27_133120553486907264
		where "g" is the Driveletter, "48D72F27" is the Volume Serial Number, and
		"133120553486907264" the timestamp of the start of the extraction.

			You can convert this timestamp at a CMD terminal:
			C:\w32tm -ntte 133120553486907264
			154074 17:09:08.6907264 - 4/11/2022 7:09:08 pm
		
			or with Powershell:
			[Datetime]::FromFileTimeUtc(133120553486907264)
			Friday, November 4, 2022 5:09:08 pm

	.PARAMETER ComputerName
		Specify host(s) to retrieve data from.
	
	.PARAMETER ThrottleLimit
		Specify maximum number of simultaneous connections.
	
	.PARAMETER Volume
		Specify a volume to retrieve its master file table.
		If ommited, it defaults to System (C:\)
	
	.PARAMETER CSV
		Output log file as comma separated values to the same folder as the extracted $MFT file(s).
		Terminal Output is suppressed
	
	.EXAMPLE
		The following example extracts the master file table from the local system volume and writes it to TEMP.
		
		PS C:\> Export-MFT
	
	.EXAMPLE
		The following example extracts the master file table from the system volume of Server01 and writes it to TEMP.
		
		PS C:\> Export-MFT -ComputerName Server01
	
	.EXAMPLE
		The following example extracts the master file table from the F volume on Server01 and writes it to TEMP.
		
		PS C:\> Export-MFT -ComputerName Server01 -Volume F

	.EXAMPLE
		The following example extracts the master file table from the F volume writes it to TEMP.
		A CSV (Comma Separated Log File is created/appended with info on the xtracted MFT
		
		PS C:\> Export-MFT  -Volume G -CSV

		Included info example:

		ComputerName         : MYPC
		Cluster Size         : 4096
		MFT Record Size      : 4096
		MFT Size             : 140 MB
		MFT Volume           : G
		MFT Volume Serial Nr : 48D72F27
		MFT File MD5 Hash    : 825C0DC93FEDDF98E77B992C9D1BEE23
		MFT File SHA256 Hash : E17AF5EEC50CF603CAC708A2018C57A0146E713077F2AE4F0320482BA6A7A6A3
		MFT File             : e:\Temp\Export-MFT_4.11.2022\\$MFT_g_48D72F27_133120553486907264


#>
[CmdletBinding()]
param
(
	[Parameter(ValueFromPipeline = $true,
			   Position = 0)]
	[ValidateNotNullOrEmpty()]
	[String[]]$ComputerName,
	[ValidateNotNullOrEmpty()]
	[Int]$ThrottleLimit = 10,
	[ValidateNotNullOrEmpty()]
	[Char]$Volume = 0,
	[switch]$CSV
) #End Param
        
    $ScriptTime = [Diagnostics.Stopwatch]::StartNew()
	$td = (Get-Date).ToShortDateString().replace("/", ".")
	$OutputFolderPath = "$($env:TEMP)\Export-MFT_$($td)"

	$RemoteScriptBlock = {
	Param (
		$Volume,
		$OutputFolderPath
	)
	
		if ($Volume -ne 0)
		{
			$Win32_Volume = Get-CimInstance -ClassName CIM_StorageVolume | where DriveLetter -match $Volume
			#$Win32_Volume = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter LIKE '$($Volume):'"
            if ($Win32_Volume.FileSystem -ne "NTFS") {
			Write-Error "$($Volume) does not have an NTFS filesystem."
                break
            }
        }
        else {
			$Win32_Volume = Get-CimInstance -ClassName CIM_StorageVolume | where DriveLetter -match $env:SystemDrive
			#$Win32_Volume = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter LIKE '$($env:SystemDrive)'"
			if ($Win32_Volume.FileSystem -ne "NTFS")
				{ 
	                Write-Error "$($env:SystemDrive) does not have an NTFS filesystem."
	                break
				}
				else
				{
					$Volume = ($env:SystemDrive).Trim(":")
				}
	}
	
	$tnow = (Get-Date).ToFileTimeUtc()
		if (![System.IO.Directory]::Exists($OutputFolderPath))
		{
			$null = [System.IO.Directory]::CreateDirectory($OutputFolderPath)
		}
		$OutputFilePath = "$($OutputFolderPath)\`$MFT_$($Volume)_$($Win32_Volume.SerialNumber.ToString('X'))_$($tnow)"
	
        ## Old -> $OutputFilePath = $env:TEMP + "\$([IO.Path]::GetRandomFileName())"
	
		#region WinAPI
		$Supported = @("WindowsPowerShell", "SAPIEN Technologies")
		$SPaths = [string]::Join('|', $Supported)
		if([System.AppDomain]::CurrentDomain.Basedirectory -notmatch $SPaths)
			{
				Write-Output "Please try running this script in Windows Powershell (PS 5.1)"
				Write-Output "PowerShell 7 is not currently supported"
				break
				
			}
        $GENERIC_READWRITE = 0x80000000
        $FILE_SHARE_READWRITE = 0x02 -bor 0x01
        $OPEN_EXISTING = 0x03
	
		$DynAssembly = New-Object System.Reflection.AssemblyName('MFT')
		$AssemblyBuilder = [System.AppDomain]::CurrentDomain.DefineDynamicAssembly($DynAssembly, [Reflection.Emit.AssemblyBuilderAccess]::Run)
		$AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly($DynAssembly, [Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemory', $false)

        $TypeBuilder = $ModuleBuilder.DefineType('kernel32', 'Public, Class')
        $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
        $SetLastError = [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
        $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor,
            @('kernel32.dll'),
            [Reflection.FieldInfo[]]@($SetLastError),
            @($True))

        #CreateFile
        $PInvokeMethodBuilder = $TypeBuilder.DefinePInvokeMethod('CreateFile', 'kernel32.dll',
            ([Reflection.MethodAttributes]::Public -bor [Reflection.MethodAttributes]::Static),
            [Reflection.CallingConventions]::Standard,
            [IntPtr],
            [Type[]]@([String], [Int32], [UInt32], [IntPtr], [UInt32], [UInt32], [IntPtr]),
            [Runtime.InteropServices.CallingConvention]::Winapi,
            [Runtime.InteropServices.CharSet]::Ansi)
        $PInvokeMethodBuilder.SetCustomAttribute($SetLastErrorCustomAttribute)

        #CloseHandle
        $PInvokeMethodBuilder = $TypeBuilder.DefinePInvokeMethod('CloseHandle', 'kernel32.dll',
            ([Reflection.MethodAttributes]::Public -bor [Reflection.MethodAttributes]::Static),
            [Reflection.CallingConventions]::Standard,
            [Bool],
            [Type[]]@([IntPtr]),
            [Runtime.InteropServices.CallingConvention]::Winapi,
            [Runtime.InteropServices.CharSet]::Auto)
        $PInvokeMethodBuilder.SetCustomAttribute($SetLastErrorCustomAttribute)

        $Kernel32 = $TypeBuilder.CreateType()

        #endregion WinAPI

        # Get handle to volume
        if ($Volume -ne 0) { $VolumeHandle = $Kernel32::CreateFile(('\\.\' + $Volume + ':'), $GENERIC_READWRITE, $FILE_SHARE_READWRITE, [IntPtr]::Zero, $OPEN_EXISTING, 0, [IntPtr]::Zero) }
        else { 
            $VolumeHandle = $Kernel32::CreateFile(('\\.\' + $env:SystemDrive), $GENERIC_READWRITE, $FILE_SHARE_READWRITE, [IntPtr]::Zero, $OPEN_EXISTING, 0, [IntPtr]::Zero) 
            $Volume = ($env:SystemDrive).TrimEnd(':')
        }
        
        if ($VolumeHandle -eq -1) { 
            Write-Error -Message "Unable to obtain read handle for volume $($Volume)"
            break 
        }         
        
        # Create a FileStream to read from the volume handle
        $FileStream = New-Object IO.FileStream($VolumeHandle, [IO.FileAccess]::Read)                   

        # Read VBR from volume
        $VolumeBootRecord = New-Object Byte[](512)                                                     
        if ($FileStream.Read($VolumeBootRecord, 0, $VolumeBootRecord.Length) -ne 512) { Write-Error "Error reading volume $($Volume)'s boot record." }

        # Get bytes per cluster
		$bytespersector = [Bitconverter]::ToUInt16($VolumeBootRecord[0xB .. 0xC], 0)
		$sectorspercluster = [int]$VolumeBootRecord[0xD]
		$bytespercluster = $bytespersector * $sectorspercluster

        # Parse MFT offset from VBR and set stream to its location
        $MftOffset = [Bitconverter]::ToInt32($VolumeBootRecord[0x30..0x37], 0) * $bytespercluster
        $FileStream.Position = $MftOffset

        # Get Volume Serial Number
		$vs = $VolumeBootRecord[0x48 .. 0x4B]
		[System.Array]::Reverse($vs)
		$VolumeSerial = [System.BitConverter]::ToString($vs) -replace '-', ''

        ## Read MFT's file record header & Validate MFT file signature
		$MftFileRecordHeader = New-Object byte[](48)
		if ($FileStream.Read($MftFileRecordHeader, 0, $MftFileRecordHeader.Length) -ne $MftFileRecordHeader.Length)
		{
			Write-Error -Exception "Error reading the `$MFT file record header."
			return
		}
		elseif([System.Text.Encoding]::ASCII.GetString($MftFileRecordHeader[0..3]) -ne 'FILE')
		{
			Write-Error "The `$MFT is corrupt or not an `$MFT"
			return
		}
		
		# Read MFT record Size
		$RecordSize = [Bitconverter]::ToInt32($MftFileRecordHeader[0x1C .. 0x1F], 0)
		
		#fxoffset
		$fxoffset = [Bitconverter]::ToUInt16($MftFileRecordHeader[4 .. 5], 0)
		
		#Nr of fixups
		$nrfixups = [Bitconverter]::ToUInt16($MftFileRecordHeader[6 .. 7], 0) - 1
		
		# Parse values from MFT's file record header
		$OffsetToAttributes = [Bitconverter]::ToUInt16($MftFileRecordHeader[0x14 .. 0x15], 0) # Offset to 1st Attribute
		$AttributesRealSize = [Bitconverter]::ToUInt32($MftFileRecordHeader[0x18 .. 0x21], 0) # Logical Size of record
		
		# Read MFT's full file record
		$MftFileRecord = New-Object System.Byte[]($RecordSize)
		$FileStream.Position = $MftOffset
		if ($FileStream.Read($MftFileRecord, 0, $MftFileRecord.Length) -ne $RecordSize)
		{
			Write-Error -Message "Error reading `$MFT file record."
			return
		}
		
		# Replace the Fix-ups
		foreach ($fx in (1 .. $nrfixups))
		{
			$MftFileRecord[(($fx * 512) - 2)] = $MftFileRecord[($fxoffset + (2 * $fx))]
			$MftFileRecord[(($fx * 512) - 1)] = $MftFileRecord[($fxoffset + (2 * $fx) + 1)]
		}
		
		# Parse MFT's attributes from file record
		$Attributes = New-object System.Byte[]($AttributesRealSize - $OffsetToAttributes)
		[Array]::Copy($MftFileRecord, $OffsetToAttributes, $Attributes, 0, $Attributes.Length)
	
	# Find Data attribute
	try
	{
		$CurrentOffset = 0
		do
		{
			$AttributeType = [Bitconverter]::ToUInt32($Attributes[$CurrentOffset .. $($CurrentOffset + 3)], 0)
			$AttributeSize = [Bitconverter]::ToUInt32($Attributes[$($CurrentOffset + 4) .. $($CurrentOffset + 7)], 0)
			$CurrentOffset += $AttributeSize
		}
		until ($AttributeType -eq 128)
	}catch{break}
	# Parse data attribute from all attributes
        $DataAttribute = $Attributes[$($CurrentOffset - $AttributeSize)..$($CurrentOffset - 1)]

        # Parse the MFT logical size from data attribute
        $MftSize = [Bitconverter]::ToUInt64($DataAttribute[0x30..0x37], 0)
        
        # Parse data runs from data attribute
        $OffsetToDataRuns = [Bitconverter]::ToInt16($DataAttribute[0x20..0x21], 0)        
        $DataRuns = $DataAttribute[$OffsetToDataRuns..$($DataAttribute.Length -1)]
        
        # Convert data run info to string[] for calculations
		$Runlist = [Bitconverter]::ToString($DataRuns) -replace '-',''
        
        # Setup to read MFT
        $FileStreamOffset = 0
        $DataRunStringsOffset = 0        
        $TotalBytesWritten = 0
		try
		{
			$OutputFileStream = [IO.File]::OpenWrite($OutputFilePath)
		}
		catch
		{
			Write-Error "Error creating out file $($OutputFilePath)"
			break
		}
	
	# MD5 Hash	
		$md5new = [System.Security.Cryptography.MD5]::Create()
        $sha256new = [System.Security.Cryptography.SHA256]::Create()
		$dr = 0

		# Start the extraction
        do
		{
			$StartBytes = [int]"0x$($Runlist.Substring($DataRunStringsOffset + 0, 1))"
			$LengthBytes = [int]"0x$($Runlist.Substring($DataRunStringsOffset + 1, 1))"
			
			# start of extend	
			$starth = $Runlist.Substring($DataRunStringsOffset + $LengthBytes * 2 + 2, $StartBytes * 2) -split "(..)"
			[array]::reverse($starth)
			$starth = (-join $starth).trim() -replace " ", ""
			$DataRunStart = [bigint]::Parse($starth, 'AllowHexSpecifier')
			
			# Length of Extend
			$lengthh = $Runlist.Substring($DataRunStringsOffset + 2, $LengthBytes * 2) -split "(..)"
			[array]::reverse($lengthh)
			$lengthh = (-join $lengthh).trim() -replace " ", ""
			$DataRunLength = [bigint]::Parse($lengthh, 'AllowHexSpecifier')
			# Get the Logical Size & not the Physical (Allocated)
			$MftData = if (($TotalBytesWritten + $bytespercluster * $DataRunLength) -gt $MftSize)
			{
				New-Object System.Byte[]($MftSize - $TotalBytesWritten)
			}
			else { New-Object System.Byte[]($bytespercluster * $DataRunLength) }
			$FileStreamOffset += ($DataRunStart * $bytespercluster)
			$FileStream.Position = $FileStreamOffset
			
			if ($FileStream.Read($MftData, 0, $MftData.Length) -ne $MftData.Length)
			{
				Write-Error "Possible error reading MFT data"
			}
			$OutputFileStream.Write($MftData, 0, $MftData.Length)
			
			# compute hashes (partial)
			$null = $md5new.TransformBlock($MftData, 0, $MftData.Length, $null, 0)
			$null = $sha256new.TransformBlock($MftData, 0, $MftData.Length, $null, 0)
			# Get total bytes
			$TotalBytesWritten += $MftData.Length
			$DataRunStringsOffset += ($StartBytes + $LengthBytes + 1) * 2
			
            $dr++
		}
		until ($TotalBytesWritten -eq $MftSize)
		Write-Host  "Saved $($dr) Dataruns - Total bytes written: $($MftSize)" -InformationAction Continue
        $FileStream.Dispose()
        $OutputFileStream.Dispose()

        # Get Final (Full) Hash
		$md5new.TransformFinalBlock([byte[]]::new(0), 0, 0)
        $sha256new.TransformFinalBlock([byte[]]::new(0), 0, 0)
		$md5 = [System.BitConverter]::ToString($md5new.Hash).Replace("-", "")
        $sha256 = [System.BitConverter]::ToString($sha256new.Hash).Replace("-", "")

        $Properties = [Ordered]@{
            'ComputerName' = $env:COMPUTERNAME
            'Cluster Size' = $bytespercluster
            'MFT Record Size' = $RecordSize
            'MFT Size' = "$($MftSize / 1024 / 1024) MB"
            'MFT Volume' = $Volume.ToString().ToUpper()
            'MFT Volume Serial Nr' = $VolumeSerial
            'MFT File MD5 Hash' = $md5
            'MFT File SHA256 Hash' = $sha256
            'MFT File' = $OutputFilePath
        }
        New-Object -TypeName PSObject -Property $Properties
    } # End RemoteScriptBlock

	$args = @(
		$Volume
		$OutputFolderPath
	)

    if ($PSBoundParameters['ComputerName']) {   
        $ReturnedObjects = Invoke-Command -ComputerName $ComputerName -ScriptBlock $RemoteScriptBlock -ArgumentList $args -SessionOption (New-PSSessionOption -NoMachineProfile) -ThrottleLimit $ThrottleLimit
    }
    else { $ReturnedObjects = Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList $args }

    if ($ReturnedObjects -ne $null -and $PSBoundParameters['CSV'])
		{
	$OutputCSVPath = "$($OutputFolderPath)\Export-MFT_Log.csv"
	if (![System.IO.File]::Exists($OutputCSVPath))
				{
					$ReturnedObjects | Export-Csv -Path $OutputCSVPath -NoTypeInformation -ErrorAction SilentlyContinue
				}
				else
				{
					$ReturnedObjects | Export-Csv -Path $OutputCSVPath -Append  -NoTypeInformation -ErrorAction SilentlyContinue
				}
			Invoke-Item -LiteralPath $OutputCSVPath
		}
	        else { Write-Output $ReturnedObjects }

    [GC]::Collect()
    $ScriptTime.Stop()
    Write-Output "Extraction Finished in: $($ScriptTime.Elapsed)"






# SIG # Begin signature block
# MIIviAYJKoZIhvcNAQcCoIIveTCCL3UCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCV611KKIS0qwlm
# KbRu06h933xEy+9JcZRaZkujcmLsrqCCKI0wggQyMIIDGqADAgECAgEBMA0GCSqG
# SIb3DQEBBQUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQIDBJHcmVhdGVyIE1hbmNo
# ZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoMEUNvbW9kbyBDQSBMaW1p
# dGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2VydmljZXMwHhcNMDQwMTAx
# MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFD
# b21vZG8gQ0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZp
# Y2VzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvkCd9G7h6naHHE1F
# RI6+RsiDBp3BKv4YH47kAvrzq11QihYxC5oG0MVwIs1JLVRjzLZuaEYLU+rLTCTA
# vHJO6vEVrvRUmhIKw3qyM2Di2olV8yJY897cz++DhqKMlE+faPKYkEaEJ8d2v+PM
# NSyLXgdkZYLASLCokflhn3YgUKiRx2a163hiA1bwihoT6jGjHqCZ/Tj29icyWG8H
# 9Wu4+xQrr7eqzNZjX3OM2gWZqDioyxd4NlGs6Z70eDqNzw/ZQuKYDKsvnw4B3u+f
# mUnxLd+sdE0bmLVHxeUp0fmQGMdinL6DxyZ7Poolx8DdneY1aBAgnY/Y3tLDhJwN
# XugvyQIDAQABo4HAMIG9MB0GA1UdDgQWBBSgEQojPpbxB+zirynvgqV/0DCktDAO
# BgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zB7BgNVHR8EdDByMDigNqA0
# hjJodHRwOi8vY3JsLmNvbW9kb2NhLmNvbS9BQUFDZXJ0aWZpY2F0ZVNlcnZpY2Vz
# LmNybDA2oDSgMoYwaHR0cDovL2NybC5jb21vZG8ubmV0L0FBQUNlcnRpZmljYXRl
# U2VydmljZXMuY3JsMA0GCSqGSIb3DQEBBQUAA4IBAQAIVvwC8Jvo/6T61nvGRIDO
# T8TF9gBYzKa2vBRJaAR26ObuXewCD2DWjVAYTyZOAePmsKXuv7x0VEG//fwSuMdP
# WvSJYAV/YLcFSvP28cK/xLl0hrYtfWvM0vNG3S/G4GrDwzQDLH2W3VrCDqcKmcEF
# i6sML/NcOs9sN1UJh95TQGxY7/y2q2VuBPYb3DzgWhXGntnxWUgwIWUDbOzpIXPs
# mwOh4DetoBUYj/q6As6nLKkQEyzU5QgmqyKXYPiQXnTUoppTvfKpaOCibsLXbLGj
# D56/62jnVvKu8uMrODoJgbVrhde+Le0/GreyY+L1YiyC1GoAQVDxOYOflek2lphu
# MIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0BAQwFADB7
# MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYD
# VQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEhMB8GA1UE
# AwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAwMFoXDTI4
# MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
# aXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5nIFJvb3Qg
# UjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIEJHQu/xYj
# ApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7fbu2ir29
# BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGrYbNzszwL
# DO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTHqi0Eq8Nq
# 6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv64IplXCN
# /7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2JmRCxrds+
# LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0POM1nqFOI
# +rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXybGWfv1Vb
# HJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyheBe6QTHrn
# xvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXycuu7D1fkK
# dvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7idFT/+IAx1
# yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQYMBaAFKAR
# CiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJwIDaRXBeF
# 5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUEDDAKBggr
# BgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmljYXRlU2Vy
# dmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3SamES4aUa1
# qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+BtlcY2fU
# QBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8ZsBRNraJ
# AlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx2jLsFeSm
# TD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyoXZ3JHFuu
# 2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p1FiAhORF
# e1rYMIIFgzCCA2ugAwIBAgIORea7A4Mzw4VlSOb/RVEwDQYJKoZIhvcNAQEMBQAw
# TDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjYxEzARBgNVBAoTCkds
# b2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMTQxMjEwMDAwMDAwWhcN
# MzQxMjEwMDAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBS
# NjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJUH6HPKZvnsFMp7PPcNCPG0RQss
# grRIxutbPK6DuEGSMxSkb3/pKszGsIhrxbaJ0cay/xTOURQh7ErdG1rG1ofuTToV
# Bu1kZguSgMpE3nOUTvOniX9PeGMIyBJQbUJmL025eShNUhqKGoC3GYEOfsSKvGRM
# IRxDaNc9PIrFsmbVkJq3MQbFvuJtMgamHvm566qjuL++gmNQ0PAYid/kD3n16qIf
# KtJwLnvnvJO7bVPiSHyMEAc4/2ayd2F+4OqMPKq0pPbzlUoSB239jLKJz9CgYXfI
# WHSw1CM69106yqLbnQneXUQtkPGBzVeS+n68UARjNN9rkxi+azayOeSsJDa38O+2
# HBNXk7besvjihbdzorg1qkXy4J02oW9UivFyVm4uiMVRQkQVlO6jxTiWm05OWgtH
# 8wY2SXcwvHE35absIQh1/OZhFj931dmRl4QKbNQCTXTAFO39OfuD8l4UoQSwC+n+
# 7o/hbguyCLNhZglqsQY6ZZZZwPA1/cnaKI0aEYdwgQqomnUdnjqGBQCe24DWJfnc
# BZ4nWUx2OVvq+aWh2IMP0f/fMBH5hc8zSPXKbWQULHpYT9NLCEnFlWQaYw55PfWz
# jMpYrZxCRXluDocZXFSxZba/jJvcE+kNb7gu3GduyYsRtYQUigAZcIN5kZeR1Bon
# vzceMgfYFGM8KEyvAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E
# BTADAQH/MB0GA1UdDgQWBBSubAWjkxPioufi1xzWx/B/yGdToDAfBgNVHSMEGDAW
# gBSubAWjkxPioufi1xzWx/B/yGdToDANBgkqhkiG9w0BAQwFAAOCAgEAgyXt6NH9
# lVLNnsAEoJFp5lzQhN7craJP6Ed41mWYqVuoPId8AorRbrcWc+ZfwFSY1XS+wc3i
# EZGtIxg93eFyRJa0lV7Ae46ZeBZDE1ZXs6KzO7V33EByrKPrmzU+sQghoefEQzd5
# Mr6155wsTLxDKZmOMNOsIeDjHfrYBzN2VAAiKrlNIC5waNrlU/yDXNOd8v9EDERm
# 8tLjvUYAGm0CuiVdjaExUd1URhxN25mW7xocBFymFe944Hn+Xds+qkxV/ZoVqW/h
# pvvfcDDpw+5CRu3CkwWJ+n1jez/QcYF8AOiYrg54NMMl+68KnyBr3TsTjxKM4kEa
# SHpzoHdpx7Zcf4LIHv5YGygrqGytXm3ABdJ7t+uA/iU3/gKbaKxCXcPu9czc8FB1
# 0jZpnOZ7BN9uBmm23goJSFmH63sUYHpkqmlD75HHTOwY3WzvUy2MmeFe8nI+z1TI
# vWfspA9MRf/TuTAjB0yPEL+GltmZWrSZVxykzLsViVO6LAUP5MSeGbEYNNVMnbrt
# 9x+vJJUEeKgDu+6B5dpffItKoZB0JaezPkvILFa9x8jvOOJckvB595yEunQtYQEg
# fn7R8k8HWV+LLUNS60YMlOH1Zkd5d9VUWx+tJDfLRVpOoERIyNiwmcUVhAn21klJ
# wGW45hpxbqCo8YLoRT5s1gLXCmeDBVrJpBAwggYaMIIEAqADAgECAhBiHW0MUgGe
# O5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUg
# U2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTla
# MFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNV
# BAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqG
# SIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNs
# fvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFi
# gOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09
# fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmT
# nAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp
# 4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8
# rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ
# 1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh
# 2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaA
# FDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritUpimq
# F6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1Ud
# HwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUF
# BzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2ln
# bmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdv
# LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aV
# cdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWT
# syNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+
# w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWD
# RF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfC
# ipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJszkye
# iaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z76mKn
# zAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGv
# spbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95E
# jza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6
# SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo
# 2bC5a4CH2RwwggZZMIIEQaADAgECAg0B7BySQN79LkBdfEd0MA0GCSqGSIb3DQEB
# DAUAMEwxIDAeBgNVBAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFI2MRMwEQYDVQQK
# EwpHbG9iYWxTaWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTE4MDYyMDAwMDAw
# MFoXDTM0MTIxMDAwMDAwMFowWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2Jh
# bFNpZ24gbnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENB
# IC0gU0hBMzg0IC0gRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDw
# AuIwI/rgG+GadLOvdYNfqUdSx2E6Y3w5I3ltdPwx5HQSGZb6zidiW64HiifuV6PE
# Ne2zNMeswwzrgGZt0ShKwSy7uXDycq6M95laXXauv0SofEEkjo+6xU//NkGrpy39
# eE5DiP6TGRfZ7jHPvIo7bmrEiPDul/bc8xigS5kcDoenJuGIyaDlmeKe9JxMP11b
# 7Lbv0mXPRQtUPbFUUweLmW64VJmKqDGSO/J6ffwOWN+BauGwbB5lgirUIceU/kKW
# O/ELsX9/RpgOhz16ZevRVqkuvftYPbWF+lOZTVt07XJLog2CNxkM0KvqWsHvD9WZ
# uT/0TzXxnA/TNxNS2SU07Zbv+GfqCL6PSXr/kLHU9ykV1/kNXdaHQx50xHAotIB7
# vSqbu4ThDqxvDbm19m1W/oodCT4kDmcmx/yyDaCUsLKUzHvmZ/6mWLLU2EESwVX9
# bpHFu7FMCEue1EIGbxsY1TbqZK7O/fUF5uJm0A4FIayxEQYjGeT7BTRE6giunUln
# EYuC5a1ahqdm/TMDAd6ZJflxbumcXQJMYDzPAo8B/XLukvGnEt5CEk3sqSbldwKs
# DlcMCdFhniaI/MiyTdtk8EWfusE/VKPYdgKVbGqNyiJc9gwE4yn6S7Ac0zd0hNkd
# Zqs0c48efXxeltY9GbCX6oxQkW2vV4Z+EDcdaxoU3wIDAQABo4IBKTCCASUwDgYD
# VR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFOoWxmnn
# 48tXRTkzpPBAvtDDvWWWMB8GA1UdIwQYMBaAFK5sBaOTE+Ki5+LXHNbH8H/IZ1Og
# MD4GCCsGAQUFBwEBBDIwMDAuBggrBgEFBQcwAYYiaHR0cDovL29jc3AyLmdsb2Jh
# bHNpZ24uY29tL3Jvb3RyNjA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vY3JsLmds
# b2JhbHNpZ24uY29tL3Jvb3QtcjYuY3JsMEcGA1UdIARAMD4wPAYEVR0gADA0MDIG
# CCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5
# LzANBgkqhkiG9w0BAQwFAAOCAgEAf+KI2VdnK0JfgacJC7rEuygYVtZMv9sbB3DG
# +wsJrQA6YDMfOcYWaxlASSUIHuSb99akDY8elvKGohfeQb9P4byrze7AI4zGhf5L
# FST5GETsH8KkrNCyz+zCVmUdvX/23oLIt59h07VGSJiXAmd6FpVK22LG0LMCzDRI
# RVXd7OlKn14U7XIQcXZw0g+W8+o3V5SRGK/cjZk4GVjCqaF+om4VJuq0+X8q5+dI
# ZGkv0pqhcvb3JEt0Wn1yhjWzAlcfi5z8u6xM3vreU0yD/RKxtklVT3WdrG9KyC5q
# ucqIwxIwTrIIc59eodaZzul9S5YszBZrGM3kWTeGCSziRdayzW6CdaXajR63Wy+I
# Lj198fKRMAWcznt8oMWsr1EG8BHHHTDFUVZg6HyVPSLj1QokUyeXgPpIiScseeI8
# 5Zse46qEgok+wEr1If5iEO0dMPz2zOpIJ3yLdUJ/a8vzpWuVHwRYNAqJ7YJQ5NF7
# qMnmvkiqK1XZjbclIA4bUaDUY6qD6mxyYUrJ+kPExlfFnbY8sIuwuRwx773vFNgU
# QGwgHcIt6AvGjW2MtnHtUiH+PvafnzkarqzSL3ogsfSsqh3iLRSd+pZqHcY8yvPZ
# HL9TTaRHWXyVxENB+SXiLBB+gfkNlKd98rUJ9dhgckBQlSDUQ0S++qCV5yBZtnjG
# pGqqIpswggZoMIIEUKADAgECAhABSJA9woq8p6EZTQwcV7gpMA0GCSqGSIb3DQEB
# CwUAMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEw
# LwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0
# MB4XDTIyMDQwNjA3NDE1OFoXDTMzMDUwODA3NDE1OFowYzELMAkGA1UEBhMCQkUx
# GTAXBgNVBAoMEEdsb2JhbFNpZ24gbnYtc2ExOTA3BgNVBAMMMEdsb2JhbHNpZ24g
# VFNBIGZvciBNUyBBdXRoZW50aWNvZGUgQWR2YW5jZWQgLSBHNDCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAMLJ3AO2G1D6Kg3onKQh2yinHfWAtRJ0I/5e
# L8MaXZayIBkZUF92IyY1xiHslO+1ojrFkIGbIe8LJ6TjF2Q72pPUVi8811j5bazA
# L5B4I0nA+MGPcBPUa98miFp2e0j34aSm7wsa8yVUD4CeIxISE9Gw9wLjKw3/QD4A
# QkPeGu9M9Iep8p480Abn4mPS60xb3V1YlNPlpTkoqgdediMw/Px/mA3FZW0b1XRF
# OkawohZ13qLCKnB8tna82Ruuul2c9oeVzqqo4rWjsZNuQKWbEIh2Fk40ofye8eEa
# VNHIJFeUdq3Cx+yjo5Z14sYoawIF6Eu5teBSK3gBjCoxLEzoBeVvnw+EJi5obPrL
# TRl8GMH/ahqpy76jdfjpyBiyzN0vQUAgHM+ICxfJsIpDy+Jrk1HxEb5CvPhR8toA
# Ar4IGCgFJ8TcO113KR4Z1EEqZn20UnNcQqWQ043Fo6o3znMBlCQZQkPRlI9Lft3L
# bbwbTnv5qgsiS0mASXAbLU/eNGA+vQIDAQABo4IBnjCCAZowDgYDVR0PAQH/BAQD
# AgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBRba3v0cHQIwQ0q
# yO/xxLlA0krG/TBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0MDIGCCsGAQUFBwIB
# FiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAMBgNVHRMB
# Af8EAjAAMIGQBggrBgEFBQcBAQSBgzCBgDA5BggrBgEFBQcwAYYtaHR0cDovL29j
# c3AuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0MEMGCCsGAQUFBzAC
# hjdodHRwOi8vc2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RzYWNhc2hh
# Mzg0ZzQuY3J0MB8GA1UdIwQYMBaAFOoWxmnn48tXRTkzpPBAvtDDvWWWMEEGA1Ud
# HwQ6MDgwNqA0oDKGMGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2Fj
# YXNoYTM4NGc0LmNybDANBgkqhkiG9w0BAQsFAAOCAgEALms+j3+wsGDZ8Z2E3JW2
# 318NvyRR4xoGqlUEy2HB72Vxrgv9lCRXAMfk9gy8GJV9LxlqYDOmvtAIVVYEtuP+
# HrvlEHZUO6tcIV4qNU1Gy6ZMugRAYGAs29P2nd7KMhAMeLC7VsUHS3C8pw+rcryN
# y+vuwUxr2fqYoXQ+6ajIeXx2d0j9z+PwDcHpw5LgBwwTLz9rfzXZ1bfub3xYwPE/
# DBmyAqNJTJwEw/C0l6fgTWolujQWYmbIeLxpc6pfcqI1WB4m678yFKoSeuv0lmt/
# cqzqpzkIMwE2PmEkfhGdER52IlTjQLsuhgx2nmnSxBw9oguMiAQDVN7pGxf+LCue
# 2dZbIjj8ZECGzRd/4amfub+SQahvJmr0DyiwQJGQL062dlC8TSPZf09rkymnbOfQ
# MD6pkx/CUCs5xbL4TSck0f122L75k/SpVArVdljRPJ7qGugkxPs28S9Z05LD7Mtg
# Uh4cRiUI/37Zk64UlaiGigcuVItzTDcVOFBWh/FPrhyPyaFsLwv8uxxvLb2qtuto
# I/DtlCcUY8us9GeKLIHTFBIYAT+Eeq7sR2A/aFiZyUrCoZkVBcKt3qLv16dVfLyE
# G02Uu45KhUTZgT2qoyVVX6RrzTZsAPn/ct5a7P/JoEGWGkBqhZEcr3VjqMtaM7WU
# M36yjQ9zvof8rzpzH3sg23IwggZyMIIE2qADAgECAhALYufvMdbwtA/sWXrOPd+k
# MA0GCSqGSIb3DQEBDAUAMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdv
# IExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBD
# QSBSMzYwHhcNMjIwMjA3MDAwMDAwWhcNMjUwMjA2MjM1OTU5WjB2MQswCQYDVQQG
# EwJHUjEdMBsGA1UECAwUS2VudHJpa8OtIE1ha2Vkb27DrWExIzAhBgNVBAoMGkth
# dHNhdm91bmlkaXMgS29uc3RhbnRpbm9zMSMwIQYDVQQDDBpLYXRzYXZvdW5pZGlz
# IEtvbnN0YW50aW5vczCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIxd
# u9+Lc83wVLNDuBn9NzaXp9JzWaiQs6/uQ6fbCUHC4/2lLfKzOUus3e76lSpnmo7b
# kCLipjwZH+yqWRuvrccrfZCoyVvBAuzdE69AMR02Z3Ay5fjN6kWPfACkgLe4D9og
# SDh/ZsOfHD89+yKKbMqsDdj4w/zjIRwcYGgBR6QOGP8mLAIKH7TwvoYBauLlb6aM
# /eG/TGm3cWd4oonwjiYU2fDkhPPdGgCXFem+vhuIWoDk0A0OVwEzDFi3H9zdv6hB
# bv+d37bl4W81zrm42BMC9kWgiEuoDUQeY4OX2RdNqNtzkPMI7Q93YlnJwitLfSrg
# GmcU6fiE0vIW3mkf7mebYttI7hJVvqt0BaCPRBhOXHT+KNUvenSXwBzTVef/9h70
# POF9ZXbUhTlJJIHJE5SLZ2DvjAOLUvZuvo3bGJIIASHnTKEIVLCUwJB77NeKsgDx
# YGDFc2OQiI9MuFWdaty4B0sXQMj+KxZTb/Q0O850xkLIbQrAS6T2LKEuviE6Ua7b
# QFXi1nFZ+r9XjOwZQmQDuKx2D92AUR/qwcpIM8tIbJdlNzEqE/2wwaE10G+sKuX/
# SaJFZbKXqDMqJr1fw0M9n0saSTX1IZrlrEcppDRN+OIdnQL3cf6PTqv1PTS4pZ/9
# m7iweMcU4lLJ7L/8ZKiIb0ThD9kIddJ5coICzr/hAgMBAAGjggGcMIIBmDAfBgNV
# HSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNVHQ4EFgQUidoax6lNhMBv
# wMAg4rCjdP30S8QwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4QgEBBAQDAgQQMEoGA1UdIARDMEEwNQYM
# KwYBBAGyMQECAQMCMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20v
# Q1BTMAgGBmeBDAEEATBJBgNVHR8EQjBAMD6gPKA6hjhodHRwOi8vY3JsLnNlY3Rp
# Z28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNybDB5BggrBgEF
# BQcBAQRtMGswRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2Vj
# dGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRw
# Oi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAG+2x4Vn8dk+Y
# w0Khv6CZY+/QKXW+aG/siN+Wn24ijKmvbjiNEbEfCicwZ12YpkOCnuFtrXs8k9zB
# PusV1/wdH+0buzzSuCmkyx5v4wSqh8OsyWIyIsW/thnTyzYys/Gw0ep4RHFtbNTR
# K4+PowRHW1DxOjaxJUNi9sbNG1RiDSAVkGAnHo9m+wAK6WFOIFV5vAbCp8upQPwh
# aGo7u2hXP/d18mf/4BtQ+J7voX1BFwgCLhlrho0NY8MgLGuMBcu5zw07j0ZFBvyr
# axDPVwDoZw07JM018c2Nn4hg2XbYyMtUkvCi120uI6299fGs6Tmi9ttP4c6pubs4
# TY40jVxlxxnqqvIA/wRYXpWOe5Z3n80OFEatcFtzLrQTyO9Q1ptk6gso/RNpRu3r
# ug+aXqfvP3a32FNZAQ6dUGr0ae57OtgM+hlLMhSSyhugHrnbi9oNAsqa/KA6UtD7
# MxWJIwAqACTqqVjUTKjzaaE+12aS3vaO6tEqCuT+DOtu7aJRPnyyMYIGUTCCBk0C
# AQEwaDBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSsw
# KQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhALYufv
# MdbwtA/sWXrOPd+kMA0GCWCGSAFlAwQCAQUAoEwwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIDEIUIOOf7v3suOd/UXDscQyk2oHs+9w
# yzkO91IB0jEqMA0GCSqGSIb3DQEBAQUABIICABuquBXrVCoW3J7RFTajWBSFf2UH
# 1hXW4KpNpaTfIm95ASbttoLONR93yS/fZnH9UB3iXO2b/aIVQLJ+khEkfUniFjsW
# MRQ4P791hv0Dr5XdViruqzn6gQuaFutFW6bOAr7QMdRhwbg0PPDffTfAt//vkJp7
# GEzT8NvSt4nL+CA33y65GhTd6/lCJy50/jOBE6LIKAiM++sM955iZRiAAWi36DrD
# 7xCAvUmBUQkM2dfujz8fIATD6FMEdCmzugjxJjMu8R0tB1FZN+cZMez0kAx1imru
# jELsJMfkTQSW/VomWYKU7Smt1nXzkKBnAC6m5lRVtDZUXfnHj9loQu/d6ff/SglM
# gLwIb1oLgQWAf31rETyYetlbNtcyotXiHN2o1vcOxMecsJbX3RuEeQftoI/dnXkA
# w7xyoGHwO3vjkNyTK+9ZNFH2FCeE3sCbDFkTZH/GQt3VmHgRuNDCvQg3ItDfKyg/
# dAOFhDAFRLitv20hkYzz4fiXOrzMI83g7+igeWEvT0lPx5P4X55QHWDFvcqn4K1l
# WrH1GhNwocAAPsSruZZ55aqb+UYdB0FKwWTArIe3rZCXV37XbEZMS4nkyL7jsQth
# ZR38zQPC2JxRH0aP8KZIVVgM4z5HvVsf7kwhpcZM8rpKTvSgPvSj9fJJ+fVJSonL
# 151nE9zB9/oBOx7yoYIDbDCCA2gGCSqGSIb3DQEJBjGCA1kwggNVAgEBMG8wWzEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAvBgNVBAMT
# KEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQCEAFIkD3C
# irynoRlNDBxXuCkwCwYJYIZIAWUDBAIBoIIBPTAYBgkqhkiG9w0BCQMxCwYJKoZI
# hvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMjExMDcxMTExMzNaMCsGCSqGSIb3DQEJ
# NDEeMBwwCwYJYIZIAWUDBAIBoQ0GCSqGSIb3DQEBCwUAMC8GCSqGSIb3DQEJBDEi
# BCDyafRSA/wlEvOnY2h0dkrPl15S3nEUDgOXq4kX3IQjkzCBpAYLKoZIhvcNAQkQ
# AgwxgZQwgZEwgY4wgYsEFDEDDhdqpFkuqyyLregymfy1WF3PMHMwX6RdMFsxCzAJ
# BgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhH
# bG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhABSJA9woq8
# p6EZTQwcV7gpMA0GCSqGSIb3DQEBCwUABIIBgJn1FnefxaXs3VmIXIeFKd/mo7Th
# 1DLAa88uHPPjF2sXo3plznOZ1G6Ys7mKIG3ZK47CTSSoprw8Rtgjr4uM5j6qVycO
# 3UNFc4K3cVfjL/yN914uhkJuuhDjyRbWjcYamkdUiKkBvRkCkh5pfnRUv7DGKJs2
# MzfgBf+6/5aEOY0oe6qu3aCOMGAH2zSBg5f9jzOqJZq2H98DtnVKcCq1sYUmR6mJ
# 3eLNjsdgoSnnVo9QZGz2QM7t4AFZPAbNOyhBzNCl3HPBt4R8iApCFQ7LllHXfpgm
# nMgHK1bikKGqu4SfLvYTw8L3cwxQ8AaXuYRCAf/INn7knfPmAupbUwTj25eQD0h4
# gd9EzxBe7kft9VPtBBzLwUUegyGG8mcUV5PevhFphb6k2d2gZfWclZdLxtFPQxB1
# AZ2iAaISGJTKR0D/Tb4TzxbcXDnhR+/n/yTlHe3BkL2xlIyR4T0PGHIVOVuI1T15
# v785iKBaLV//ojEJo+8J9XszfM4v+0dpbtbY0Q==
# SIG # End signature block
