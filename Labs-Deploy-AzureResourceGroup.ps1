Param(
    [string]$azureAccountName,
    [string]$azurePasswordString,
    [string]$subscriptionID,
    [int]$buildId,
    [string] [Parameter(Mandatory=$true)] $ArtifactStagingDirectory,
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName,
    [switch] $UploadArtifacts,
    [string] $StorageAccountName,
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant(),
    [string] $TemplateFile = $ArtifactStagingDirectory + '\labs\labs-azuredeploy.json',
    [string] $TemplateParametersFile = $ArtifactStagingDirectory + '.\labs\labs-azuredeploy.parameters.json',
    [string] $TemplateFile2 = $ArtifactStagingDirectory + '\labs\labs-azuredeploy2.json',
    [string] $TemplateParametersFile2 = $ArtifactStagingDirectory + '.\labs\labs-azuredeploy2.parameters.json',
    [string] $TemplateFile3 = $ArtifactStagingDirectory + '\labs\labs-azuredeploy3.json',
    [string] $TemplateParametersFile3 = $ArtifactStagingDirectory + '.\labs\labs-azuredeploy3.parameters.json',
   
    [string] $DSCSourceFolder = $ArtifactStagingDirectory + '.\DSC',
    [switch] $ValidateOnly,
    [string] $DebugOptions = "None",
    [switch] $Dev,
    [string] $EnvironmentName

)

$azurePassword = ConvertTo-SecureString $azurePasswordString -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)

if ($EnvironmentName -eq 'china') {
    Login-AzureRmAccount -EnvironmentName AzureChinaCloud -Credential $psCred
}
else{
    Login-AzureRmAccount -Credential $psCred
}

Set-AzureRmContext -SubscriptionID $subscriptionID

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "AzureRMSamples")
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateArgs = New-Object -TypeName Hashtable
$TemplateArgs2 = New-Object -TypeName Hashtable
$TemplateArgs3 = New-Object -TypeName Hashtable


if ($Dev) {
    $TemplateParametersFile = $TemplateParametersFile.Replace('azuredeploy.parameters.json', 'azuredeploy.parameters.dev.json')
    if (!(Test-Path $TemplateParametersFile)) {
        $TemplateParametersFile = $TemplateParametersFile.Replace('azuredeploy.parameters.dev.json', 'azuredeploy.parameters.1.json')
    }
}

if (!$ValidateOnly) {
    $OptionalParameters.Add('DeploymentDebugLogLevel', $DebugOptions)
}

$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

$TemplateFile2 = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile2))
$TemplateParametersFile2 = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile2))

$TemplateFile3 = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile3))
$TemplateParametersFile3 = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile3))


$ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
$ScriptsFolder=$ArtifactStagingDirectory+"\labs\scripts"

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))
    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
    if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
        $JsonParameters = $JsonParameters.parameters
    }
    #$ArtifactsLocationName = '_artifactsLocation'
    #$ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
    #$OptionalParameters[$ArtifactsLocationName] = $JsonParameters | Select-Object -Expand $ArtifactsLocationName -ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore
    #$OptionalParameters[$ArtifactsLocationSasTokenName] = $JsonParameters | Select-Object -Expand $ArtifactsLocationSasTokenName -ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }

    # Create a storage account name if none was provided
    if ($StorageAccountName -eq '') {
        $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
    }

    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})

    # Create the storage account if it doesn't already exist
    if ($StorageAccount -eq $null) {
        $StorageResourceGroupName = 'ARM_Deploy_Staging'
        New-AzureRmResourceGroup -Location "$ResourceGroupLocation" -Name $StorageResourceGroupName -Force
        $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
    }


 
    if (Test-Path $ScriptsFolder) {
        # Copy files from the local storage staging location to the storage account container
        New-AzureStorageContainer -Name $StorageContainerName -Permission Container -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1
        $ArtifactFilePaths = Get-ChildItem $ScriptsFolder -Recurse -File | ForEach-Object -Process {$_.FullName}
        foreach ($SourcePath in $ArtifactFilePaths) {
        Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($ArtifactStagingDirectory.length + 1) -Container $StorageContainerName -Context $StorageAccount.Context -Force
        }
    }

   
    $TemplateArgs.Add('TemplateFile', $TemplateFile)
    $TemplateArgs2.Add('TemplateFile', $TemplateFile2)
    $TemplateArgs3.Add('TemplateFile', $TemplateFile3)




}
else {

    $TemplateArgs.Add('TemplateFile', $TemplateFile)
    $TemplateArgs2.Add('TemplateFile', $TemplateFile2)
    $TemplateArgs3.Add('TemplateFile', $TemplateFile3)

}

