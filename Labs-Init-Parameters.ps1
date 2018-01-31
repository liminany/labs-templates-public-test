Param(
   [string] [Parameter(Mandatory=$true)] $ArtifactStagingDirectory,
   [int]$buildId
)


function New-SWRandomPassword {
    <#
    .Synopsis
       Generates one or more complex passwords designed to fulfill the requirements for Active Directory
    .DESCRIPTION
       Generates one or more complex passwords designed to fulfill the requirements for Active Directory
    .EXAMPLE
       New-SWRandomPassword
       C&3SX6Kn

       Will generate one password with a length between 8  and 12 chars.
    .EXAMPLE
       New-SWRandomPassword -MinPasswordLength 8 -MaxPasswordLength 12 -Count 4
       7d&5cnaB
       !Bh776T"Fw
       9"C"RxKcY
       %mtM7#9LQ9h

       Will generate four passwords, each with a length of between 8 and 12 chars.
    .EXAMPLE
       New-SWRandomPassword -InputStrings abc, ABC, 123 -PasswordLength 4
       3ABa

       Generates a password with a length of 4 containing atleast one char from each InputString
    .EXAMPLE
       New-SWRandomPassword -InputStrings abc, ABC, 123 -PasswordLength 4 -FirstChar abcdefghijkmnpqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ
       3ABa

       Generates a password with a length of 4 containing atleast one char from each InputString that will start with a letter from 
       the string specified with the parameter FirstChar
    .OUTPUTS
       [String]
    .NOTES
       Written by Simon Wåhlin, blog.simonw.se
       I take no responsibility for any issues caused by this script.
    .FUNCTIONALITY
       Generates random passwords
    .LINK
       http://blog.simonw.se/powershell-generating-random-password-for-active-directory/
   
    #>
    [CmdletBinding(DefaultParameterSetName='FixedLength',ConfirmImpact='None')]
    [OutputType([String])]
    Param
    (
        # Specifies minimum password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='RandomLength')]
        [ValidateScript({$_ -gt 0})]
        [Alias('Min')] 
        [int]$MinPasswordLength = 8,
        
        # Specifies maximum password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='RandomLength')]
        [ValidateScript({
                if($_ -ge $MinPasswordLength){$true}
                else{Throw 'Max value cannot be lesser than min value.'}})]
        [Alias('Max')]
        [int]$MaxPasswordLength = 12,

        # Specifies a fixed password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='FixedLength')]
        [ValidateRange(1,2147483647)]
        [int]$PasswordLength = 8,
        
        # Specifies an array of strings containing charactergroups from which the password will be generated.
        # At least one char from each group (string) will be used.
        [String[]]$InputStrings = @('abcdefghijkmnpqrstuvwxyz', 'ABCEFGHJKLMNPQRSTUVWXYZ', '23456789', '!"#%&'),

        # Specifies a string containing a character group from which the first character in the password will be generated.
        # Useful for systems which requires first char in password to be alphabetic.
        [String] $FirstChar,
        
        # Specifies number of passwords to generate.
        [ValidateRange(1,2147483647)]
        [int]$Count = 1
    )
    Begin {
        Function Get-Seed{
            # Generate a seed for randomization
            $RandomBytes = New-Object -TypeName 'System.Byte[]' 4
            $Random = New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider'
            $Random.GetBytes($RandomBytes)
            [BitConverter]::ToUInt32($RandomBytes, 0)
        }
    }
    Process {
        For($iteration = 1;$iteration -le $Count; $iteration++){
            $Password = @{}
            # Create char arrays containing groups of possible chars
            [char[][]]$CharGroups = $InputStrings

            # Create char array containing all chars
            $AllChars = $CharGroups | ForEach-Object {[Char[]]$_}

            # Set password length
            if($PSCmdlet.ParameterSetName -eq 'RandomLength')
            {
                if($MinPasswordLength -eq $MaxPasswordLength) {
                    # If password length is set, use set length
                    $PasswordLength = $MinPasswordLength
                }
                else {
                    # Otherwise randomize password length
                    $PasswordLength = ((Get-Seed) % ($MaxPasswordLength + 1 - $MinPasswordLength)) + $MinPasswordLength
                }
            }

            # If FirstChar is defined, randomize first char in password from that string.
            if($PSBoundParameters.ContainsKey('FirstChar')){
                $Password.Add(0,$FirstChar[((Get-Seed) % $FirstChar.Length)])
            }
            # Randomize one char from each group
            Foreach($Group in $CharGroups) {
                if($Password.Count -lt $PasswordLength) {
                    $Index = Get-Seed
                    While ($Password.ContainsKey($Index)){
                        $Index = Get-Seed                        
                    }
                    $Password.Add($Index,$Group[((Get-Seed) % $Group.Count)])
                }
            }

            # Fill out with chars from $AllChars
            for($i=$Password.Count;$i -lt $PasswordLength;$i++) {
                $Index = Get-Seed
                While ($Password.ContainsKey($Index)){
                    $Index = Get-Seed                        
                }
                $Password.Add($Index,$AllChars[((Get-Seed) % $AllChars.Count)])
            }
            Write-Output -InputObject $(-join ($Password.GetEnumerator() | Sort-Object -Property Name | Select-Object -ExpandProperty Value))
        }
    }
}


