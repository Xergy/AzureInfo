
#Join Detailed VM Data

$Nics = $AzureInfoResults.Results.NetworkInterfaces
$NicsPrimary = $AzureInfoResults.Results.NetworkInterfaces | Where-Object {$_.Primary -eq "TRUE"}
$VMTagRightProps = "IAM_ENVIRONMENT","IAM_PLATFORM","IAM_SUBCOMPONENT","IAM_FUNCTION"
$VMTagAllProps = "Subscription","ResourceGroupName","Name" + $VMTagRightProps

$VMTags_Vital = $AzureInfoResults.Results.VMTags | Select-Object -Property $VMTagAllProps
$VMsPlusTags = Join-Object -Left $AzureInfoResults.Results.VMs -Right $VMTags_Vital -Where {$args[0].Name -eq $args[1].Name -and $args[0].ResourceGroupName -eq $args[1].ResourceGroupName } -LeftProperties * -RightProperties $VMTagRightProps -Type AllInLeft
$VMsAllTagsIPs = Join-Object -Left $VMsPlusTags -Right $Nics -Where {$args[0].Name -eq $args[1].Owner -and $args[0].ResourceGroupName -eq $args[1].ResourceGroupName } -LeftProperties * -RightProperties "PrivateIp" -Type AllInLeft
$VMDetails = 
    $VMsAllTagsIPs
   
# $VMDetails | ogv     

#VMs missing Vital Tags

$VM_MissingTagENVIRONMENT = $VMDetails | Where-Object {$_.IAM_ENVIRONMENT -like ""}

$VM_MissingTagPLATFORM = $VMDetails | Where-Object {$_.IAM_PLATFORM -like ""}

$VM_MissingTagSUBCOMPONENT = $VMDetails | Where-Object {$_.IAM_SUBCOMPONENT -like ""}

$VM_MissingTagFUNCTION  = $VMDetails | Where-Object {$_.IAM_FUNCTION -like ""}

#Windows VMs without HUB
$VM_MissingHub = $VMDetails | Where-Object {$_.OsType -eq "Windows" -and $_.LicenseType -notlike "Windows_Server" } 


# Nics Set to Inherit from Subnet
# $Nics | ogv

$Nics_NoDNSInherit = $Nics | Where-Object {$_.DNSServers -like ""}

#Orphan Resources

$Nics_Orphan = $Nics | Where-Object {$_.Owner -like ""}

$Disk_Orphan = $AzureInfoResults.Results.Disks | Where-Object {$_.ManagedByShortName -eq $Null} | Measure-Object
# $AzureInfoResults.Results.Disks | Ogv

$NSGs_Orphan = $AzureInfoResults.Results.NSGs | Where-Object {$_.NetworkInterfaceName -eq $Null -and $_.SubnetName -eq $Null }

#Backup Issues
$BackupItemSummary = $AzureInfoResults.Results.BackupItemSummary

$Backup_UnWell = $BackupItemSummary | Where-Object {$_.ProtectionStatus -ne "Healthy" -or $_.ProtectionState -ne "Protected" -or $_.LastBackupStatus -ne "Completed" }



