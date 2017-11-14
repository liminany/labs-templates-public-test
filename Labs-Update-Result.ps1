  Param(
  [string]$azureAccountName,
  [string]$azurePasswordString,
  [string]$subscriptionID,
  [string]$azureRMGroupName
  )


  $PayLoad="resource=https://management.core.windows.net/&client_id=1950a258-227b-4e31-a9cf-717495945fc2&grant_type=password&username="+$azureAccountName+"&scope=openid&password="+$azurePasswordString
  $Response=Invoke-WebRequest -Uri "https://login.microsoftonline.com/Common/oauth2/token" -Method POST -Body $PayLoad
  $ResponseJSON=$Response|ConvertFrom-Json

  $requestHeader = @{
  "x-ms-version" = "2014-10-01"; #'2014-10-01'
  "Authorization" = " Bearer " + $ResponseJSON.access_token
  }


  #List all vms in specific azure resouce group

  Function GetVMList()
  {
  $Uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/virtualmachines?api-version=2016-04-30-preview" -f $subscriptionID, $azureRMGroupName
  $data = Invoke-RestMethod -Method Get -Headers $requestheader -Uri $uri
  return $data | ConvertTo-Json
  }


  Function GetVMInfo($name)
  {
  $Uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/virtualMachines/{2}?api-version=2016-04-30-preview" -f $subscriptionID, $azureRMGroupName, $name
  $data = Invoke-RestMethod -Method Get -Headers $requestheader -Uri $uri

  return $data | ConvertTo-Json
 
  }

  $vmList=GetVMList | ConvertFrom-Json;
 

  #Loop VM list
  ForEach ($i in $vmList.value) {
        
       #get vm info
       $vmInfo=GetVMInfo($i.name) | ConvertFrom-Json;
       echo $vmInfo | ConvertTo-Json

       #create custom object and convert to json
       $env = New-Object –TypeName PSObject
       $env | Add-Member -MemberType NoteProperty -Name displayname -Value $i.Name
       $env | Add-Member -MemberType NoteProperty -Name protocol -Value ""
       $env | Add-Member -MemberType NoteProperty -Name hostname -Value ""
       $env | Add-Member -MemberType NoteProperty -Name username -Value $vmInfo.properties.osProfile.adminUsername
       $env | Add-Member -MemberType NoteProperty -Name password -Value $vmInfo.properties.osProfile.adminPassword
       $env | Add-Member -MemberType NoteProperty -Name private-key -Value ""
       $env | Add-Member -MemberType NoteProperty -Name port -Value ""
       $env | Add-Member -MemberType NoteProperty -Name external -Value true
       #echo $env | ConvertTo-Json

  }
