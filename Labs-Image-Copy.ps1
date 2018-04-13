Param(
    [string] [Parameter(Mandatory=$true)] $azureAccountName,
    [string] [Parameter(Mandatory=$true)] $azurePasswordString,

    [string] [Parameter(Mandatory=$false)] $uniqueSeed, # maybe a buildid
    [string] [Parameter(Mandatory=$false)] $resourceGroupName = "tfs-labs-image-copy",   
    [string] [Parameter(Mandatory=$false)] $storageAccountName = "tfslabsimagecopy", # 3 and 24 characters in length and use numbers and lower-case letters
    [string] [Parameter(Mandatory=$false)] $storageAccountContainer = "vhds", # 3 and 24 characters in length and use numbers and lower-case letters 

    [string] [Parameter(Mandatory=$true)] $sourceVhdUrl,
    [string] $targetVhdName = ([guid]::NewGuid()).ToString()+".vhd", 
    [string] $azEnvName = "AzureChinaCloud", # global(AzureCloud) or china(AzureChinaCloud)  Get-AzureRmEnvironment | Select-Object Name
    [string] $azEnvLocation = "chinanorth"

    

    # powershell build task args(Mandatory):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed $(Build.BuildId) -sourceVhdUrl "$(sourceVhdUrl-tfs2018-Snapshot-0329)"

    # powershell build task args(multi vhd copy to a resource group/storage account):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed "" -sourceVhdUrl "$(sourceVhdUrl-tfs2018-Snapshot-0329)" -resourceGroupName $(resourceGroupName) -storageAccountName $storageAccountName -storageAccountContainer $(storageAccountContainer)

    # powershell build task args(Mandatory)£¬and copy to global(AzureCloud):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed $(Build.BuildId) -sourceVhdUrl "$(sourceVhdUrl-tfs2018-Snapshot-0329)" -azEnvName  $(azEnvName) -azEnvLocation $(azEnvLocation) 
)

$resourceGroupName = $resourceGroupName+$uniqueSeed
$storageAccountName = $storageAccountName+$uniqueSeed
$storageAccountContainer = $storageAccountContainer+$uniqueSeed

$azurePassword = ConvertTo-SecureString $azurePasswordString -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)

Login-AzureRmAccount -Credential $psCred -EnvironmentName $azEnvName #AzureChinaCloud

$findRSName = (Find-AzureRmResourceGroup | where {$_.name -EQ $resourceGroupName}).name

if($resourceGroupName -ne $findRSName){
    "resource group $resourceGroupName not exists,create new "
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $azEnvLocation
}

$accountAvailable = Get-AzureRmStorageAccountNameAvailability -Name $storageAccountName
"resourceGroupName is $resourceGroupName, storageAccountName is $storageAccountName, accountAvailable is: "
 $accountAvailable 

if($accountAvailable.NameAvailable) {
    #throw "storageAccountName£º $storageAccountName not Exists £¡" 
    "$storageAccountName not Exists £¬create new storage account"
    New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -Location $azEnvLocation -Type "Standard_LRS"  
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
    New-AzureStorageContainer -Name $storageAccountContainer      
}
elseif($accountAvailable.Reason -eq "AlreadyExists") {
    
}
else {
    throw "Reason:" + $accountAvailable.Reason +","+ $accountAvailable.Message
}

$destStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName;

"start copy image"
#$copyBlob = Start-AzureStorageBlobCopy -AbsoluteUri $sourceVhdUrl -DestContainer $storageAccountContainer -DestContext $destStorageAccount.Context -DestBlob $targetVhdName;
#$copyBlob
"wait copy complete(maybe need 5 Minutes ~60 Minutes)..."
#$copyBlob | Get-AzureStorageBlobCopyState -Blob $targetVhdName -Container $storageAccountContainer  -WaitForComplete

"copy complate!"
#Get-AzureStorageBlob -Container $storageAccountContainer | Stop-AzureStorageBlobCopy -Force
