#===========================================================================================================================#
# Version     = 0.11
# Script Name = AVD - Remediation script for FSLogix (Standard setup).ps1
# Description = This is a remediation script to set registry keys on AVD Host Pools Multi-session for FSLogix Standard setup.
# Notes       = Variable changes needed ($VHDLocations)
#===========================================================================================================================#

# Define the log file location
$logFolder = "C:\Temp"
$logFile = "$logFolder\FSLogixRemediationLog.txt"

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
Write-Log "Starting FSLogix registry remediation."

# Ensure the device is running (Check if the WMI "Winmgmt" service is running)
$wmiService = Get-Service -Name "Winmgmt" -ErrorAction SilentlyContinue
if ($wmiService.Status -ne 'Running') {
  Write-Log "Azure VM WMI (Winmgmt) service is not running. Exiting script."
  Exit 0
}

Write-Log "Azure VM WMI service is running. Proceeding with remediation."

# Ensure the device is an AVD Multi-Session (Windows SKU 175 = Multi-Session)
$windowsSKU = (Get-WmiObject -Class Win32_OperatingSystem).OperatingSystemSKU
if ($windowsSKU -ne 175) {
  Write-Log "This is not an AVD Multi-Session host. Exiting script."
  Exit 0
}

Write-Log "Device is confirmed as an AVD Multi-Session host."

# Check if FSLogix Profiles registry path exists
if (-not (Test-Path -Path $fsLogixProfilesRegPath)) {
  Write-Log "FSLogix Profiles registry path does not exist. Exiting script."
  Exit 1
}

Write-Log "FSLogix Profiles registry path exists."

# Define expected FSLogix Profile values
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
}

# Kerberos registry key expected values
$kerberosExpectedValues = @{
  "CloudKerberosTicketRetrievalEnabled" = 1
}

# Function to set or create registry keys with appropriate property types
function Set-RegistryKey {
  param (
    [string]$path,
    [string]$keyName,
    [string]$value
  )

  # Determine the correct property type based on the keyName
  $propertyType = "DWORD"
  if ($keyName -eq "VHDLocations") {
    $propertyType = "MultiString"
  }
  elseif ($keyName -eq "VolumeType") {
    $propertyType = "String"
  }

  try {
    if (-not (Test-Path -Path $path)) {
      New-Item -Path $path -Force | Out-Null
      Write-Log "Created registry path: $path"
    }

    if (-not (Get-ItemProperty -Path $path -Name $keyName -ErrorAction SilentlyContinue)) {
      # Create the registry key if it doesn't exist
      New-ItemProperty -Path $path -Name $keyName -Value $value -PropertyType $propertyType -Force | Out-Null
      Write-Log "Created $keyName with value $value at $path."
    }
    else {
      # Update the registry key if it exists
      Set-ItemProperty -Path $path -Name $keyName -Value $value -Force
      Write-Log "Updated $keyName to $value at $path."
    }
  }
  catch {
    Write-Log "Failed to set or create $keyName at $path."
  }
}

# Apply the correct FSLogix Profile values
Write-Log "Remediating FSLogix Profile registry keys."
foreach ($key in $expectedValues.Keys) {
  Set-RegistryKey -path $fsLogixProfilesRegPath -keyName $key -value $expectedValues[$key]
}

# Apply the Kerberos values
Write-Log "Remediating Kerberos registry keys."
foreach ($key in $kerberosExpectedValues.Keys) {
  Set-RegistryKey -path $kerberosRegPath -keyName $key -value $kerberosExpectedValues[$key]
}

# Verify remediation
Write-Log "Registry keys have been remediated."
Exit 0
