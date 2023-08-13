#!/bin/bash

cd $(dirname $0)

vacant_ip_lso=$(awk -F '[./]' '/^AllowedIPs/ { values[$4]=$4 } END{vacant=5;while(vacant in values){vacant+=1};print vacant}' /etc/wireguard/wg0.conf)
vacant_ip=10.0.0.$vacant_ip_lso

mkdir ./$vacant_ip
cd ./$vacant_ip
wg genkey > $vacant_ip.key && wg pubkey > $vacant_ip.pub < $vacant_ip.key


spubkey=`awk -F '[ ]' '/^PrivateKey/ {print $3}' /etc/wireguard/wg0.conf | wg pubkey`

wg set wg0 peer $(cat $vacant_ip.pub) allowed-ips $vacant_ip/32
wg-quick save wg0

echo -e "\
[Interface]\n\
Address = 10.0.0.$vacant_ip_lso/24\n\
DNS = 1.1.1.1\n\
PrivateKey = $(cat $vacant_ip.key)\n\
Table = off\n\
\n\
[Peer]\n\
AllowedIPs = 0.0.0.0/0, ::/128\n\
Endpoint = 127.0.0.1:50000\n\
PersistentKeepalive = 25\n\
PublicKey = $spubkey\n\
" > wgtun0.conf

echo -e "\
{\n\
    "remote_authority": \"\",\n\
    "remote_wg_port": 51820,\n\
    "proxy_authority": \"\",\n\
    "gw": \"\",\n\
    "interface_toward_proxy": \"\",\n\
    "metric_start_from": 15\n\
}\n\
" > config.json
