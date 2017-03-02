# Author: Brian Lund <brian@cze.dk>
# Purpose: Bootstrap Windows Chef node from AWS userdata
# Requires: AWSPowerShell module
# Credits: Based on the bash version in the AWS OpsWorks docs: http://docs.aws.amazon.com/opsworks/latest/userguide/opscm-unattend-assoc.html
# Settings: Change chefServerName and chefServerEndpoint at a minimum

# Required settings
$global:region              = "eu-west-1"
$global:chefServerName      = "serverName"
$global:chefServerEndpoint  = "endpoint" # Provide the FQDN or endpoint; it's the string after 'https://'
$global:chefConf            = "c:\chef\client.rb"
$global:chefCaPath          = "C:\Users\Administrator\.chef\trusted_certs\"
$global:chefCaFile          = "opsworks-cm-ca-2016-root.pem"
$global:opensslURI          = "https://slproweb.com/download/Win32OpenSSL_Light-1_1_0e.exe"

# Optional settings
$chefOrganization="default"    # Leave as "default"; do not change. AWS OpsWorks for Chef Automate always creates the organization "default"
$nodeEnvironment=""            # e.g. development, staging, onebox ...
$chefClientVersion="12.16.42"  # latest if empty

# Recommended: upload the chef-client cookbook from the chef supermarket  https://supermarket.chef.io/cookbooks/chef-client
# Use this to apply sensible default settings for your chef-client configuration like logrotate, and running as a service.
# You can add more cookbooks in the run list, based on your needs
$runList="recipe[chef-client]" # e.g. "recipe[chef-client],recipe[apache2]"

function Get-InstanceId
{
    Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id
}

function Install-OpenSSL
{
  $opensslinst = "$env:temp\opensslinst.exe"
  $openssl = "$opensslinst /verysilent /dir=$env:temp\openssl"
  (New-Object System.Net.WebClient).DownloadFile($opensslURI, "$opensslinst")
  Sleep 2
  iex $openssl
  Write-Output "ran $openssl"
  echo "`$LastExitCode=$LastExitCode and `$?=$?"
}

function Associate-Node ($instanceId)
{
  New-Item "c:\chef" -type directory
  $clientKey = "c:\chef\client.pem"
  $clientPub = "c:\chef\client.pub"
  iex "$env:temp\openssl\bin\openssl.exe genrsa -out $clientKey 2048"
  Sleep 2
  iex "$env:temp\openssl\bin\openssl.exe rsa -in $clientKey -pubout -out $clientPub"
  Sleep 2
  $publicKey = $content = [IO.File]::ReadAllText($clientPub)
  $global:associationToken = Add-OWCMNode -Region $region -ServerName $chefServerName -EngineAttribute @{Name = "CHEF_NODE_PUBLIC_KEY"; Value = $publicKey},@{Name = "CHEF_ORGANIZATION"; Value = $chefOrganization} -NodeName $instanceId
}

function Get-AssociationStatus ($associationToken, $chefServerName)
{
    Get-OWCMNodeAssociationStatus -Region $region -ServerName $chefServerName -NodeAssociationStatusToken $associationToken
}

function Wait-NodeAssociated ($associationToken)
{
  while ($associationStatus -ne "SUCCESS")
    {
      $associationStatus = Get-AssociationStatus $associationToken $chefServerName
      Write-Output $associationStatus
      Sleep 2
    }
}

function Install-TrustedCert
{
    $certificatePEM      = "https://s3-eu-west-1.amazonaws.com/opsworks-cm-" + $region + "-beta-default-assets/misc/opsworks-cm-ca-2016-root.pem"
    New-Item "$chefCaPath" -type directory
    (New-Object System.Net.WebClient).DownloadFile($certificatePEM, "$chefCaPath$chefCaFile")
}

function Install-Chef
{
  . { iwr -useb https://omnitruck.chef.io/install.ps1 } | iex; install -channel current -project chef
}

function Write-ChefConfig
{
    if (!(Test-Path $chefConf))
    {
      $confChefServerUrl = "chef_server_url 'https://$chefServerEndpoint/organizations/$chefOrganization'"
      $confNodeName = "node_name  '$instanceId'"
      $confSslCaFile = "ssl_ca_file '$chefCaPath$chefCaFile'"
      $confChefServerUrl, $confNodeName, $confSslCaFile  | Out-File -filepath $chefConf -Encoding UTF8
    }
}


Install-OpenSSL
Install-Chef
Install-TrustedCert
$instanceId = Get-InstanceId
Associate-Node $instanceId
Wait-NodeAssociated $associationToken
Write-ChefConfig

# Reload PATH so we can find chef-client
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# launch the chef client 
if ($nodeEnvironment)
{
  chef-client -r $runList -E $nodeEnvironment
}
else
{
    chef-client -r $runList
}
