if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -WorkingDirectory "$PSScriptRoot" -Verb RunAs
    exit
}



$service = (Get-Service -Name 'WireGuardTunnel$wgtun0' -ErrorAction SilentlyContinue)
if ($null -ne $service) {
    wireguard /uninstalltunnelservice wgtun0
}
if ($null -ne ($proc = Get-Process -Name wstunnel -ErrorAction SilentlyContinue)) {
    $proc | Stop-Process
}

Get-ScheduledTask -TaskPath "\InternetOverdose\" -TaskName "Start wstunnel" -ErrorAction SilentlyContinue | Disable-ScheduledTask

Write-Host "Disconnected."
