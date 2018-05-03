Param(

    [string] [Parameter(Mandatory=$true)]  $sourceAzureAccountName,
    [string] [Parameter(Mandatory=$true)] $sourceAzurePasswordString,
    [string] [Parameter(Mandatory=$true)] $sourceSubscriptionId, #72c9703f-60d5-47aa-b7a7-ec0fc7ce1a43 ls-mc-test-env

    [string] [Parameter(Mandatory=$false)] $sourceSnapshotName = "",# format" name-type(Windows OR Linux)-ver-date£¨ tfs2018Snap-Windows-v1.5-20170418 tfs2018AgentSnap-Linux-v1.5-20170418
    [string] [Parameter(Mandatory=$false)] $sourceVhdUrl,# $sourceSnapshotName or $sourceVhdUrl must pass one ls112-tfs-server-2018-tfs2018-windows-snapshot-20180423.2

    [string] [Parameter(Mandatory=$false)] $sourceStorageAccountName, # 3 and 24 characters in length and use numbers and lower-case letters
    [string] [Parameter(Mandatory=$false)] $sourceAzEnvName = "AzureChinaCloud", # global(AzureCloud) or china(AzureChinaCloud)  Get-AzureRmEnvironment | Select-Object Name
    #[string] $sourceAzEnvLocation = "chinanorth",  
          
    [string] [Parameter(Mandatory=$true)] $destSubscriptionId, #"9b26957f-5a38-47aa-a0fa-cd97f1dfdb12", #Windows Azure ∆Û“µ
    [string] [Parameter(Mandatory=$true)] $destAzureAccountName,
    [string] [Parameter(Mandatory=$true)] $destAzurePasswordString,

    [string] [Parameter(Mandatory=$false)] $destStorageAccountName, # 3 and 24 characters in length and use numbers and lower-case letters
    [string] [Parameter(Mandatory=$false)] $destAzEnvName = "AzureChinaCloud", # global(AzureCloud) or china(AzureChinaCloud)  Get-AzureRmEnvironment | Select-Object Name
    [string] [Parameter(Mandatory=$false)] $destVhdName = "vhd",# =sourceSnapshotName
    [string] [Parameter(Mandatory=$false)] $destAzEnvLocation = "chinanorth", 

    [string] [Parameter(Mandatory=$false)] $uniqueSeed, # maybe a buildid
    [string] [Parameter(Mandatory=$true)] $resourceGroupName, 
    [string] [Parameter(Mandatory=$false)] $destResourceGroupName, 
    [string] [Parameter(Mandatory=$false)] $storageAccountContainer = "vhds" # 3 and 24 characters in length and use numbers and lower-case letters    
 )

if($sourceSnapshotName -eq $null -and $sourceVhdUrl -eq $null){
    throw "Params:sourceSnapshotName/sourceVhdUrl must pass one."
}

# login source sourceSubscriptionId
$azurePassword = ConvertTo-SecureString $sourceAzurePasswordString -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($sourceAzureAccountName, $azurePassword)
Login-AzureRmAccount -Credential $psCred -EnvironmentName $sourceAzEnvName #AzureChinaCloud

if($sourceSubscriptionId -ne $null){
    "Select source Subscription: $sourceSubscriptionId"
    Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId   
}

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
    "snapSasUrl: $sourceVhdUrl"
    $destVhdName = $sourceSnapshotName + (Get-Date -Format fff) + ".vhd" 
}
else {    
     $destVhdName =  $destVhdName + (Get-Date -Format fff) + ".vhd" 
    "vhd Name is: $destVhdName"
}

#same Subscription
if($sourceSubscriptionId -eq $destinationSubscriptionId){
    # Different Azure account
    if($sourceAzureAccountName -ne $destAzureAccountName){
        # login dest Subscription
        $azurePassword = ConvertTo-SecureString $destAzurePasswordString -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($destAzureAccountName, $azurePassword)
        Login-AzureRmAccount -Credential $psCred -EnvironmentName $destAzEnvName #AzureChinaCloud           
    }   
}
else {
     "login dest Subscription: $destSubscriptionId"
     if($sourceAzureAccountName -ne $destAzureAccountName){
        # login dest Subscription
        $azurePassword = ConvertTo-SecureString $destAzurePasswordString -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($destAzureAccountName, $azurePassword)
        Login-AzureRmAccount -Credential $psCred -EnvironmentName $destAzEnvName #AzureChinaCloud           
    }
    if($destSubscriptionId -ne $null){
        "Select dest Subscription: $destSubscriptionId"
        Select-AzureRmSubscription -SubscriptionId $destSubscriptionId   
    }
}

 # for new resource Group unique
