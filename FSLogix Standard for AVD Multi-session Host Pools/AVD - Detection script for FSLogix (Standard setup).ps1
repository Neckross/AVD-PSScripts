#===========================================================================================================================#
# Version     = 0.12
# Script Name = AVD - Detection script for FSLogix (Standard setup).ps1
# Description = This is a detection script to check registry keys exist on AVD Host Pools Multi-session for FSLogix Standard setup.
# Notes       = Variable changes needed ($VHDLocations)
#===========================================================================================================================#

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

# Ensure Logging of User/Device Context
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Log "Running as: $currentUser"

# Define the registry paths
$fsLogixProfilesRegPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles"
$kerberosRegPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"

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

# Ensure the device is an AVD Multi-Session (Windows SKU 175 = Multi-Session)
$windowsSKU = (Get-WmiObject -Class Win32_OperatingSystem).OperatingSystemSKU
if ($windowsSKU -ne 175) {
  Write-Log "This is not an AVD Multi-Session host. Exiting script."
  Exit 0
}

Write-Log "Device is confirmed as an AVD Multi-Session host."

# Define expected FSLogix Profile values
$expectedValues = @(
  @{ KeyName = "Enabled"; Value = 1 },
  @{ KeyName = "DeleteLocalProfileWhenVHDShouldApply"; Value = 1 },
  @{ KeyName = "FlipFlopProfileDirectoryName"; Value = 1 },
  @{ KeyName = "LockedRetryCount"; Value = 3 },
  @{ KeyName = "LockedRetryInterval"; Value = 15 },
  @{ KeyName = "ProfileType"; Value = 0 },
  @{ KeyName = "ReAttachIntervalSeconds"; Value = 15 },
  @{ KeyName = "ReAttachRetryCount"; Value = 3 },
  @{ KeyName = "SizeInMBs"; Value = 30000 },
  @{ KeyName = "VHDLocations"; Value = $VHDLocations },
  @{ KeyName = "VolumeType"; Value = "VHDX" },
  @{ KeyName = "IsDynamic"; Value = 1 }
)

# Kerberos registry key expected values
$kerberosExpectedValues = @(
  @{ KeyName = "CloudKerberosTicketRetrievalEnabled"; Value = 1 }
)

# Function to check if a registry path and key exist and match the expected value
function Check-RegistryKey {
  param (
    [string]$path,
    [string]$keyName,
    [string]$expectedValue
  )

  # Check if the registry path exists
  if (-not (Test-Path -Path $path)) {
    Write-Log "Registry path missing: $path"
    return $false
  }

  # Check if the registry key exists
  $actualValue = (Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $keyName -ErrorAction SilentlyContinue)

  if ($null -eq $actualValue) {
    Write-Log "Registry key missing: $keyName at $path"
    return $false
  }

  # Check if the value matches
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

# Check FSLogix Profiles registry keys
Write-Log "Checking FSLogix Profile registry keys."
foreach ($entry in $expectedValues) {
  if (-not (Check-RegistryKey -path $fsLogixProfilesRegPath -keyName $entry.KeyName -expectedValue $entry.Value)) {
    $remediationNeeded = $true
  }
}

# Check Kerberos registry keys
Write-Log "Checking Kerberos registry keys."
foreach ($entry in $kerberosExpectedValues) {
  if (-not (Check-RegistryKey -path $kerberosRegPath -keyName $entry.KeyName -expectedValue $entry.Value)) {
    $remediationNeeded = $true
  }
}

# Exit status based on the results
if ($remediationNeeded) {
  Write-Log "Registry keys need remediation."
  Exit 1
}
else {
  Write-Log "All registry keys are set correctly."
  Exit 0
}
