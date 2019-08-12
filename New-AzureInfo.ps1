<#
    .SYNOPSIS
        Gathers selected cross subscription Azure configuration details by resource group, and outputs to csv, html, and zip

    .NOTES
        GetRGInfo allows a user to pick specific Subs/RGs in out-gridview 
        and export info to CSV and html report.

        It is designed to be easily edited to for any specific purpose.

        It writes temp data to C:\temp. It also zips up the final results.

    .EXAMPLE
        .\GetRGInfo.ps1

#>

$ScriptDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 
Set-Location $ScriptDir

#if not logged in to Azure, start login
if ($Null -eq (Get-AzContext).Account) {
Connect-AzAccount -Environment AzureUSGovernment}

# Suppress Azure PowerShell Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#region Build Config File

$subs = Get-AzSubscription | Out-GridView -OutputMode Multiple -Title "Select Subscriptions"
$RGs = @()

$elapsed = [System.Diagnostics.Stopwatch]::StartNew()

foreach ( $sub in $subs )
{

    Set-AzContext -SubscriptionId $sub.SubscriptionId
    
    $SubRGs = Get-AzResourceGroup |  
        Select-Object *,
            @{N='Subscription';E={
                    $sub.Name
                }
            },
            @{N='SubscriptionId';E={
                    $sub.Id
                }
            } |        
        Out-GridView -OutputMode Multiple -Title "Select Resource Groups"

    foreach ( $SubRG in $SubRGs )
    {

    $RGs = $RGS + $SubRg

    }
}

#endregion


#region Gather Info

$VMsStatus = @()
$VMs = @()
$Tags = @()
$TagsAVSet = @()
$UniqueTags = @()
$StorageAccounts = @()
$Disks = @() 
$Vnets = @()
$NetworkInterfaces = @()
$NSGs = @()
$AutoAccounts = @()
$LogAnalystics = @()
$KeyVaults = @()
$RecoveryServicesVaults = @()
$BackupItemSummary = @()
$AVSets = @()
$VMImages = @()

# Pre-Processing Some Items:
# VMSize Info

$Locations = @()
$Locations = $RGs.Location | Select-Object -Unique
$VMSizes = $Locations | 
    foreach-object {
        $Location = $_ ;
        Get-AzVMSize -Location $_ | 
        Select-Object *, 
            @{N='Location';E={$Location}},
            @{N='MemoryInGB';E={"{0:n2}" -f [int]($_.MemoryInMB)/[int]1024}} 
    } 

# Main Loop

