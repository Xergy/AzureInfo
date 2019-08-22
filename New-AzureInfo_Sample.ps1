<#
    .SYNOPSIS
        Gathers selected cross subscription Azure configuration details by resource group, and outputs to csv, html, and zip

    .NOTES
        AzureInfo allows a user to pick specific Subs/RGs in out-gridview 
        and export info to CSV and html report.

        It is designed to be easily edited to for any specific purpose.

        It writes temp data to a folder of your choice i.e. C:\temp. It also zips up the final results.
#>

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

#region Build Config File
#$Subs = Get-AzSubscription | Out-GridView -OutputMode Multiple -Title "Select Subscriptions"
$Subs = Get-AzSubscription | where-object {$_.Name -eq "Azure Government Internal"}
$RGs = @()

foreach ( $Sub in $Subs )
{

    Set-AzContext -SubscriptionId $Sub.SubscriptionId | Out-Null
    
    $SubRGs = Get-AzResourceGroup |  
        Select-Object *,
            @{N='Subscription';E={
                    $Sub.Name
                }
            },
            @{N='SubscriptionId';E={
                    $Sub.Id
                }
            } |        
        Where-Object {$_.ResourceGroupName -eq "F5-RG"}
            #Out-GridView -OutputMode Multiple -Title "Select Resource Groups"

    foreach ( $SubRG in $SubRGs )
    {

    $RGs = $RGS + $SubRg

    }
}

#endregion

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Running Get-AzureInfo..."

$Params = @{
    Subscription = $Subs
    ResourceGroup = $RGs
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

Write-Output "$(Get-Date -Format yyyy-MM-ddTHH.mm.fff) Done!"
        