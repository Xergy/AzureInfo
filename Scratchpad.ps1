Copy
$resourceGroupName = "<your-resource-group-name>"
$storageAccountName = "<your-storage-account-name>"

# This command requires you to be logged into your Azure account, run Login-AzAccount if you haven't
# already logged in.
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName

# The ComputerName, or host, is <storage-account>.file.core.windows.net for Azure Public Regions.
# $storageAccount.Context.FileEndpoint is used because non-Public Azure regions, such as sovereign clouds
# or Azure Stack deployments, will have different hosts for Azure file shares (and other storage resources).
Test-NetConnection -ComputerName ([System.Uri]::new($storageAccount.Context.FileEndPoint).Host) -Port 445



$resourceGroupName = "Prod-RG"
$storageAccountName = "diagsa"
$fileShareName = "shareroot"

# These commands require you to be logged into your Azure account, run Login-AzAccount if you haven't
# already logged in.
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageAccountKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
$fileShare = Get-AzStorageShare -Context $storageAccount.Context | Where-Object { 
    $_.Name -eq $fileShareName -and $_.IsSnapshot -eq $false
}

if ($fileShare -eq $null) {
    throw [System.Exception]::new("Azure file share not found")
}

Test-NetConnection -ComputerName ([System.Uri]::new($storageAccount.Context.FileEndPoint).Host) -Port 445
52.227.72.44


Test-NetConnection -ComputerName "52.227.72.44" -Port 445
# The value given to the root parameter of the New-PSDrive cmdlet is the host address for the storage account, 
# <storage-account>.file.core.windows.net for Azure Public Regions. $fileShare.StorageUri.PrimaryUri.Host is 
# used because non-Public Azure regions, such as sovereign clouds or Azure Stack deployments, will have different 
# hosts for Azure file shares (and other storage resources).
$password = ConvertTo-SecureString -String $storageAccountKeys[0].Value -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "AZURE\$($storageAccount.StorageAccountName)", $password


New-PSDrive -Name "M" -PSProvider FileSystem -Root "\\$($fileShare.StorageUri.PrimaryUri.Host)\$($fileShare.Name)" -Credential $credential 


ping diagsa.file.core.usgovcloudapi.net

$resourceGroup = "Prod-RG"

$StorageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroup `
  -Name "diagsa" `
  -SkuName Standard_LRS `
  -Location $location `


$StorageAccountRG = "Prod-RG"
$StorageAccountName = "diagsa"
$StorageAccountContainer = "azureinfo"
$StorageAccount = (Get-AzStorageAccount -ResourceGroupName $StorageAccountRG  -Name $StorageAccountName)
$StorageAccountCtx = ($StorageAccount).Context

Get-ChildItem "$($mdStr)" | foreach-object {
    Set-AzStorageBlobContent -Context $StorageAccountCtx -Container "$StorageAccountContainer" -File $_.FullName -Blob "$($RootFolderStr)\$($ReportFolderStr)\$($_.Name)"
}

$mdStr = "$($LocalPath)\$($RootFolderStr)\$($ReportFolderStr)"

(Get-ChildItem "$($mdStr)")[0] | fl *


Get-Item "C:\GitRepos\AzureInfo\Sandbox\2019.08.12_21.59_RGInfo.zip" | Set-AzStorageBlobContent -Context $StorageAccountCtx -Container azureinfo



Get-Item "$($mdStr).zip" | 

Move-Item "$($mdStr).zip" "$($mdStr)"

get-item C:\temp\2019-08\2019-08-13T13.03_AzureInfo.zip
2019-08-13T13.03_AzureInfo.zip


$_.SourceVirtualMachine.id | Split-Path -Leaf

$MyPath = "\bob\myleaf"

$MyPath = $null

If ($MyPath) { $MyPath  | Split-Path -Leaf}




#region Export, Open CSVs in LocalPath

$NowStr = Get-Date -Format yyyy-MM-ddTHH.mm
$RootFolderStr = Get-Date -Format yyyy-MM
$ReportFolderStr = "$($NowStr)_AzureInfo"
$mdStr = "$($LocalPath)\$($RootFolderStr)\$($ReportFolderStr)"

Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Saving Data to $mdStr"

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
#$AVSets | Export-Csv -Path "$($mdStr)\AVSets.csv" -NoTypeInformation
#$TagsAVSetAll | Export-Csv -Path "$($mdStr)\TagsAVSet.csv" -NoTypeInformation 
#$AVSetSizes | Export-Csv -Path "$($mdStr)\AVSetSizes.csv" -NoTypeInformation
$VMSizes | Export-Csv -Path "$($mdStr)\VMSizes.csv" -NoTypeInformation
$VMImages | Export-Csv -Path "$($mdStr)\VMImages.csv" -NoTypeInformation

# Save the report out to a file in the current path
$HTMLmessage | Out-File -Force ("$($mdStr)\RGInfo.html")
# Email our report out
# send-mailmessage -from $fromemail -to $users -subject "Systems Report" -Attachments $ListOfAttachments -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer $server

#endregion

#region Zip Results
Write-Verbose "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Creating Archive ""$($mdStr).zip"""
Add-Type -assembly "system.io.compression.filesystem"

[io.compression.zipfile]::CreateFromDirectory($mdStr, "$($mdStr).zip") | Out-Null
Move-Item "$($mdStr).zip" "$($mdStr)"

#endregion
