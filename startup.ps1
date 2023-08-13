
# https://feeld-uni.com/?p=1244
function ConvertFrom-Ini {

    $ini = [ordered]@{}
    $commentCount = 0

    switch -regex ($input) {
        "^\[(.+)\]" {
            $section = $matches[1]
            $ini[$section] = @{}
            $commentCount = 0
        }
        "^((;|#).*)$" {
            $value = $matches[1]
            $commentCount = $commentCount + 1
            $name = "Comment" + $commentCount
            if ($null -eq $section) {
                $section = "NoSection"
                $ini[$section] = @{}
            }
            $ini[$section][$name] = $value
        }
        "(.+?)\s*=(.*)" {
            $name, $value = $matches[1..2]
            if ($null -eq $section) {
                $section = "NoSection"
                $ini[$section] = @{}
            }
            $ini[$section][$name] = $value
        }
    }

    return $ini
}

function ConvertTo-Ini($ini) {
    $sb = New-Object System.Text.StringBuilder

    foreach ($sectionKey in $ini.Keys | Sort-Object) {
        if ($sectionKey -ne "NoSection") {
            [void]$sb.AppendLine("[$sectionKey]")
        }

        foreach ($key in $ini[$sectionKey].Keys | Sort-Object ) {
            if ($key -match "^Comment[\d]+") {
                [void]$sb.AppendLine("$($ini[$sectionKey][$key])")
            }
            else {
                [void]$sb.AppendLine("$key=$($ini[$sectionKey][$key])")
            }
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}

if (!(Test-Path .\config.json)) {
    Write-Host "スタートアップ時にコンフィグファイルが見つかりませんでした．" -ForegroundColor Red
    exit -1
}
$config = (Get-Content .\config.json | ConvertFrom-Json)

$service = (Get-Service -Name 'WireGuardTunnel$wgtun0' -ErrorAction SilentlyContinue)
if ($null -ne $service) {
    wireguard /uninstalltunnelservice wgtun0
}

$is_under_proxy = (Get-ItemProperty -LiteralPath "HKCU:Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
if ($is_under_proxy) {
    $proxy_server = (Get-ItemProperty -LiteralPath "HKCU:Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyServer
    $url = ([System.Uri]$proxy_server)
    $proxy_host = $url.Host
    $proxy_ip = [System.Net.Dns]::GetHostAddresses($proxy_host).IPAddressToString
    $proxy_user = if ($url.UserInfo -ne "") { $url.UserInfo + "@" }else { "" }
    $config.proxy_authority = if ($url.HostNameType -eq [System.UriHostNameType]::IPv4) {
        $proxy_user + $proxy_ip + ":" + $url.Port
    }
    else {
        $proxy_user + "[" + $proxy_ip + "]:" + $url.Port
    }

    $netroute = (Find-NetRoute -RemoteIPAddress $proxy_ip)[1]
    $config.interface_toward_proxy = $netroute.InterfaceAlias
    $config.gw = $netroute.NextHop

    Set-ItemProperty -LiteralPath "HKCU:Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0
    ConvertTo-Json $config | Out-File .\config.json
}

$is_under_proxy = ($config.proxy_authority -ne "")

if ($is_under_proxy) {
    $fullmask = if ((($config.proxy_authority.ToCharArray() | Where-Object { $_ -eq ":" }).Length) -gt 2) { 128 } else { 32 } # select for CIDR expression
    $proxy_ip = ([System.Uri]("http://" + $config.proxy_authority)).DnsSafeHost
    # Ensure a route to the proxy
    New-NetRoute -DestinationPrefix "${proxy_ip}/${fullmask}" -NextHop $config.gw -InterfaceAlias $config.interface_toward_proxy -RouteMetric ($config.metric_start_from - 1) -PolicyStore ActiveStore
    Write-Host ("Ensure a route: ${proxy_ip}/${fullmask}" + " --[" + $config.interface_toward_proxy + "]--> " + $config.gw)
}

$local_ws_port = 50000
while ($null -ne (Get-NetUDPEndpoint -LocalPort $local_ws_port -ErrorAction Ignore)) {
    $local_ws_port++
}

[array]$ws_args = @("--udp", "--quiet", "--udpTimeoutSec -1", ("-L 127.0.0.1:${local_ws_port}:127.0.0.1:" + $config.remote_wg_port))
if ($is_under_proxy) {
    $ws_args += "--httpProxy=`"" + $config.proxy_authority + "`""
}

$ws_args += "wss://" + $config.remote_authority

$ws_exec = ".\wstunnel.exe" + " " + ($ws_args -join " ")
$ws_exec = $ws_exec.Replace("`"", "\`"")
Write-Host "`".\bootstrap.exe ${ws_exec}`""
runas.exe /trustlevel:0x20000 ".\bootstrap.exe ${ws_exec}"

$wg_conf = Get-Content .\wgtun0.conf | ConvertFrom-Ini
$wg_conf["Peer"]["Endpoint"] = "127.0.0.1:${local_ws_port}"
ConvertTo-Ini $wg_conf | Out-File .\wgtun0.conf
wireguard.exe /installtunnelservice ('"' + (Resolve-Path .\wgtun0.conf).Path + '"')
Start-Sleep -s 1
Set-Service -Name 'WireGuardTunnel$wgtun0' -StartupType Manual
$wg_gw = $wg_conf["Interface"]["Address"].Trim().split("/")[0]
New-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop $wg_gw -InterfaceAlias wgtun0 -RouteMetric ($config.metric_start_from - 1) -PolicyStore ActiveStore
