#===================================================================================================================#
# Version     = 0.1
# Script Name = AVD - Install BGInfo on ALL AVD Session Hosts.ps1
# Description = This is a remediation script that install BGInfo extension on ALL AVD Session Hosts.
# Notes       = No variable changes needed
#===================================================================================================================#

# Import necessary modules
Import-Module Az.Accounts
Import-Module Az.Resources
Import-Module Az.Compute
Import-Module Az.DesktopVirtualization

# Extract VM Name from ResourceId
function Get-VMNameFromResourceId {
  param ([string]$resourceId)
  return ($resourceId -split '/virtualMachines/')[-1]
}

# Identify if a VM is an AVD Session Host
function Is-AVDSessionHost {
  param ([string]$vmName)

  $hostPools = Get-AzWvdHostPool

  foreach ($hostPool in $hostPools) {
    $resourceGroupName = ($hostPool.Id -split '/')[4]
    $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $resourceGroupName -HostPoolName $hostPool.Name

    foreach ($sessionHost in $sessionHosts) {
      $sessionHostVMName = Get-VMNameFromResourceId -resourceId $sessionHost.ResourceId

      if ($sessionHostVMName -eq $vmName) {
        Write-Host "VM $vmName matches with Session Host: $sessionHostVMName (Host Pool: $($hostPool.Name))" -ForegroundColor Green
        return $true
      }
    }
  }
  Write-Host "VM $vmName is not an AVD Session Host." -ForegroundColor Yellow
  return $false
}

# Install BGInfo extension if not present
function Install-BGInfo {
  param ([string]$resourceGroupName, [string]$vmName)

  $bginfoExtension = Get-AzVMExtension `
    -ResourceGroupName $resourceGroupName `
    -VMName $vmName `
    -Name "BGInfo" `
    -ErrorAction SilentlyContinue

  if (-not $bginfoExtension) {
    Write-Host "Installing BGInfo on VM: $vmName in Resource Group: $resourceGroupName" -ForegroundColor Cyan
    Set-AzVMBginfoExtension `
      -ResourceGroupName $resourceGroupName `
      -VMName $vmName `
      -Name "BGInfo"
  }
  else {
    Write-Host "BGInfo is already installed on VM: $vmName in Resource Group: $resourceGroupName" -ForegroundColor Cyan
  }
}

# Iterate over all VMs in each resource group and check if they are AVD Session Hosts, then install BGInfo
$resourceGroups = Get-AzResourceGroup

foreach ($resourceGroup in $resourceGroups) {
  $vms = Get-AzVM -ResourceGroupName $resourceGroup.ResourceGroupName

  foreach ($vm in $vms) {
    $isAVD = Is-AVDSessionHost -vmName $vm.Name

    if ($isAVD) {
      Write-Host "Confirmed AVD Session Host: $($vm.Name)" -ForegroundColor Green
      Install-BGInfo -resourceGroupName $resourceGroup.ResourceGroupName -vmName $vm.Name
    }
  }
}
