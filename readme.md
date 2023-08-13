# *InternetOverdose*
Getting over the kosen gfw.

`setupInternetOverdose.ps1`を実行すると`%appdata%\..\Local\InternetOverdose`フォルダにインストールされる．

`connect.ps1`で接続開始，`disconnect.ps1`で切断する．

あくまで個人用に制作したものであるため，使用にあたって損害が発生したとしても当方は一切の責任を負わない．

設定はインストールされたフォルダ内の`config.json`を編集して行う．

# config.json
| Field名                | Description                                                                                                                                                                              |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| metric_start_from      | 使用するメトリックの開始値を指定する．`metric_start_from-1`の値をプロキシ宛て通信に，`metric_start_from`の値をwireguardのトンネルに設定する．Windowsの標準設定等よりも高い値にすること． |
| remote_authority       | 相手先のURLを指定する．URIでいうオーソリティを指定する．例) `123.123.123.123:8080`                                                                                                       |
| remote_wg_port         | 相手先のWireGuardが動作しているポートを指定する．相手先のconfファイル内のListenPortの値．                                                                                                |
| proxy_authority        | プロキシを使用している場合にはプロキシのオーソリティを指定する．Windowsの設定（旧IE）で設定している場合自動的に読み込まれ，このフィールドに保存される． 例) `aaaaaa.com:8080`            |
| gw                     | 外部に出るために経由するゲートウェイを指定する．ほとんどの場合自動的に設定される．                                                                                                       |
| interface_toward_proxy | 外部と接続するためのインターフェースのエイリアスを指定する．PowershellのGet-NetAdapterで得られるものと同じ．ほとんどの場合自動的に設定される．                                           |

# 不具合
1台のPCで2人のユーザーが使用しようとするとうまくいかない（はず）．
