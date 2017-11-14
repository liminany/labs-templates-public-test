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

  Function GetVMInfo()
  {
  $Uri = "https://management.azure.com/subscriptions/be7ae223-262c-4fde-bee6-3b8ed6e6e896/resourceGroups/101-acs-swarm-1560/providers/Microsoft.Compute/virtualmachines?api-version=2016-04-30-preview"
  $data = Invoke-RestMethod -Method Get -Headers $requestheader -Uri $uri
  echo $data | ConvertTo-Json
  }

  GetVMInfo
