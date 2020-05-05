﻿#PDQ_Remote_dev.ps1
#Powershell script for calling a package from a client. Client calls this script to deploy software to itself.

param (
    [Parameter(Mandatory=$true)]
    [string]$Package,
    [int]$BeginDeploymentTimeout = 40,
    [int]$DeploymentTimeout = 1800
)

#function borrowed from http://gallery.technet.microsoft.com/scriptcenter/Powershell-script-to-33887eb2#content
function ConvertFrom-Base64($stringfrom) { 
    $bytesfrom  = [System.Convert]::FromBase64String($stringfrom); 
    $decodedfrom = [System.Text.Encoding]::UTF8.GetString($bytesfrom); 
    return $decodedfrom   
}

# Grab the variables from the Task Sequence
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$tsenv.GetVariables() | % { Set-Variable -Name "$_" -Value "$($tsenv.Value($_))" }
#Set Credentials to Task Sequence variable values
$ClearID = ConvertFrom-Base64 -stringfrom "$UserID"
$ClearDomain = ConvertFrom-Base64 -stringfrom "$UserDomain"
$ClearPW = ConvertFrom-Base64 -stringfrom "$UserPassword"
$User = "$ClearDomain\$ClearID"
$Password = ConvertTo-SecureString -String "$ClearPW" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User,$Password

$computername = $env:COMPUTERNAME 
Invoke-Command -ComputerName Servername.corp.com -ScriptBlock { Set-Location "C:\Program Files (x86)\Admin Arsenal\PDQ Deploy\";  PDQDeploy.exe Deploy -Package $Using:package -Target $Using:computername } -credential $Credential

#wait for the package to start by waiting for the lock file to appear
## This is good for when deployments may be queued up if PDQ deployment server is heavily used.
$timerStart = Get-Date
do {
    Write-Host "Waiting for PDQ install to start on $env:COMPUTERNAME"
    Start-Sleep -Seconds 10
} until ((Test-Path "$env:SystemRoot\AdminArsenal\PDQDeployRunner\service-1.lock") -or
        ((Get-Date) - $timerStart).TotalSeconds -gt $BeginDeploymentTimeout )

### Check if the package is still running by looking for the lock file to disappear
$timerStart = Get-Date
do {
    Write-Host 'PDQ install started: waiting to complete on ' $env:COMPUTERNAME
    Start-Sleep -Seconds 10
} until (-not (Test-Path "$env:SystemRoot\AdminArsenal\PDQDeployRunner\service-1.lock") -or
        ((Get-Date) - $timerStart).TotalSeconds -gt $DeploymentTimeout )
