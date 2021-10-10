<#
	.SYNOPSIS
		Decodes an ObjectID GUID
	
	.DESCRIPTION
		Decodes an ObjectID GUID to:
		
		- Formatted ObjectID GUID
		- Version
		- Variant
		- Sequence Nr
		- Created Timestamp (UTC)
		- MAC Address
	
	.PARAMETER Hex
		A description of the Hex parameter.
	
	.EXAMPLE
		PS C:\> Get-ObjectIdFromHex
	
	.OUTPUTS
		System.Management.Automation.PSObject
	
	.NOTES
		Additional information about the function.
#>
function Get-ObjectIdFromHex
{
	[OutputType([pscustomobject])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Hex
	)
	
	try
	{
		# remove 0x and extra spaces
		$Hex = $Hex -replace " ", ""
		$Hex = $Hex.trim() -replace '\s', ''
		
		# check length
		if ($hex.length -ne 32) { return }
		
		# prepare output pscustomobject	
		$PS_ObjectID = [PSCustomObject]@{ }
		
		# Object ID
		$objid = $Hex -replace '(..)(..)(..)(..)(..)(..)(..)(..)(..)(..)', '$4$3$2$1-$6$5-$8$7-$9$10-'
		$ObjectID = [System.GUID]::Parse($objid).Guid.ToUpper()
		
		# Add to pscustomobject			
		$PS_ObjectID | Add-Member -Type NoteProperty -Name 'ObjectID' -Value $ObjectID
		
		$version = [Convert]::ToUInt64("0x$($hex.Substring(14, 1))", 16)
		$vs = [convert]::ToString("0x$($objid.Substring(19, 4))", 2)
		$variant = [Convert]::ToInt16($vs.Substring(0, 2), 2)
		$Sequence = [Convert]::ToInt16($vs.Substring(2, 14), 2)
		
		# Add to pscustomobject		
		$PS_ObjectID | Add-Member -Type NoteProperty -Name 'Version' -Value $version
		$PS_ObjectID | Add-Member -Type NoteProperty -Name 'Variant' -Value $variant
		$PS_ObjectID | Add-Member -Type NoteProperty -Name 'Sequence' -Value $Sequence
		
		# Get MAC address & Timestamp
		if ($objid.Substring(14, 1) -eq 1)
		{
			# Get the Date
			# Get the first 16 bytes 
			$tm = $hex.Substring(0, 16)
			# Replace the Version nimble (14) with 0
			$tm = $tm.Remove(14, 1).Insert(14, '0')
			# Reverse Endianess
			$tm = $tm -split "(..)" -ne ""
			[Array]::Reverse($tm)
			$tm = $tm -join ""
			# Convert to Decimal
			$timedec = [Convert]::ToUInt64("0x$($tm)", 16)
			# Get offsets from 1582 & 1601
			$1582offset = (New-Object DateTime(1582, 10, 15, 0, 0, 0)).Ticks
			$1601offset = (New-Object DateTime(1601, 1, 1, 0, 0, 0)).Ticks
			# Calculate the Date after substracting the two Date offsets
			$ObjectIdCreated = [datetime]::FromFileTimeUtc($timedec - ($1601offset - $1582offset)).ToString("dd/MM/yyyy HH:mm:ss.fffffff")
			
			# Add to pscustomobject	
			$PS_ObjectID | Add-Member -Type NoteProperty -Name 'Created' -Value $ObjectIdCreated
			
			# Format MAC
			$mac = ($hex.Substring(20, 12) -split "(..)" -ne "") -join ":"
			
			# Add to pscustomobject	
			$PS_ObjectID | Add-Member -Type NoteProperty -Name 'MAC' -Value $mac
		}
		# output
		$PS_ObjectID
	}
	catch { $null }
}