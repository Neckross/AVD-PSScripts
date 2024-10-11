#==================================================================================================================================#
# Version     = 0.2
# Script Name = AVD - Detection script for FSLogix (Standard setup).ps1
# Description = This is a detection script to check registry keys exist on AVD Host Pools Multi-session for FSLogix Standard setup.
# Notes       = Variable changes needed ($VHDLocations)
#==================================================================================================================================#

# Define the log file location
$logFolder = "C:\Temp"
$logFile = "$logFolder\FSLogixDetectionLog.txt"

# Ensure the log folder exists
if (-not (Test-Path -Path $logFolder)) {
  New-Item -Path $logFolder -ItemType Directory | Out-Null
}

# Function to write log entries
function Write-Log {
  param (
    [string]$message
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logEntry = "$timestamp - $message"
  Write-Host $logEntry
  $logEntry | Out-File -FilePath $logFile -Append
}

# Define the registry paths
$fsLogixProfilesRegPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
$kerberosRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"

# Define the Storage Account UNC Path value (Update this before running the script)
$VHDLocations = "\\storage-account-name.file.core.windows.net\share-name"

# Start logging
Write-Log "Starting FSLogix registry detection."

# Ensure the device is running (Check if the WMI "Winmgmt" service is running)
$wmiService = Get-Service -Name "Winmgmt" -ErrorAction SilentlyContinue
if ($wmiService.Status -ne 'Running') {
  Write-Log "Azure VM WMI (Winmgmt) service is not running. Exiting script."
  Exit 0
}

Write-Log "Azure VM WMI service is running. Proceeding with detection."

# Ensure the device is an AVD Host (Check RDInfraAgent)
$avdKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue
if (-not $avdKey) {
  Write-Log "This device is not an AVD Host. Exiting script."
  Exit 0
}

Write-Log "Device is confirmed as an AVD Host."

# Ensure the device is an AVD Multi-Session (Windows SKU 175 = Multi-Session)
$windowsSKU = (Get-WmiObject -Class Win32_OperatingSystem).OperatingSystemSKU
if ($windowsSKU -ne 175) {
  Write-Log "This is not an AVD Multi-Session host. Exiting script."
  Exit 0
}

Write-Log "Device is confirmed as an AVD Multi-Session host."

# Define expected values
$expectedValues = @{
  "Enabled"                              = 1
  "DeleteLocalProfileWhenVHDShouldApply" = 1
  "FlipFlopProfileDirectoryName"         = 1
  "LockedRetryCount"                     = 3
  "LockedRetryInterval"                  = 15
  "ProfileType"                          = 0
  "ReAttachIntervalSeconds"              = 15
  "ReAttachRetryCount"                   = 3
  "SizeInMBs"                            = 30000
  "VHDLocations"                         = $VHDLocations
  "VolumeType"                           = "VHDX"
  "IsDynamic"                            = 1
  "SIDDirNamePattern"                    = "%username%%sid%"
  "SIDDirNameMatch"                      = "%username%%sid%"
}

# Kerberos registry key expected values
$kerberosExpectedValues = @{
  "CloudKerberosTicketRetrievalEnabled" = 1
}

# Function to check if registry key exists and matches expected value
function Check-RegistryKey {
  param (
    [string]$path,
    [string]$keyName,
    [string]$expectedValue
  )

  $actualValue = Get-ItemProperty -Path $path -Name $keyName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $keyName

  if ($actualValue -ne $expectedValue) {
    Write-Log "Mismatch found: $keyName has a value of $actualValue, expected $expectedValue."
    return $false
  }
  else {
    Write-Log "$keyName is set correctly."
    return $true
  }
}

# Initialize a flag to track if remediation is needed
$remediationNeeded = $false

# Check FSLogix Profile registry keys
Write-Log "Checking FSLogix Profile registry keys."
foreach ($key in $expectedValues.Keys) {
  if (-not (Check-RegistryKey -path $fsLogixProfilesRegPath -keyName $key -expectedValue $expectedValues[$key])) {
    $remediationNeeded = $true
  }
}

# Check Kerberos registry key
Write-Log "Checking Kerberos registry keys."
foreach ($key in $kerberosExpectedValues.Keys) {
  if (-not (Check-RegistryKey -path $kerberosRegPath -keyName $key -expectedValue $kerberosExpectedValues[$key])) {
    $remediationNeeded = $true
  }
}

# Exit status
if ($remediationNeeded) {
  Write-Log "Registry keys need remediation."
  Exit 1
}
else {
  Write-Log "All registry keys are set correctly."
  Exit 0
}