if($destResourceGroupName -eq $null -or $destResourceGroupName -eq "") {
    if($uniqueSeed -eq $null) {
        $uniqueSeed=""
    }
    $destResourceGroupName = $resourceGroupName+$uniqueSeed
    "destResourceGroupName:$destResourceGroupName"
}


# find source resourceGroupName
$findRSName = (Find-AzureRmResourceGroup | where {$_.name -EQ $destResourceGroupName}).name

if($destResourceGroupName -ne $findRSName){
    # create targetResourceGroupName
    "resource group $destResourceGroupName not exists,create new "
    New-AzureRmResourceGroup -Name $destResourceGroupName -Location $destAzEnvLocation
}

$accountAvailable = Get-AzureRmStorageAccountNameAvailability -Name $destStorageAccountName
"resourceGroupName is $destResourceGroupName, storageAccountName is $destStorageAccountName, accountAvailable is: "
$accountAvailable 

if($accountAvailable.NameAvailable) {
    #create targetStorageAccount " 
    "$destStorageAccountName not Exists £¨create new storage account"
    New-AzureRmStorageAccount -ResourceGroupName $destResourceGroupName -AccountName $destStorageAccountName -Location $destAzEnvLocation -Type "Standard_LRS"  
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

# get destStorageAccount $destStorageAccountName="labstemplatestorageprod" ; $destSubscriptionId="9c147847-d93d-4174-9fd8-1c04057acf82"; $storageAccountContainer="vhds"
$destStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $destResourceGroupName -Name $destStorageAccountName;


"start copy image"
$copyBlob = Start-AzureStorageBlobCopy -AbsoluteUri $sourceVhdUrl -DestContainer $storageAccountContainer -DestContext $destStorageAccount.Context -DestBlob $destVhdName;
$copyBlob
"wait copy complete(maybe need 5 Minutes ~60 Minutes)..."
$copyBlob | Get-AzureStorageBlobCopyState -Blob $destVhdName -Container $storageAccountContainer  -WaitForComplete
"copy complate!"

# stop copy
#Get-AzureStorageBlob -Container $storageAccountContainer | Stop-AzureStorageBlobCopy -Force

# create new vm image from vhd file
#todo get image type from $destVhdName Windows
if($destVhdName.ToLower().IndexOf("windows") -ge 0){
    $osType = "Windows";
}
elseif($destVhdName.ToLower().IndexOf("linux") -ge 0){
    $osType = "Linux";
}
else {
    "the destVhdName value: $destVhdName must Contain a osType(Windows or Linux)°£refer sourceSnapshotName(value is:$sourceSnapshotName) format:ls112-tfs-server-2018-tfs2018-windows-snapshot-20180423.1"
}

$osVhdUri = "$($container.CloudBlobContainer.Uri.AbsoluteUri)/$destVhdName"
"osVhdUri is: $osVhdUri"
$imageConfig = New-AzureRmImageConfig -Location $destAzEnvLocation
Set-AzureRmImageOsDisk -Image $imageConfig -OsType $osType -OsState Generalized -BlobUri $osVhdUri

$imageName = $destVhdName.Replace(".vhd","").Replace("snapshot","image")
$image = New-AzureRmImage -ImageName $imageName -ResourceGroupName $destResourceGroupName -Image $imageConfig
$image
"create new vm image completed"

"start replece output result.json"
 #replace all output string
$needReplaceVars = "#imageName#","#imageId#"
$resultTemplateFilePath=$env:BUILD_SOURCESDIRECTORY + '\000-image-sync\labs-result-template.json'
echo $resultTemplateFilePath
$resultJsonContent = Get-Content $resultTemplateFilePath | Out-String 
$resultJsonContent=$resultJsonContent.Replace($needReplaceVars[0], $imageName);
$resultJsonContent=$resultJsonContent.Replace($needReplaceVars[1], $image.Id);

out-File -FilePath $resultTemplateFilePath -InputObject $resultJsonContent
echo $resultJsonContent
