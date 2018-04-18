Param(

    [string] [Parameter(Mandatory=$false)]  $sourceAzureAccountName = "lixiaoming@leixu.partner.onmschina.cn",
    [string] [Parameter(Mandatory=$false)]  $sourceAzurePasswordString = "LXM@2931157121",

    [string] [Parameter(Mandatory=$false)]  $destAzureAccountName = "leansoft@sxmcv.partner.onmschina.cn",
    [string] [Parameter(Mandatory=$false)]  $destAzurePasswordString= "Yjcr123456",

    [string] [Parameter(Mandatory=$false)] $sourceSubscriptionId,
    [string] [Parameter(Mandatory=$false)] $destinationSubscriptionId,
    [string] [Parameter(Mandatory=$false)] $sourceSnapshotName = "tfs2018Snap-Windows-v1.5-20170418",# format" name-type(Windows OR Linux)-ver-date£¬tfs2018-ag-linux-snapshot,tfs2018-Snapshot-0329 £º
    [string] [Parameter(Mandatory=$false)] $sourceVhdUrl,# $sourceSnapshotName or $sourceVhdUrl must pass one

    [string] [Parameter(Mandatory=$false)] $uniqueSeed, # maybe a buildid
    [string] [Parameter(Mandatory=$false)] $resourceGroupName = "tfs-labs-template-images",   

    [string] [Parameter(Mandatory=$false)] $sourceStorageAccountName = "labstemplatestorageac", # 3 and 24 characters in length and use numbers and lower-case letters
    [string] [Parameter(Mandatory=$false)] $destStorageAccountName = "labstemplatestoragesy", # 3 and 24 characters in length and use numbers and lower-case letters
    [string] [Parameter(Mandatory=$false)] $storageAccountContainer = "vhds", # 3 and 24 characters in length and use numbers and lower-case letters 
    
    [string] $destVhdName = "vhd", #([guid]::NewGuid()).ToString()+".vhd", 
    [string] $azEnvName = "AzureChinaCloud", # global(AzureCloud) or china(AzureChinaCloud)  Get-AzureRmEnvironment | Select-Object Name
    [string] $azEnvLocation = "chinanorth" 

    # powershell build task args(Mandatory):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed $(Build.BuildId) -sourceVhdUrl "$(sourceVhdUrl-tfs2018-ag-linux-snapshot)"

    # powershell build task args(multi vhd copy to a resource group/storage account):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed "" -sourceVhdUrl "$(sourceVhdUrl-tfs2018-ag-linux-snapshot)" -resourceGroupName $(resourceGroupName) -storageAccountName $storageAccountName -storageAccountContainer $(storageAccountContainer)

    # powershell build task args(Mandatory)£¬and copy to global(AzureCloud):
    # -azureAccountName $(azureAccountName)  -azurePasswordString $(azurePasswordString) -uniqueSeed $(Build.BuildId) -sourceVhdUrl "$(sourceVhdUrl-tfs2018-ag-linux-snapshot)" -azEnvName  $(azEnvName) -azEnvLocation $(azEnvLocation) -targetVhdName $(targetVhdName)
)

if($sourceSnapshotName -eq "" -and $sourceVhdUrl -eq ""){
    throw "Params:sourceSnapshotName/sourceVhdUrl must pass one."
}

# login source sourceSubscriptionId
$azurePassword = ConvertTo-SecureString $sourceAzurePasswordString -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($sourceAzureAccountName, $azurePassword)
Login-AzureRmAccount -Credential $psCred -EnvironmentName $azEnvName #AzureChinaCloud

# find source resourceGroupName
$findRSName = (Find-AzureRmResourceGroup | where {$_.name -EQ $resourceGroupName}).name

if($resourceGroupName -ne $findRSName){
    throw "snapshot resourceGroupName: $resourceGroupName not exists in sourceSubscriptionId: $sourceSubscriptionId"
}