$TemplateArgs.Add('TemplateParameterFile', $TemplateParametersFile)
$TemplateArgs2.Add('TemplateParameterFile', $TemplateParametersFile2)
$TemplateArgs3.Add('TemplateParameterFile', $TemplateParametersFile3)


# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                                                                  @TemplateArgs `
                                                                                  @OptionalParameters)

    
    if (Test-Path $TemplateFile2) {
     $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                                                                  @TemplateArgs2 `
                                                                                  @OptionalParameters2)
    }

    if (Test-Path $TemplateFile3) {
     $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                                                                  @TemplateArgs3 `
                                                                                  @OptionalParameters3)
    }

    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }



}
else {
    $result=New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -ResourceGroupName $ResourceGroupName `
                                       @TemplateArgs `
                                       @OptionalParameters `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages
    if (Test-Path $TemplateFile2) {
          $result2=New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -ResourceGroupName $ResourceGroupName `
                                       @TemplateArgs2 `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages
    }
  
    if (Test-Path $TemplateFile3) {
          $result3=New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -ResourceGroupName $ResourceGroupName `
                                       @TemplateArgs3 `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages
    }
    #replace all output string
    $resultTemplateFilePath=$ArtifactStagingDirectory + '\labs\labs-result-template.json'
    $resultFilePath=$ArtifactStagingDirectory + '\labs\result.json'
    $outputs=$result.Outputs | ConvertTo-Json  
    echo "outputs json"
    echo $outputs
    $outputsObj=$outputs | ConvertFrom-Json
    $result = Get-Content $resultTemplateFilePath | Out-String 
    ForEach ($i in $outputsObj.psobject.properties) 
    {
       
        $replacePara="#"+$i.Name;
        $replaceValue=$i.Value.Value;
        $result=$result.Replace("$replacePara", $replaceValue);
    
    }

   if (Test-Path $TemplateFile2){
         $outputs2=$result2.Outputs | ConvertTo-Json  
          echo "outputs json"
          echo $outputs2
          $outputsObj2=$outputs2 | ConvertFrom-Json
          ForEach ($i in $outputsObj2.psobject.properties) 
          {
            
                $replacePara="#"+$i.Name;
                $replaceValue=$i.Value.Value;
                $result=$result.Replace("$replacePara", $replaceValue);
            
          }
    }

    if (Test-Path $TemplateFile3){
         $outputs3=$result3.Outputs | ConvertTo-Json  
          echo "outputs json"
          echo $outputs3
          $outputsObj3=$outputs3 | ConvertFrom-Json
          ForEach ($i in $outputsObj3.psobject.properties) 
          {
            
                $replacePara="#"+$i.Name;
                $replaceValue=$i.Value.Value;
                $result=$result.Replace("$replacePara", $replaceValue);
            
          }
    }

    
    out-File -FilePath $resultFilePath -InputObject $result
    echo $result

    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}


# Remove AzureStorageContainer
$TempStorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})

if (Test-Path $ScriptsFolder) {
    Remove-AzureStorageContainer -Name $StorageContainerName -Context $TempStorageAccount.Context -Force
}