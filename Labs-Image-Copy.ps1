Param(
    [string] [Parameter(Mandatory=$true)] $azureAccountName,
    [string] [Parameter(Mandatory=$true)] $azurePasswordString,

    [string] [Parameter(Mandatory=$false)] $uniqueSeed, # maybe a buildid
    [string] [Parameter(Mandatory=$false)] $resourceGroupName = "tfs-labs-image-copy",   
    [string] [Parameter(Mandatory=$false)] $storageAccountName = "tfslabsimagecopy", # 3 and 24 characters in length and use numbers and lower-case letters
    [string] [Parameter(Mandatory=$false)] $storageAccountContainer = "vhds", # 3 and 24 characters in length and use numbers and lower-case letters 

    [string] [Parameter(Mandatory=$true)] $sourceVhdUrl,
    [string] $targetVhdName = "vhd", #([guid]::NewGuid()).ToString()+".vhd", 
    [string] $azEnvName = "AzureChinaCloud", # global(AzureCloud) or china(AzureChinaCloud)  Get-AzureRmEnvironment | Select-Object Name
    [string] $azEnvLocation = "chinanorth" 

    # powershell build task args(Mandatory):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed $(Build.BuildId) -sourceVhdUrl "$(sourceVhdUrl-tfs2018-ag-linux-snapshot)"

    # powershell build task args(multi vhd copy to a resource group/storage account):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed "" -sourceVhdUrl "$(sourceVhdUrl-tfs2018-ag-linux-snapshot)" -resourceGroupName $(resourceGroupName) -storageAccountName $storageAccountName -storageAccountContainer $(storageAccountContainer)

    # powershell build task args(Mandatory)��and copy to global(AzureCloud):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed $(Build.BuildId) -sourceVhdUrl "$(sourceVhdUrl-tfs2018-ag-linux-snapshot)" -azEnvName  $(azEnvName) -azEnvLocation $(azEnvLocation) -targetVhdName $(targetVhdName)
)

$resourceGroupName = $resourceGroupName+$uniqueSeed
$storageAccountName = $storageAccountName+$uniqueSeed
$storageAccountContainer = $storageAccountContainer+$uniqueSeed

$azurePassword = ConvertTo-SecureString $azurePasswordString -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)

$targetVhdName =  $targetVhdName + (Get-Date -Format fff) + ".vhd"   

"vhd Name is: $targetVhdName"

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
    #throw "storageAccountName�� $storageAccountName not Exists ��" 
    "$storageAccountName not Exists ��create new storage account"
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
$copyBlob = Start-AzureStorageBlobCopy -AbsoluteUri $sourceVhdUrl -DestContainer $storageAccountContainer -DestContext $destStorageAccount.Context -DestBlob $targetVhdName;
$copyBlob
"wait copy complete(maybe need 5 Minutes ~60 Minutes)..."
$copyBlob | Get-AzureStorageBlobCopyState -Blob $targetVhdName -Container $storageAccountContainer  -WaitForComplete

"copy complate!"
#Get-AzureStorageBlob -Container $storageAccountContainer | Stop-AzureStorageBlobCopy -Force

#$vmName = "tfs2018"
#$rgName = "tfs2018"
#$location = "ChinaNorth"
#$imageName = "tfs2018"
#$osVhdUri = "https://imagestorage3.blob.core.chinacloudapi.cn/vhds/tfs20183.vhd"

#$imageConfig = New-AzureRmImageConfig -Location $location
#$imageConfig = Set-AzureRmImageOsDisk -Image $imageConfig -OsType Windows -OsState Generalized -BlobUri $osVhdUri
#$image = New-AzureRmImage -ImageName $imageName -ResourceGroupName $rgName -Image $imageConfig
