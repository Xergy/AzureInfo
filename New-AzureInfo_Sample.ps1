<#
    .SYNOPSIS
        Gathers selected cross subscription Azure configuration details by resource group, and outputs to csv, html, and zip

    .NOTES
        AzureInfo allows a user to pick specific Subs/RGs in out-gridview 
        and export info to CSV and html report.

        It is designed to be easily edited to for any specific purpose.

        It writes temp data to a folder of your choice i.e. C:\temp. It also zips up the final results.
#>
[CmdletBinding()]
param (
    $ConfigLabel = "All"
)
process {


Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Starting..."

$VerbosePreference = "Continue"

$ScriptDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 
Set-Location $ScriptDir

#Reload AzureInfo Module
If (get-module AzureInfo) {Remove-Module AzureInfo}
Import-Module .\Modules\AzureInfo

#if not logged in to Azure, start login
if ($Null -eq (Get-AzContext).Account) {
Connect-AzAccount -Environment AzureUSGovernment | Out-Null}

$SubsAll = Get-AzSubscription
$RGsAll = @()

foreach ( $Sub in $SubsAll ) {

    Set-AzContext -SubscriptionId $Sub.SubscriptionId | Out-Null
  
    $SubRGs = Get-AzResourceGroup

    $RGsAll = $RGsAll + $SubRGs 

}

Switch ($ConfigLabel) {
    All {
        $Subs = $SubsAll
        $RGs = $RGsAll
    }
    Prod-RG {
        $Subs = $SubsAll | Where-Object {$_.Name -eq "Azure Government Internal"}
        $RGs = $RGsAll | Where-Object {$_.ResourceGroupName -eq "Prod-RG"}
    }
    F5-RG {
        $Subs = $SubsAll | Where-Object {$_.Name -eq "Azure Government Internal"}
        $RGs = $RGsAll | Where-Object {$_.ResourceGroupName -eq "F5-RG"}
    }
}

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Running Get-AzureInfo..."

$Params = @{
    Subscription = $Subs
    ResourceGroup = $RGs
    ConfigLabel = $ConfigLabel
}

$AzureInfoResults = Get-AzureInfo @Params

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Running Export-AzureInfo..."

$Params = @{
    AzureInfoResults = $AzureInfoResults
    LocalPath = "C:\Temp"    
}

Export-AzureInfo @Params

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Running Export-AzureInfoToBlobStorage..."

$Params = @{
    AzureInfoResults = $AzureInfoResults
    LocalPath = "C:\Temp"
    StorageAccountSubID = (Get-AzSubscription -SubscriptionName "Azure Government Internal").Id
    StorageAccountRG = "Prod-RG"        
    StorageAccountName =  "diagsa"       
    StorageAccountContainer = "azureinfo"
}

Export-AzureInfoToBlobStorage @Params 

# Post Processing...

# Create BuildSheet
$ProcessLabel = "BuildSheet"

$Nics = $AzureInfoResults.Results.NetworkInterfaces | Where-Object {$_.Primary -eq "TRUE"}
$VMTagRightProps = "IAM_ENVIRONMENT","IAM_PLATFORM","IAM_SUBCOMPONENT","IAM_FUNCTION"
$VMTagAllProps = "Subscription","ResourceGroupName","Name" + $VMTagRightProps

$VMTags_Vital = $AzureInfoResults.Results.VMTags | Select-Object -Property $VMTagAllProps
$VMsPlusTags = Join-Object -Left $AzureInfoResults.Results.VMs -Right $VMTags_Vital -Where {$args[0].Name -eq $args[1].Name -and $args[0].ResourceGroupName -eq $args[1].ResourceGroupName } -LeftProperties * -RightProperties $VMTagRightProps -Type AllInLeft
$VMsAllTagsIPs = Join-Object -Left $VMsPlusTags -Right $Nics -Where {$args[0].Name -eq $args[1].Owner -and $args[0].ResourceGroupName -eq $args[1].ResourceGroupName } -LeftProperties * -RightProperties "PrivateIp" -Type AllInLeft
$VMsAllTagsIPsFiltered = $VMsAllTagsIPs | Select-Object -Property * -ExcludeProperty LicenseType,OsDiskName,NicCountCap,OsDiskCaching,DataDiskName,DataDiskCaching

$OutfilePath = "C:\Temp\$($AzureInfoResults.RunTime)_$($ProcessLabel)_$($AzureInfoResults.ConfigLabel).csv"
$VMsAllTagsIPsFiltered | Export-Csv -Path $OutfilePath -NoTypeInformation -Force


$Params = @{
    Files = (Get-Item $OutfilePath)
    TargetBlobFolderPath = "$($AzureInfoResults.ConfigLabel)\$($AzureInfoResults.RunTime.substring(0,7))"
    StorageAccountSubID = (Get-AzSubscription -SubscriptionName "Azure Government Internal").Id
    StorageAccountRG = "Prod-RG"        
    StorageAccountName =  "diagsa"       
    StorageAccountContainer = "buildsheets"
}

Copy-FilesToBlobStorage @Params

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Done!"

} #End Process