# get snapshot,if pass a snapshot url,use this url as sourceVhdUrl
if($sourceVhdUrl -eq "") {
    $sourceSnap = Get-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $sourceSnapshotName
    $snapSasUrl = Grant-AzureRmSnapshotAccess -ResourceGroupName $resourceGroupName -SnapshotName $sourceSnapshotName -DurationInSecond 315360000 -Access Read  # 315360000s = 10 year
   
    # todo get vhd name from snap name
    $sourceVhdUrl = $snapSasUrl.AccessSAS;
    $destVhdName = $sourceSnapshotName +".vhd"
}
else {    
     $destVhdName =  $destVhdName + (Get-Date -Format fff) + ".vhd" 
    "vhd Name is: $destVhdName"
}

# login dest Subscription
$azurePassword = ConvertTo-SecureString $destAzurePasswordString -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($destAzureAccountName, $azurePassword)
Login-AzureRmAccount -Credential $psCred -EnvironmentName $azEnvName #AzureChinaCloud

if($destSubscriptionId -eq ""){
    Select-AzureRmSubscription -SubscriptionId $destSubscriptionId
}

# for new resource Group unique
$destResourceGroupName = $resourceGroupName+$uniqueSeed

# find source resourceGroupName
$findRSName = (Find-AzureRmResourceGroup | where {$_.name -EQ $destResourceGroupName}).name

if($destResourceGroupName -ne $findRSName){
    # create targetResourceGroupName
    "resource group $destResourceGroupName not exists,create new "
    New-AzureRmResourceGroup -Name $destResourceGroupName -Location $azEnvLocation
}

$accountAvailable = Get-AzureRmStorageAccountNameAvailability -Name $destStorageAccountName
"resourceGroupName is $destResourceGroupName, storageAccountName is $destStorageAccountName, accountAvailable is: "
$accountAvailable 

if($accountAvailable.NameAvailable) {
    #create targetStorageAccount " 
    "$destResourceGroupName not Exists £¬create new storage account"
    New-AzureRmStorageAccount -ResourceGroupName $destResourceGroupName -AccountName $destStorageAccountName -Location $azEnvLocation -Type "Standard_LRS"  
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $destResourceGroupName -Name $destStorageAccountName
    $container = New-AzureStorageContainer -Name $storageAccountContainer      
}
elseif($accountAvailable.Reason -eq "AlreadyExists") {
    # get container
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $destResourceGroupName -Name $destStorageAccountName
    $container = AzureStorageContainer -Name $storageAccountContainer
}
else {
    throw "Reason:" + $accountAvailable.Reason +","+ $accountAvailable.Message
}

# get destStorageAccount
$destStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $destResourceGroupName -Name $destStorageAccountName;

<#
"start copy image"
$copyBlob = Start-AzureStorageBlobCopy -AbsoluteUri $sourceVhdUrl -DestContainer $storageAccountContainer -DestContext $destStorageAccount.Context -DestBlob $destVhdName;
$copyBlob
"wait copy complete(maybe need 5 Minutes ~60 Minutes)..."
$copyBlob | Get-AzureStorageBlobCopyState -Blob $destVhdName -Container $destStorageAccountName  -WaitForComplete
"copy complate!"

# stop copy
#Get-AzureStorageBlob -Container $storageAccountContainer | Stop-AzureStorageBlobCopy -Force


##$osVhdUri = "https://imagestorage3.blob.core.chinacloudapi.cn/vhds/tfs20183.vhd" #https://tfslabsimagecopy.blob.core.chinacloudapi.cn/vhds/targetVhdName.vhd184.vhd

# create new vm image from vhd file
#todo get image type from $destVhdName

$osVhdUri = "$($container.CloudBlobContainer.Uri.AbsoluteUri)/$destVhdName"
"osVhdUri is: $osVhdUri"
$imageConfig = New-AzureRmImageConfig -Location $azEnvLocation
$imageConfig = Set-AzureRmImageOsDisk -Image $imageConfig -OsType Windows -OsState Generalized -BlobUri $osVhdUri
$image = New-AzureRmImage -ImageName $destVhdName  -ResourceGroupName $destResourceGroupName -Image $imageConfig
$image
"create new vm image completed"

#>