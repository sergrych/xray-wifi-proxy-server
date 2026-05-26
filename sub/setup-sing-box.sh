#!/bin/bash
set -e

trap 'echo -e "\n Ошибка в строке $LINENO. Код выхода: $?"; exit 1' ERR

# — URL-парсинг —
if [[ $1 == "--url" && -n $2 ]]; then
  XRAY_URL="$2"
else
  read -rp $'\n Вставьте ссылку Xray ( vless://): ' XRAY_URL
fi

# Download geodb
mkdir -p /etc/sing-box/rulesets
cd /etc/sing-box/rulesets
wget https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs
wget https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-us.srs
wget https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs

# start and enable systemd-resolved.service
systemctl start systemd-resolved.service
systemctl enable systemd-resolved.service


# Download and install sing-box binary if not present
if ! command -v sing-box >/dev/null; then
  echo "🔧 Installing sing-box..."
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH=amd64;;
    aarch64) ARCH=arm64;;
    *) echo "Unsupported architecture: $ARCH"; exit 1;;
  esac

  VERSION="1.13.12"
  SING_BOX_URL="https://github.com/SagerNet/sing-box/releases/download/v$VERSION/sing-box-$VERSION-linux-$ARCH.tar.gz"

  echo "Trying to download $SING_BOX_URL"

  curl -L -o sing-box.tar.gz "$SING_BOX_URL"
  tar -xf sing-box.tar.gz
  sudo install -m 755 sing-box-*/sing-box /usr/local/bin/sing-box
  rm -rf sing-box.tar.gz sing-box-*
  echo "sing-box v$VERSION installed to /usr/local/bin/sing-box"
fi

PROTO=""
SERVER=""
PORT=""
UUID=""
TLS_ENABLED="false"
PASSWORD=""

FLOW="xtls-rprx-vision"
SNI=""
FP="chrome"
PBK=""
SID=""

echo "Xray url = $XRAY_URL"

if [[ $XRAY_URL == vmess://* ]]; then
  CONFIG_JSON=$(echo "${XRAY_URL#vmess://}" | base64 -d 2>/dev/null)
  [[ -z $CONFIG_JSON ]] && { echo "❌ Failed to decode vmess link."; exit 1; }
  PROTO="vmess"
  SERVER=$(echo "$CONFIG_JSON" | jq -r .add)
  PORT=$(echo "$CONFIG_JSON" | jq -r .port)
  UUID=$(echo "$CONFIG_JSON" | jq -r .id)
  TLS_RAW=$(echo "$CONFIG_JSON" | jq -r .tls)
  TLS_ENABLED=$( [[ "$TLS_RAW" == "tls" || "$TLS_RAW" == "true" ]] && echo true || echo false )
  ALTERID=$(echo "$CONFIG_JSON" | jq -r '.aid // empty')

elif [[ $XRAY_URL == vless://* ]]; then
  PROTO="vless"
  FULL=${XRAY_URL#vless://}
  UUID=${FULL%@*}
  REST=${FULL#*@}
  SERVER=${REST%%:*}
  PORT=${REST#*:}; PORT=${PORT%%\?*}
  SECURITY=$(echo "$REST" | grep -oP 'security=\K[^&]*' || echo "")
  TLS_ENABLED=$( [[ "$SECURITY" == "tls" || "$SECURITY" == "reality" ]] && echo true || echo false )
  
  PARAMS="${REST#*\?}"   # берём всё после ? (параметры)
  # извлекаем каждый параметр
  PBK=$(echo "$PARAMS" | grep -oP 'pbk=\K[^&]*' || echo "")
  SID=$(echo "$PARAMS" | grep -oP 'sid=\K[^&]*' || echo "")
  SNI=$(echo "$PARAMS" | grep -oP 'sni=\K[^&]*' || echo "")
  FP=$(echo "$PARAMS" | grep -oP 'fp=\K[^&]*' || echo "chrome")
  FLOW=$(echo "$PARAMS" | grep -oP 'flow=\K[^&]*' || echo "")
  SPX=$(echo "$PARAMS" | grep -oP 'spx=\K[^&]*' || echo "")


elif [[ $XRAY_URL == trojan://* ]]; then
  PROTO="trojan"
  FULL=${XRAY_URL#trojan://}
  PASSWORD=${FULL%%@*}
  REST=${FULL#*@}
  SERVER=${REST%%:*}
  PORT=${REST#*:}; PORT=${PORT%%\?*}
  TLS_ENABLED=true

else
  echo "Only vmess://, vless:// and trojan:// links are supported."
  exit 1
fi

echo "Configs exctraction done! SERVER=$SERVER, PORT=$PORT, UUID=$UUID, PASSWORD=$PASSWORD"

[[ -z $SERVER || -z $PORT || (-z $UUID && -z $PASSWORD) ]] && { echo "Failed to extract connection parameters."; exit 1; }

mkdir -p /etc/sing-box
cat <<EOF | sudo tee /etc/sing-box/config.json > /dev/null
{
  "log": { "level": "info" },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "type": "https",
        "server": "1.1.1.1",
        "server_port": 443,
        "tls": { "enabled": true }
      },
      {
        "tag": "local",
        "type": "udp",
        "server": "223.5.5.5",
        "server_port": 53
      }
    ],
    "rules": [
      {
        "rule_set": "geoip-cn",
        "server": "local"
      }
    ],
    "final": "cloudflare"
  },
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "tun0",
      "address": ["172.19.0.1/30"],
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "stack": "system"
    }
  ],
  "outbounds": [
{
      "type": "$PROTO",
      "tag": "proxy",
      "server": "$SERVER",
      "server_port": $PORT,
      "uuid": "$UUID",
      "flow": "$FLOW",
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "utls": {
          "enabled": true,
          "fingerprint": "$FP"
        },
        "reality": {
          "enabled": true,
          "public_key": "$PBK",
          "short_id": "$SID"
        }
      }
    },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "final": "proxy",
    "default_domain_resolver": "cloudflare",
    "auto_detect_interface": true,
    "rules": [
      {
        "domain_suffix": ["ru", "vc.com", "yandex.ru"],
        "outbound": "direct"
      },
      {
        "ip_cidr": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "192.168.100.0/24"],
        "outbound": "direct"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-ru",
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-us",
        "outbound": "proxy"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-cn",
        "type": "local",
        "format": "binary",
        "path": "/etc/sing-box/rulesets/geoip-cn.srs"
      },
      {
        "tag": "geoip-us",
        "type": "local",
        "format": "binary",
        "path": "/etc/sing-box/rulesets/geoip-us.srs"
      },
      {
        "tag": "geoip-ru",
        "type": "local",
        "format": "binary",
        "path": "/etc/sing-box/rulesets/geoip-ru.srs"
      }
    ]
  },
  "experimental": {
    "cache_file": { "enabled": true }
  }
}
EOF

set +x

cat <<EOF > /etc/systemd/system/sing-box.service
[Unit]
Description=sing-box proxy service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run --config /etc/sing-box/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo -e "\n sing-box config saved to /etc/sing-box/config.json"
echo "   Protocol: $PROTO"
echo "   Server: $SERVER:$PORT"
[[ -n $UUID ]] && echo "   UUID: $UUID"
if [[ -n $PASSWORD ]]; then echo "   Password: [hidden]"; fi