foreach ( $RG in $RGs )
{
    
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Gathering Info for $($RG.ResourceGroupName) " -ForegroundColor Cyan
    
    Set-AzContext -SubscriptionId $RG.SubscriptionId | Out-Null
 
    # Prep for RestAPI Calls
    $tenantId = (Get-AzSubscription -SubscriptionId $RG.SubscriptionID).TenantId
    $tokenCache = (Get-AzContext).TokenCache
    $cachedTokens = $tokenCache.ReadItems() `
            | Where-Object { $_.TenantId -eq $tenantId } `
            | Sort-Object -Property ExpiresOn -Descending
    $accessToken = $cachedTokens[0].AccessToken
    
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Gathering Info for $($RG.ResourceGroupName) VMs" -ForegroundColor Cyan
    $RGVMs = Get-AzVM -ResourceGroupName $RG.ResourceGroupName
    
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Gathering Info for $($RG.ResourceGroupName) VM Status" -ForegroundColor Cyan
    #Below one by one data grab resolves issue with getting fault/update domain info
    $VMsStatus += $RGVMs | foreach-object {Get-AzVM -ResourceGroupName $RG.ResourceGroupName -Name $_.Name -Status }
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) VMs" -ForegroundColor Cyan
    $VMs +=  $RGVMs |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru |
        foreach-object { $_ | Add-Member -MemberType NoteProperty –Name Size –Value ($_.HardwareProfile.Vmsize) -PassThru} |
        foreach-object { $_ | Add-Member -MemberType NoteProperty –Name OsType –Value ($_.StorageProfile.OsDisk.OsType) -PassThru} |
        foreach-object { $_ | Add-Member -MemberType NoteProperty –Name NicCount –Value ($_.NetworkProfile.NetworkInterfaces.Count) -PassThru} |
        foreach-object { $_ | Add-Member -MemberType NoteProperty –Name NicCountCap –Value ($_.NetworkProfile.NetworkInterfaces.Capacity) -PassThru} |
        foreach-object { $AvailabilitySet = If($_.AvailabilitySetReference){$_.AvailabilitySetReference.Id.Split("/")[8]}Else{$Null} ;
            $_ | Add-Member -MemberType NoteProperty –Name AvailabilitySet –Value ($AvailabilitySet) -PassThru } |        
        forEach-Object { $VM = $_ ; $VMStatus = $VMsStatus | Where-Object {$VM.Name -eq $_.Name -and $VM.ResourceGroupName -eq $_.ResourceGroupName } ;
            $_ | 
            Select-Object *,
                @{N='PowerState';E={
                        ($VMStatus.statuses)[1].code.split("/")[1]
                    }
                },
                @{N='FaultDomain';E={
                        $VMStatus.PlatformFaultDomain
                    }
                },
                @{N='UpdateDomain';E={
                        $VMStatus.PlatformUpdateDomain
                    }
                }
        } |
        forEach-Object { $VM = $_ ; $VMSize = $VMSizes | Where-Object {$VM.Size -eq $_.Name -and $VM.Location -eq $_.Location } ;
            $_ | 
            Select-Object *,
                @{N='NumberOfCores';E={
                        $VMSize.NumberOfCores
                    }
                },
                @{N='MemoryInGB';E={
                        $VMSize.MemoryInGB
                    }
                }  
        } |
        Select-Object *,
            @{N='OsDiskName';E={
                    $_.StorageProfile.OsDisk.Name
                }
            },
            @{N='OsDiskCaching';E={
                    $_.StorageProfile.OsDisk.Caching
                }
            },
            @{N='DataDiskName';E={
                    ($_.StorageProfile.DataDisks.Name ) -join " "
                }
            }, 
            @{N='DataDiskCaching';E={
                    ($_.StorageProfile.DataDisks.Caching ) -join " "
                }
            } 

    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) StorageAccounts" -ForegroundColor Cyan    
    $StorageAccounts += $RG | 
        get-AzStorageAccount |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
    
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) Disks" -ForegroundColor Cyan 
    $Disks += $RG |
        Get-AzDisk |
        Select-Object -Property *,
            @{N='ManagedByShortName';E={
                If($_.ManagedBy){$_.ManagedBy.tostring().substring($_.ManagedBy.tostring().lastindexof('/')+1)}
                }
            },
            @{N='SkuName';E={
                $_.Sku.Name
                }
            },
            @{N='SkuTier';E={
                $_.Sku.Tier
                }
            },
            @{N='CreationOption';E={
                $_.CreationData.CreateOption
                }
            },
            @{N='ImageReference';E={
                If($_.CreationData.ImageReference.Id){$_.CreationData.ImageReference.Id}
                }
            },
            @{N='SourceResourceId';E={
                If($_.CreationData.SourceResourceId){$_.CreationData.SourceResourceId}
                }
            },
            @{N='SourceUri';E={
                If($_.CreationData.SourceUri){$_.CreationData.SourceUri}
                }
            } |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
 
    # Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) Vnets" -ForegroundColor Cyan        
    # $Vnets +=  $RG | 
    #     Get-AzVirtualNetwork |
    #     Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
    #     Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 

    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) NetworkInterfaces" -ForegroundColor Cyan 
    $NetworkInterfaces +=  $RG |
        Get-AzNetworkInterface |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru |
        ForEach-Object { $_ | Add-Member -MemberType NoteProperty –Name PrivateIp –Value ($_.IpConfigurations[0].PrivateIpAddress) -PassThru} |
        Select-Object *,
            @{N='VNetSub';E={
                $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[2]
                }
            },
            @{N='VNetRG';E={
                $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[4]
                }
            },
            @{N='VNet';E={
                $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[8]
                }
            },
            @{N='Subnet';E={
                $_.IpConfigurations[0].Subnet.Id.tostring().split('/')[10]
                }
            },
            @{N='NSG';E={
                $_.NetworkSecurityGroup.id.tostring().substring($_.NetworkSecurityGroup.id.tostring().lastindexof('/')+1)
                }
            },
            @{N='Owner';E={
                $_.VirtualMachine.Id.tostring().substring($_.VirtualMachine.Id.tostring().lastindexof('/')+1)
                }
            },
            @{N='PrivateIPs';E={
                ($_.IpConfigurations.PrivateIpAddress) -join " "  
                }
            },
            @{N='DnsServers';E={
                ($_.DnsSettings.DnsServers) -join " "  
                }
            }

    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) MSGs" -ForegroundColor Cyan 
    $NSGs += $RG |
        Get-AzNetworkSecurityGroup         |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru |
        Select-Object *,
        @{N='SecurityRuleName';E={
                ($_.SecurityRules.Name) -join " "
                } 
         },
         @{N='DefaultSecurityRuleName';E={
                ($_.DefaultSecurityRules.Name) -join " "
                } 
         },
         @{N='NetworkInterfaceName';E={
            ($_.NetworkInterfaces.ID | ForEach-Object {$_.tostring().substring($_.tostring().lastindexof('/')+1) } ) -join " " 
            }
         }, 
         @{N='SubnetName';E={
            ( $_.Subnets.ID | ForEach-Object {$_.tostring().substring($_.tostring().lastindexof('/')+1) } ) -join " "
            } 
        }  

    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) Automation Accounts" -ForegroundColor Cyan   
    $AutoAccounts += $RG | 
        Get-AzAutomationAccount |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru #|
        #Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
        
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) LogAnalystics" -ForegroundColor Cyan   
    $LogAnalystics += $RG |
        Get-AzOperationalInsightsWorkspace |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
        
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) KeyVaults" -ForegroundColor Cyan   
    $KeyVaults += Get-AzKeyVault -ResourceGroupName ($RG).ResourceGroupName |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru

        
    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) Recovery Services Vaults" -ForegroundColor Cyan   
    $RecoveryServicesVaults += Get-AzRecoveryServicesVault -ResourceGroupName ($RG).ResourceGroupName |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Select-Object *,
            @{N='BackupAlertEmails';E={
                    $CurrentVaultName = $_.Name ;
                    $url = "https://management.usgovcloudapi.net/subscriptions/$($RG.SubscriptionId)/resourceGroups/$($RG.ResourceGroupName)/providers/Microsoft.RecoveryServices/vaults/$($CurrentVaultName)/monitoringconfigurations/notificationconfiguration?api-version=2017-07-01-preview" ;
                    $Response = Invoke-RestMethod -Method Get -Uri $url -Headers @{ "Authorization" = "Bearer " + $accessToken } ;
                    $Response.properties.additionalRecipients
                }
            }              

    #BackupItems Summary
        
        Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) Backup Items" -ForegroundColor Cyan   
        foreach ($recoveryservicesvault in (Get-AzRecoveryServicesVault -ResourceGroupName ($RG).ResourceGroupName)) {
            #write-host $recoveryservicesvault.name
            Get-AzRecoveryServicesVault -Name $recoveryservicesvault.Name | Set-AzRecoveryServicesVaultContext   

            $containers = Get-AzRecoveryServicesBackupContainer -ContainerType azurevm


            foreach ($container in $containers) {
                #write-host $container.name

                $BackupItem = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType "AzureVM"

                $BackupItem = $BackupItem |
                Add-Member -MemberType NoteProperty –Name FriendlyName –Value $Container.FriendlyName -PassThru |        
                Add-Member -MemberType NoteProperty –Name ResourceGroupName –Value $Container.ResourceGroupName -PassThru |
                Add-Member -MemberType NoteProperty –Name RecoveryServicesVault –Value $RecoveryServicesVault.Name -PassThru 
 
                $BackupItemSummary += $backupItem

            } 
        }

    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) AVSets" -ForegroundColor Cyan  
    $AVSets +=  $RG | Get-AzAvailabilitySet |
    Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
    Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru | 
    ForEach-Object {
        $AvailVMSizesF =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_F*" -and $_ -notlike "*promo*" } | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
        $AvailVMSizesD =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_D*" -and $_ -notlike "*promo*" -and $_ -notlike "*v*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
        $AvailVMSizesDv2 =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_D*" -and $_ -notlike "*promo*" -and $_ -like "*v2*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
        $AvailVMSizesDv3 =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_D*" -and $_ -notlike "*promo*" -and $_ -like "*v3*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
        $AvailVMSizesA =($_ | Select-Object -Property ResourceGroupName, @{N='AvailabilitySetName';E={$_.Name}} | Get-AzVMSize | ForEach-Object { $_.Name} | Where-Object {$_ -like "Standard_A*" -and $_ -notlike "*promo*"} | ForEach-Object {$_.Replace("Standard_","") } | Sort-Object ) -join " " ;
        $_ | Add-Member -MemberType NoteProperty –Name AvailVMSizesF –Value $AvailVMSizesF -PassThru |
        Add-Member -MemberType NoteProperty –Name AvailVMSizesD –Value $AvailVMSizesD -PassThru |
        Add-Member -MemberType NoteProperty –Name AvailVMSizesDv2 –Value $AvailVMSizesDv2 -PassThru |
        Add-Member -MemberType NoteProperty –Name AvailVMSizesDv3 –Value $AvailVMSizesDv3 -PassThru |
        Add-Member -MemberType NoteProperty –Name AvailVMSizesA –Value $AvailVMSizesA -PassThru
    }

    Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) VM Images" -ForegroundColor Cyan   
    $VMImages += Get-AzImage -ResourceGroupName ($RG).ResourceGroupName |
        Select-Object -Property *,
        @{N='Subscription';E={($RG.Subscription)}}, @{N='SubscriptionId';E={($RG.SubscriptionID)}},
        @{N='OSType';E={
            $_.StorageProfile.OsDisk.OSType
            } 
        },
        @{N='DiskSizeGB';E={
            $_.StorageProfile.OsDisk.DiskSizeGB
            } 
        },
        @{N='SourceVMShortName';E={
            $_.SourceVirtualMachine.id | Split-Path -Leaf
            } 
        }
}

