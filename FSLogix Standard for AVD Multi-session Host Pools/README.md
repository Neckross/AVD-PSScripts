# FSLogix Standard for AVD Multi-session Host Pools
This is a Proactive Remediation scripts solution to set FSLogix Standard reg keys exclusively for AVD Multi-session Host Pools.

## For reference
FSLogix is a cloud solution aimed to manage user profiles within an Azure Virtual Desktop environment.
Most commonly used in AVD Multi-session host pools to allow user profile roaming within sessions.
FSLogix has different deployment options (eg. Intune, Azure VM script extension, GPOs, etc..).
FSLogix has different configurations (eg. Standard, HA, DR, etc..), this solution is focused on Standard configuration.

> IMPORTANT: you MUST have configured the Storage Account as part of FSLogix documentation

* FSLogix documentation:
[Click Here](https://learn.microsoft.com/en-us/fslogix/overview-what-is-fslogix)

* FSLogix Standard (+ other Configurations):
[Click Here](https://learn.microsoft.com/en-us/fslogix/concepts-configuration-examples#example-1-standard)

* [Optional] Intune Setting Catalog (FSLogix):
[Click Here](https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles)

* FSLogix deployment options:
[Click Here](https://learn.microsoft.com/en-us/fslogix/concepts-configuration-options)

## Solution outcome
The solution aims to have a continuos proactive remediation for FSLogix Standard configuration in an AVD Multi-session host pools environment to ensure stability and maximize user profiles accessability.

## Using this solution
> Note: The scripts are not signed. If your organization is blocking the execution of unsigned scripts, they will not run.

### Detection Script
The detection script checks if the computer is an AVD Multi-session Host, otherwise the script will not run.
The script will check if FSLogix Standard reg keys exist on the device.
For troubleshooting, there's a written log file stored under C:\Temp in the device.

> IMPORTANT: Update "$VHDLocations" value for Storage Account UNC Path. Download/Update script and Upload to Intune Proactive Remediation scripts blade.

> REMINDER: Configure script to run in device-context "Run this script using logged-on credentials" set NO, And "Run script in 64-bit PowerShell" set YES.

### Remediation Script
The remediation script fuels from the detection script, and will attempt to set the FSLogix Standard reg keys configuration.
For troubleshooting, there's a written log file stored under C:\Temp in the device.

> IMPORTANT: Update "$VHDLocations" value for Storage Account UNC Path. Download/Update script and Upload to Intune Proactive Remediation scripts blade.

> REMINDER: Configure script to run in device-context "Run this script using logged-on credentials" set NO, And "Run script in 64-bit PowerShell" set YES.
