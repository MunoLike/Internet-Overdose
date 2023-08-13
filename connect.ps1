Set-Location $env:APPDATA\..\Local\InternetOverdose

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -WorkingDirectory "$PSScriptRoot" -Verb RunAs
    exit
}

.\startup.ps1
Get-ScheduledTask -TaskPath "\InternetOverdose\" -TaskName "Start wstunnel" | Enable-ScheduledTask > $null
Write-Host "The connection has started."