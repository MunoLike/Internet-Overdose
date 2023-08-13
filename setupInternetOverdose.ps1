Param(
    [String]$conf = "./wgtun0.conf"
)

@("System.Net.WebClient", "System.IO.Compression") | ForEach-Object { [void][System.Reflection.Assembly]::LoadWithPartialName($_) }


$LOGO = @'
  _____ _   _ _______ ______ _____  _   _ ______ _______               
  |_   _| \ | |__   __|  ____|  __ \| \ | |  ____|__   __|             
   | | |  \| |  | |  | |__  | |__) |  \| | |__     | |                 
    | | | . ` |  | |  |  __| |  _  /| . ` |  __|    | |                
  _| |_| |\  |  | |  | |____| | \ \| |\  | |____   | |                 
|_____|_| \_|__|_|_ |______|_|__\_\_|_\_|______| _|_|   _____ ______   
             / __ \ \    / /  ____|  __ \|  __ \ / __ \ / ____|  ____| 
             | |  | \ \  / /| |__  | |__) | |  | | |  | | (___ | |__   
           | |  | |\ \/ / |  __| |  _  /| |  | | |  | |\___ \|  __|    
             | |__| | \  /  | |____| | \ \| |__| | |__| |____) | |____ 
             \____/   \/   |______|_|  \_\_____/ \____/|_____/|______| 

'@
function Download($url) {
    $web_client = [System.Net.WebClient]::new()

    $is_under_proxy = (Get-ItemProperty -LiteralPath "HKCU:Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
    if ($is_under_proxy) {
        $proxy_server_url = (Get-ItemProperty -LiteralPath "HKCU:Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer")
        $url = ([System.Uri]$proxy_server_url)
        $proxy_server = [System.Net.WebProxy]($url.Scheme + "://" + $url.Host + $url.Port, $true)

        if ($null -ne $url.UserInfo) {
            $sped = $url.UserInfo.Split(":")
            $credential = [System.Net.NetworkCredential]($sped[0], $sped[1])
            $proxy_server.Credentials = $credential
        }
        $web_client.Proxy = $proxy_server
    }

    return $web_client.DownloadData($url)
}

function Unzip {
    param(
        [byte[]]$byte,
        [string]$path
    )

    $compressedStream = [System.IO.MemoryStream]::new($byte)

    # Create a decompression stream using the ZipArchive class
    $zipArchive = [System.IO.Compression.ZipArchive]::new($compressedStream, [System.IO.Compression.ZipArchiveMode]::Read)

    # Extract all the files from the ZIP archive
    $zipArchive.Entries | Where-Object { $_.FullName.Contains(".exe") } | ForEach-Object {
        $entry = $_
        $entryStream = $entry.Open()
        $file = [System.IO.File]::Create($path)
        $entryStream.CopyTo($file)
        $file.Close()
        $entryStream.Close()
    }

    $zipArchive.Dispose()
    $compressedStream.Close()
}


function Print-RainbowText {
    param (
        [string]$Text
    )

    $esc = [char]27
    Write-Output ""

    $colors = @('Red', 'Yellow', 'Green', 'Cyan', 'Blue', 'Magenta')
    $colorIndex = 0

    foreach ($char in $Text.ToCharArray()) {
        $currentColor = $colors[$colorIndex % $colors.Count]

        Write-Host -NoNewline -ForegroundColor $currentColor -Object ("${esc}[1m" + "${char}") -BackgroundColor Black
        $colorIndex++
    }

    Write-Host
}

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -WorkingDirectory "$PSScriptRoot" -Verb RunAs
    exit
}

Set-Location $PSScriptRoot

Write-Host "Checking whether Wireguard is installed..."
$is_WG_installed = ((Get-ChildItem -LiteralPath (('HKLM:', 'HKCU:' | ForEach-Object { "${_}\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" }) `
                + 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) |`
        Where-Object { $_.GetValue("DisplayName") -eq "WireGuard" }).Length

if (!$is_WG_installed) {
    Write-Host "Downloading wireguard..."
    try {
        $msi = Download "https://download.wireguard.com/windows-client/wireguard-amd64-0.5.3.msi"
        [io.File]::WriteAllBytes(".\wireguard-installer.msi", $msi)
    }
    catch {
        Write-Host "Something went wrong. Pls set up wireguard manually."
        Read-Host
        exit -1
    }

    Start-Process -FilePath "msiexec.exe" -ArgumentList "/package wireguard-installer.msi" -Wait
}

if (!(Test-Path "$env:APPDATA/../Local/InternetOverdose")) {
    New-Item -Item Directory -Force $env:APPDATA/../Local/InternetOverdose
}

$is_wstunnel_installed = (Test-Path $env:APPDATA/../Local/InternetOverdose/wstunnel.exe)
if (!$is_wstunnel_installed) {
    Write-Host "Downloading wstunnel..."
    try {
        $zip = Download "https://github.com/erebe/wstunnel/releases/latest/download/wstunnel-windows-x64.zip"
        Unzip $zip "$env:APPDATA\..\Local\InternetOverdose\wstunnel.exe"
    }
    catch {
        Write-Host "Something went wrong. Pls set up wstunnel manually." -ForegroundColor Red
        Write-Host $_ -ForegroundColor Red
        Read-Host
        exit -1
    }
    Write-Host "Installed in: "$env:APPDATA"\..\Local\InternetOverdose\"
}

Copy-Item -Force ./startup.ps1 $env:APPDATA\..\Local\InternetOverdose\
Copy-Item -Force ./bootstrap.exe $env:APPDATA\..\Local\InternetOverdose\
Write-Host "Copied startup.ps1."

if (!(Test-Path $conf)) {
    Write-Host "wireguard用コンフィグファイルが見つかりませんでした。" -ForegroundColor Red
    Write-Host "setupInternetOverdose.ps1 [config_file]"
    Read-Host
    exit -1
}
Copy-Item -Force .\$conf $env:APPDATA\..\Local\InternetOverdose\wgtun0.conf
Write-Host "Copied the wg conf file."

Copy-Item -Force .\config.json $env:APPDATA\..\Local\InternetOverdose\config.json

# Create Task scheduler
.\registTaskScheduler.ps1
Write-Host "Registed the startup script"

Write-Host "The installing has been done."
Write-Host "せーの!" -NoNewline -ForegroundColor Black -BackgroundColor White
Print-RainbowText $LOGO

Write-Host "Please press the enter key..."
Read-Host