# Post-Process VM Tags

Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for All Tags" -ForegroundColor Cyan  
[System.Collections.ArrayList]$Tags = @()
$UniqueTags = $VMs.Tags.Keys.ToUpper() | Select-Object -Unique | Sort-Object

foreach ($VM in $VMs) {
    $VMTagHash = [Ordered]@{
        Name = $VM.Name
        Subscription = $VM.Subscription
        ResourceGroupName = $VM.ResourceGroupName
    }
    
    foreach ($UniqueTag in $UniqueTags) {
        $TagValue = $Null
        if ($VM.Tags.Keys -contains $UniqueTag) {
            $TagName = $VM.Tags.Keys.Where{$_ -eq $UniqueTag}
            $TagValue = $VM.Tags[$TagName]
        }

        $VMTagHash.$UniqueTag = $TagValue
    }
    $VMTag = [PSCustomObject]$VMTagHash
    [Void]$Tags.Add($VMTag)
}

# Post-Process AVSet Tags

Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for All AV Set Tags " -ForegroundColor Cyan  
[System.Collections.ArrayList]$TagsAVSet = @()
$UniqueTags = $AVSets.Tags.Keys.ToUpper() | Select-Object -Unique | Sort-Object

foreach ($AVSet in $AVSets) {
    $AVSetTagHash = [Ordered]@{
        Name = $AVSet.Name
        Subscription = $AVSet.Subscription
        ResourceGroupName = $AVSet.ResourceGroupName
    }
    
    foreach ($UniqueTag in $UniqueTags) {
        $TagValue = $Null
        if ($AVSet.Tags.Keys -contains $UniqueTag) {
            $TagName = $AVSet.Tags.Keys.Where{$_ -eq $UniqueTag}
            $TagValue = $AVSet.Tags[$TagName]
        }

        $AVSetTagHash.$UniqueTag = $TagValue
    }
    $AVSetTag = [PSCustomObject]$AVSetTagHash
    [Void]$TagsAVSet.Add($AVSetTag)
}


