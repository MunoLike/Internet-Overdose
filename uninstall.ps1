if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -WorkingDirectory "$PSScriptRoot" -Verb RunAs
    exit
}

Set-Location $PSScriptRoot
.\disconnect.ps1
Unregister-ScheduledTask -TaskPath "\InternetOverdose\" -TaskName "Start wstunnel" -Confirm:$false -ErrorAction SilentlyContinue

Remove-Item ($env:APPDATA + "\..\Local\InternetOverdose") -Recurse -Force

Write-Host "Uninstall has been completed."
Write-Host "WireGuard isn't uninstalled. Uninstall manually if you want."
Write-Host "Please press the Enter key..."

Read-Host