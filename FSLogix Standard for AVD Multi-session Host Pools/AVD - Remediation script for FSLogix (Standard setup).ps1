#===========================================================================================================================#
# Version     = 0.12
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

# Function to create or update registry keys
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
    # Check and create the registry path if it doesn't exist
    if (-not (Test-Path -Path $path)) {
      New-Item -Path $path -Force | Out-Null
      Write-Log "Created registry path: $path"
    }

    # Check if the registry key exists and create/update its value
    $actualValue = (Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $keyName -ErrorAction SilentlyContinue)
    if ($null -eq $actualValue) {
      New-ItemProperty -Path $path -Name $keyName -Value $value -PropertyType $propertyType -Force | Out-Null
      Write-Log "Created $keyName with value $value at $path."
    }
    elseif ($actualValue -ne $value) {
      Set-ItemProperty -Path $path -Name $keyName -Value $value -Force
      Write-Log "Updated $keyName to $value at $path."
    }
    else {
      Write-Log "$keyName is already set to the correct value at $path."
    }
  }
  catch {
    Write-Log "Failed to set or create $keyName at $path."
  }
}

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

# Apply FSLogix Profile registry keys
Write-Log "Remediating FSLogix Profile registry keys."
foreach ($entry in $expectedValues) {
  Set-RegistryKey -path $fsLogixProfilesRegPath -keyName $entry.KeyName -value $entry.Value
}

# Apply Kerberos registry keys
Write-Log "Remediating Kerberos registry keys."
foreach ($entry in $kerberosExpectedValues) {
  Set-RegistryKey -path $kerberosRegPath -keyName $entry.KeyName -value $entry.Value
}

# Verify remediation
Write-Log "Registry keys have been remediated."
Exit 0