#$TagsProps = "Subscription","ResourceGroupName","Name" 
#$TagsProps += $UniqueTags

#Get Vnets when we might not have access to the Sub and RG of the Vnet
Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Processing Info for $($RG.ResourceGroupName) Hidden Vnets and Subnets" -ForegroundColor Cyan        

If (!$Vnets ) {
    $Vnets = $NetworkInterfaces | 
        Select-Object -Unique -Property VNetSub,VNetRG,VNet | 
        Select-Object -Property @{N='Name';E={$_.VNet}},@{N='ResourceGroupName';E={$_.VNetRG}} | 
        Get-AzVirtualNetwork |
        Add-Member -MemberType NoteProperty –Name Subscription –Value $RG.Subscription -PassThru |
        Add-Member -MemberType NoteProperty –Name SubscriptionId –Value $RG.SubscriptionID -PassThru 
        
    $Subnets = $Vnets |
        ForEach-Object {
            $VNetSub = $_.Subscription
            $VNetSubID = $_.SubscriptionID
            $VNetRG = $_.ResourceGroupName
            $VNetLocation = $_.Location
            $VNetName = $_.Name
                        
            $_.Subnets |
                Select-Object *, 
                    @{N='Subscription';E={$VNetSub}},
                    @{N='SubscriptionID ';E={$VNetSubID}},
                    @{N='ResourceGroupName';E={$VNetRG}},
                    @{N='Location';E={$VNetLocation}},
                    @{N='VNet';E={$VNetName}},
                    @{N='AddressPrefixText';E={$_.AddressPrefix[0]}}
        }

}

