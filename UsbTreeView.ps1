
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Load own Device names
. "$scriptDir\UsbDeviceNames.ps1"

# Get USB Root Hubs
$UsbRootHubs = get-wmiobject -class "Win32_USBHub" -namespace "root\CIMV2" | Where-object { $_.Caption -eq 'USB Root Hub'} 

# Get USB Device list 
$UsbDevices = get-wmiobject -class "Win32_USBControllerDevice" -namespace "root\CIMV2"  | Select Dependent

$UsbTree = @{}
$UsbDeviceNames = @{}
 
Write-Output "Enumerating $($UsbDevices.length-1) Usb Devices"
Write-Host "$("........................................................................................................................................................................".Substring(1,$UsbDevices.length-1))"
foreach($UsbDevice in $UsbDevices){
	# Get DeviceId
	$arrDependent = ($UsbDevice.Dependent.Split("="))
	$DeviceId = $arrDependent[1] -replace """",""
	$DeviceId = $DeviceId -replace "\\\\","\"
	# Get parent Deviceid
	$ParentId = $(& $scriptDir\get-parent-device.exe "$($DeviceId)" ".*")

	# Add DeviceId to Parents hash table 
	if (! $UsbTree.Contains($ParentId)){
		$NewHashTable = @{}
		$UsbTree.Add($ParentId,$NewHashTable)
	}
	$UsbTree[$ParentId].Add($DeviceId,"Yes")

	# Get devices name (Caption)
	$UsbDeviceNames.Add($DeviceId,(get-wmiobject -class "Win32_PnPEntity" -namespace "root\CIMV2"  | Where-Object { $_.DeviceId -eq $DeviceId } | Select Caption).Caption)
#	Write-output "$($UsbDeviceNames[$DeviceId])`t$($DeviceId)`t$($ParentId)" 
	Write-host -NoNewline "." 
}
Write-output ""

function RecurseUSBRoot 
{
   param(
	[hashtable]	$UsbDeviceNames,
	[hashtable]	$OwnUsbDeviceNames,
	[hashtable]	$UsbTree,
     [string]$ParentId,
     [Int32]$Level
   )  

	# Use own device name if found 
	if ($OwnUsbDeviceNames.Contains($ParentId)){
		$DeviceName = $OwnUsbDeviceNames[$ParentId]
	} else {
		$DeviceName = $UsbDeviceNames[$ParentId]
	}
		
	Write-Host "$("`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t`t".Substring(1,$Level))$($DeviceName) ($($ParentId))"

	# If device is saved as parent
	if ( $UsbTree.Contains($ParentId)){
		# Loop it's children
		foreach ($ChildId in ($UsbTree[$ParentId]).Keys){
			 RecurseUSBRoot $UsbDeviceNames $OwnUsbDeviceNames $UsbTree $ChildId ($Level+1)
		}
	}
}

Write-Output "          Usb Tree"
Write-Output "----------------------------"
# Start by looping USB Root Hubs
foreach($UsbRootHub in $UsbRootHubs){
	RecurseUSBRoot $UsbDeviceNames $OwnUsbDeviceNames $UsbTree $UsbRootHub.DeviceId 0
}