# BGInfo extension for AVD Session Hosts
This is a script remediation that loops through all AzVMs, ensures only the AVD Session Hosts are captured and checks if BGInfo extension is installed, otherwise it gets installed on missing AVD Session Hosts.

> IMPORTANT: BGInfo extension for AVD is not installed by default, this is completely OPTIONAL.

## For reference
BGInfo extension only gets installed by default on New-AzVM servers, but not for windows clients (eg. Windows 10 or 11, Enterprise or Multi-session).

* Set-AzVMBginfoExtension docs:
[Click Here](https://learn.microsoft.com/en-us/powershell/module/az.compute/set-azvmbginfoextension?view=azps-12.3.0)

## Solution outcome
For AVD environments, is usefull to add some visibility around the device information.

## Using this solution
Installing BGInfo extension can take a few minutes, grab a cup of coffee and let it run.

> Note: The scripts are not signed. If your organization is blocking the execution of unsigned scripts, they will not run.

> Note: Download script and run it from an azure cloud shell or local PS session.