#endregion


#region Filter and Sort Gathered Info
Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Filtering Gathered Data" -ForegroundColor Cyan  
$FilteredSubs = $Subs | Select-Object -Property Name, ID, TenantId |
Sort-Object Name

$FilteredRGs = $RGs  | Select-Object -Property ResourceGroupName,Subscription,SubscriptionId,Location |
    Sort-Object Subscription,Location,ResourceGroupName

$VMs = $VMs | 
    Select-Object -Property Name,Subscription,ResourceGroupName,Location,PowerState,OSType,LicenseType,Size,NumberOfCores,MemoryInGB,OsDiskName,OsDiskCaching,DataDiskName,DataDiskCaching,NicCount,NicCountCap,AvailabilitySet,FaultDomain,UpdateDomain |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$Tags = $Tags | Sort-Object Subscription,ResourceGroupName,Name

$StorageAccounts = $StorageAccounts  | 
    Select-Object -Property StorageAccountName,Subscription,ResourceGroupName,Location |
    Sort-Object Subscription,Location,ResourceGroupName,StorageAccountName

$Disks = $Disks | 
    Select-Object -Property Name,ManagedByShortName,Subscription,Location,ResourceGroupName,OsType,DiskSizeGB,TimeCreated,SkuName,SkuTier,CreationOption,ImageReference,SourceResourceId,SourceUri |
    Sort-Object Subscription,Location,ResourceGroupName,Name,ManagedByShortName

$Vnets =  $Vnets | 
    Select-Object -Property Subscription,Location,ResourceGroupName,Name |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$Subnets =  $Subnets | 
    Select-Object -Property Subscription,Location,ResourceGroupName,VNet,Name,AddressPrefixText |
    Sort-Object Subscription,Location,ResourceGroupName,VNet,Name

$NetworkInterfaces =  $NetworkInterfaces | 
    Select-Object -Property Subscription,Location,ResourceGroupName,Owner,Name,VNetSub,VNetRG,VNet,Subnet,Primary,NSG,MacAddress,DnsServers,PrivateIp,PrivateIPs |
    Sort-Object Subscription,Location,ResourceGroupName,Owner,Name

$NSGs = $NSGs | 
    Select-Object -Property Subscription,Location,ResourceGroupName,Name,NetworkInterfaceName,SubnetName,SecurityRuleName |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$AutoAccounts = $AutoAccounts | 
    Select-Object -Property AutomationAccountName,Subscription,ResourceGroupName,Location |
    Sort-Object Subscription,Location,ResourceGroupName,AutomationAccountName

$LogAnalystics = $LogAnalystics  | 
    Select-Object -Property Name,Subscription,ResourceGroupName,Location |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$KeyVaults = $KeyVaults | 
    Select-Object -Property VaultName,Subscription,ResourceGroupName,Location |
    Sort-Object Subscription,Location,ResourceGroupName,VaultName

$RecoveryServicesVaults = $RecoveryServicesVaults |
    Select-Object -Property Name,Subscription,ResourceGroupName,Location,BackupAlertEmails  |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$BackupItemSummary = $BackupItemSummary |
    Select-Object -Property FriendlyName,RecoveryServicesVault,ProtectionStatus,ProtectionState,LastBackupStatus,LastBackupTime,ProtectionPolicyName,LatestRecoveryPoint,ContainerName,ContainerType |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$AVsetsAll = $AVSets

$AVSets = $AVsetsAll | 
    Select-Object -Property Name,Subscription,ResourceGroupName,Location,PlatformFaultDomainCount,PlatformUpdateDomainCount |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$TagsAVSet = $TagsAVSet | Sort-Object Subscription,ResourceGroupName,Name

