Param(
    [string] [Parameter(Mandatory=$true)] $azureAccountName,
    [string] [Parameter(Mandatory=$true)] $azurePasswordString,

    [int] [Parameter(Mandatory=$true)] $uniqueSeed, # maybe a buildid
    [string] [Parameter(Mandatory=$false)] $resourceGroupName = "tfs-labs-image-copy",   
    [string] [Parameter(Mandatory=$false)] $storageAccountName = "tfslabsimagecopy", # 3 and 24 characters in length and use numbers and lower-case letters
    [string] [Parameter(Mandatory=$false)] $storageAccountContainer = "vhds", # 3 and 24 characters in length and use numbers and lower-case letters

    [string] [Parameter(Mandatory=$true)] $sourceVhdUrl,
    [string] $targetVhdName = ([guid]::NewGuid()).ToString()+".vhd",
    [string] $azEnvName = "AzureChinaCloud", # Global or china  
    [string] $azEnvLocation = "chinanorth"  
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
    New-AzureRmResourceGroup -Name $resourceGroupName -Location "chinanorth"    
}

$accountAvailable = Get-AzureRmStorageAccountNameAvailability -Name $storageAccountName

if($accountAvailable.NameAvailable) {
    #throw "storageAccountName£º $storageAccountName not Exists £¡" 
    "$storageAccountName not Exists £¬create new storage account"
    New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -Location $azEnvLocation -Type "Standard_LRS"  
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
    New-AzureStorageContainer -Name $storageAccountContainer

    $destStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName;
    "start copy image"
    $copyBlob = Start-AzureStorageBlobCopy -AbsoluteUri $sourceVhdUrl -DestContainer $storageAccountContainer -DestContext $destStorageAccount.Context -DestBlob $targetVhdName;
    $copyBlob
    "wait copy complete..."
    $copyBlob | Get-AzureStorageBlobCopyState -Blob $targetVhdName -Container $storageAccountContainer  -WaitForComplete
    
    "copy complate!"
    #Get-AzureStorageBlob -Container $storageAccountContainer | Stop-AzureStorageBlobCopy -Force
}
else {
    throw $accountAvailable.Message
}




#$azureAccountName="leansoft@sxmcv.partner.onmschina.cn"
#$azurePasswordString="Yjcr123456"

#$resourceGroupName = "tfs-labs-image-copy2"
#$storageAccountName = "tfslabsimagecopy2"  # 3 and 24 characters in length and use numbers and lower-case letters
#$storageAccountContainer = "vhds" # 3 and 24 characters in length and use numbers and lower-case letters

#$sourceVhdUrl = "https://md-nqpgq1vdftkd.blob.core.chinacloudapi.cn/pvbh014drqs1/abcd?sv=2017-04-17&sr=b&si=087b5e94-032b-449e-957d-e3df309cb735&sig=NKyIPus%2FGWny%2FKYBdQ8%2Bu77ZyFuIaxaIsCMC5Eenkh8%3D"
#$targetVhdName = ([guid]::NewGuid()).ToString()+".vhd"

# Get-AzureRmStorageAccount | select StorageAccountName,ResourceGroupName, Location, Kind,Sku, @{Name="Type"; Expression={$_.Sku.Tier}} | ft
# StorageAccountName  ResourceGroupName  Location      Kind     Type
# ------------------  -----------------  --------      ----     ----
# tfslabs             tfs-labs-genorator chinanorth Storage Standard
# tfslabtest01diag246 tfs-lab-test-01    chinanorth Storage Standard
# LabsImagesStorage LabsImages
