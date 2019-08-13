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