$AVSetSizes = $AVsetsAll | 
    Select-Object -Property Name,Subscription,ResourceGroupName,Location,AvailVMSizesA,AvailVMSizesD,AvailVMSizesDv2,AvailVMSizesDv3,AvailVMSizesF |
    Sort-Object Subscription,Location,ResourceGroupName,Name

$VMSizes = $VMSizes | 
    Select-Object -Property Name,Location,NumberOfCores,MemoryInGB |
    Sort-Object Location,Name,MemoryInGB,NumberOfCores

$VMImages = $VMImages | 
    Select-Object -Property Name,Subscription,Location,ResourceGroupName,OSType,DiskSizeGB,SourceVMShortName,Id |
    Sort-Object Subscription,Location,ResourceGroupName,Name

#endregion


#region Export, Open CSVs in C:\temp
Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Saving Data" -ForegroundColor Cyan 

$NowStr = Get-Date -Format yyyy.MM.dd_HH.mm

$mdStr = "C:\temp\$($NowStr)_RGInfo"

md $mdStr | Out-Null
 
$FilteredRGs | Export-Csv -Path "$($mdStr)\RGs.csv" -NoTypeInformation 
$VMs | Export-Csv -Path "$($mdStr)\VMs.csv" -NoTypeInformation 
$Tags | Export-Csv -Path "$($mdStr)\Tags.csv" -NoTypeInformation 
$StorageAccounts | Export-Csv -Path "$($mdStr)\StorageAccounts.csv" -NoTypeInformation
$Disks | Export-Csv -Path "$($mdStr)\Disks.csv" -NoTypeInformation
$Vnets | Export-Csv -Path "$($mdStr)\Vnets.csv" -NoTypeInformation
$Subnets | Export-Csv -Path "$($mdStr)\Subnets.csv" -NoTypeInformation
$NetworkInterfaces | Export-Csv -Path "$($mdStr)\NetworkInterfaces.csv" -NoTypeInformation
$NSGs  | Export-Csv -Path "$($mdStr)\NSGs.csv" -NoTypeInformation
$AutoAccounts | Export-Csv -Path "$($mdStr)\AutoAccounts.csv" -NoTypeInformation
$LogAnalystics | Export-Csv -Path "$($mdStr)\LogAnalystics.csv" -NoTypeInformation
$KeyVaults | Export-Csv -Path "$($mdStr)\KeyVaults.csv" -NoTypeInformation
$RecoveryServicesVaults | Export-Csv -Path "$($mdStr)\RecoveryServicesVaults.csv" -NoTypeInformation
$BackupItemSummary  | Export-Csv -Path "$($mdStr)\BackupItemSummary.csv" -NoTypeInformation
$AVSets | Export-Csv -Path "$($mdStr)\AVSets.csv" -NoTypeInformation
$TagsAVSet | Export-Csv -Path "$($mdStr)\TagsAVSet.csv" -NoTypeInformation 
$AVSetSizes | Export-Csv -Path "$($mdStr)\AVSetSizes.csv" -NoTypeInformation
$VMSizes | Export-Csv -Path "$($mdStr)\VMSizes.csv" -NoTypeInformation
$VMImages | Export-Csv -Path "$($mdStr)\VMImages.csv" -NoTypeInformation

#endregion


#region Build HTML Report, Export to C:\
Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Building HTML Report" -ForegroundColor Cyan 
$Report = @()
$HTMLmessage = ""
$HTMLMiddle = ""

Function Addh1($h1Text){
	# Create HTML Report for the current System being looped through
	$CurrentHTML = @"
	<hr noshade size=3 width="100%">
	
	<p><h1>$h1Text</p></h1>
"@
return $CurrentHTML
}

Function Addh2($h2Text){
	# Create HTML Report for the current System being looped through
	$CurrentHTML = @"
	<hr noshade size=3 width="75%">
	
	<p><h2>$h2Text</p></h2>
"@
return $CurrentHTML
}

function GenericTable ($TableInfo,$TableHeader,$TableComment ) {
$MyTableInfo = $TableInfo | ConvertTo-HTML -fragment

	# Create HTML Report for the current System being looped through
	$CurrentHTML += @"
	<h3>$TableHeader</h3>
	<p>$TableComment</p>
	<table class="normal">$MyTableInfo</table>	
"@

return $CurrentHTML
}