#generate 8 length random password
echo "ArtifactStagingDirectory="
echo $ArtifactStagingDirectory
$parametersFilePath=$ArtifactStagingDirectory+'\labs\labs-azuredeploy.parameters.json'
$parametersFilePath=[System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $parametersFilePath))

$parametersFilePath2=$ArtifactStagingDirectory+'\labs\labs-azuredeploy2.parameters.json'
$parametersFilePath2=[System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $parametersFilePath2))


echo "parametersFilePath="
echo $parametersFilePath
$password=New-SWRandomPassword -InputStrings abcdefghijkmnpqrstuvwxyz, ABCEFGHJKLMNPQRSTUVWXYZ, 1234567890 -PasswordLength 8 -FirstChar abcdefghijkmnpqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ;
$parametersFileContent = Get-Content $parametersFilePath | Out-String 
$parametersFileContent=$parametersFileContent.Replace("%{adminPassword}%", $password);

if (Test-Path $parametersFilePath2)
{
    $parametersFileContent2 = Get-Content $parametersFilePath | Out-String 
    $parametersFileContent2=$parametersFileContent.Replace("%{adminPassword}%", $password);
}


#generte unique dns name
$dns=New-SWRandomPassword -InputStrings abcdefghijkmnpqrstuvwxyz -PasswordLength 8 -FirstChar abcdefghijkmnpqrstuvwxyz;
$dns=$dns+$buildId
$parametersFileContent=$parametersFileContent.Replace("%{dnsLabelPrefix}%", $dns);

if (Test-Path $parametersFilePath2) {
    $dns2=New-SWRandomPassword -InputStrings abcdefghijkmnpqrstuvwxyz -PasswordLength 8 -FirstChar abcdefghijkmnpqrstuvwxyz;
    $dns2=$dns+$buildId
    $parametersFileContent2=$parametersFileContent.Replace("%{dnsLabelPrefix}%", $dns2);
}


#generate ssh key and replace

$isRequiredSSH=$parametersFileContent.Contains("%{sshRSAPublicKey}%")

if($isRequiredSSH)
{
      $sshkeyFolderPath = $ArtifactStagingDirectory+'\labs\sshkey';
      $sshkeyFolderPath=[System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $sshkeyFolderPath))
      $existing = [System.Boolean](Test-Path $sshkeyFolderPath)
      if($existing)
      {
          Remove-Item $sshkeyFolderPath -recurse
      }
      New-Item $sshkeyFolderPath -type directory
      $Email = "info@lean-soft.cn"
      $sshKeyFileName = $sshkeyFolderPath + "\id_rsa"
      & 'C:\Program Files\Git\usr\bin\ssh-keygen.exe'  -t rsa -C $Email -f $sshKeyFileName -P """"

      $sshkeyPubFileName = $sshKeyFileName+".pub"
      $publicKeyContent = [IO.File]::ReadAllText($sshkeyPubFileName)
      $privateKeyContent = [IO.File]::ReadAllText($sshKeyFileName)
      Write-Host " publick key : " + $publicKeyContent
      Write-Host " private key : " + $privateKeyContent

      $parametersFileContent=$parametersFileContent.Replace("%{sshRSAPublicKey}%", $publicKeyContent);


}


#save file
echo $parametersFileContent
echo $parametersFileContent2
out-File -FilePath $parametersFilePath -InputObject $parametersFileContent
out-File -FilePath $parametersFilePath2 -InputObject $parametersFileContent2