function VMs($VMs){

$MyTableInfo = $VMs | ConvertTo-HTML -fragment

	# Create HTML Report for the current System being looped through
	$CurrentHTML += @"
	<h3>VMs:</h3>
	<p>Detailed Azure VM Info</p>
	<table class="normal">$MyTableInfo</table>	
"@

return $CurrentHTML
}

$HTMLMiddle += AddH1 "Azure Resource Information Summary Report"
$HTMLMiddle += GenericTable $FilteredSubs "Subscriptions" "Detailed Subscription Info"
$HTMLMiddle += GenericTable $FilteredRGs "Resource Groups" "Detailed Resource Group Info"
$HTMLMiddle += VMs $VMs
$HTMLMiddle += GenericTable $Tags "Tags" "Detailed Tag Info"
$HTMLMiddle += GenericTable $StorageAccounts "Storage Accounts" "Detailed Disk Info"
$HTMLMiddle += GenericTable $Disks  "Disks" "Detailed Disk Info"
$HTMLMiddle += GenericTable $Vnets "VNet" "Detailed VNet Info"
$HTMLMiddle += GenericTable $NetworkInterfaces "Network Interfaces" "Detailed Network Interface Info"
$HTMLMiddle += GenericTable $NSGs "Network Security Groups" "Detailed Network Security Groups Info"
$HTMLMiddle += GenericTable $AutoAccounts  "Automation Accounts" "Detailed Automation Account Info"
$HTMLMiddle += GenericTable $LogAnalystics  "Log Analystics" "Detailed LogAnalystics Info"
$HTMLMiddle += GenericTable $KeyVaults "Key Vaults" "Detailed Key Vault Info"
$HTMLMiddle += GenericTable $RecoveryServicesVaults "Recovery Services Vaults" "Detailed Vault Info"
$HTMLMiddle += GenericTable $BackupItemSummary "Backup Item Summary" "Detailed Backup Item Summary Info"
$HTMLMiddle += GenericTable $AVSets "Availability Sets Info" "Detailed AVSet Info"
$HTMLMiddle += GenericTable $TagsAVSet "Availability Set Tags" "Availability Sets Tag Info"
$HTMLMiddle += GenericTable $AVSetSizes "Availability Sets Available VM Sizes" "AVSet Available VM Sizes"
$HTMLMiddle += GenericTable $VMSizes "VM Sizes by Location" "Detailed VM Sizes by Location"
$HTMLMiddle += GenericTable $VMIMages "VM Images Info" "Detailed VM Image Info"

# Assemble the HTML Header and CSS for our Report
$HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>Azure Report</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

    #report { width: 835px; }

    table{
	border-collapse: collapse;
	border: none;
	font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
	color: black;
	margin-bottom: 10px;
}

    table td{
	font-size: 12px;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

    table th {
	font-size: 12px;
	font-weight: bold;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

h2{ clear: both; font-size: 130%; }

h3{
	clear: both;
	font-size: 115%;
	margin-left: 20px;
	margin-top: 30px;
}

p{ margin-left: 20px; font-size: 12px; }

table.list{ float: left; }

    table.list td:nth-child(1){
	font-weight: bold;
	border-right: 1px grey solid;
	text-align: right;
}

table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px  grey solid; }
div.second{ margin-left: 30px; }
table{ margin-left: 20px; }
-->
</style>
</head>
<body>

"@

# Assemble the closing HTML for our report.
$HTMLEnd = @"
</div>
</body>
</html>
"@

# Assemble the final report from all our HTML sections

$HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
# Save the report out to a file in the current path
$HTMLmessage | Out-File -Force ("$($mdStr)\RGInfo.html")
# Email our report out
# send-mailmessage -from $fromemail -to $users -subject "Systems Report" -Attachments $ListOfAttachments -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer $server



#endregion


#region Zip Results
Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Creating Archive ""$($mdStr).zip""" -ForegroundColor Cyan
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($mdStr, "$($mdStr).zip") | Out-Null

#endregion


#region Capture Time
Write-Host "$(Get-Date -Format yyyy.MM.dd_HH.mm.fff) Done! Total Elapsed Time: $($elapsed.Elapsed.ToString())" -ForegroundColor Cyan 
$elapsed.Stop()
#endregion


#region Open CSVs/Results in Explorer and Gridview

# ii "$mdStr"
# (Get-ChildItem $mdStr).FullName | Out-GridView -OutputMode Multiple -Title "Choose Files to Open" | ForEach-Object {Import-Csv $_ | Out-GridView -Title $_}

#endregion


