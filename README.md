> 🇷🇺 Read in [Russian](README_ru.md)

# Xray Wi-Fi Gateway Setup

Automated setup of a local Wi-Fi proxy gateway that tunnels all traffic through Xray (via sing-box).

The script:
- Installs **sing-box** and generates a config from a `vmess://`, `vless://`, or `trojan://` link
- Sets up an access point with **hostapd** and DHCP via **dnsmasq**
- Routes all client traffic through a local **tun0** interface
- Applies **iptables** NAT, configures DNS, and registers systemd services
- Works on both `amd64` and `arm64` (Orange Pi, Raspberry Pi, etc.)

---

## Quick Start

### 1. Clone this repo on a Linux device (Ubuntu 22/24+)

```bash
git clone https://github.com/sergrych/xray-wifi-proxy-server.git
cd xray-wifi-proxy-server
```

### 2. Run the setup

```bash
bash setup.sh
```

### 3. Answer the prompts:

-  Paste your Xray URL (e.g. `vless://uuid@ip:port?...`)
-  Select your Wi-Fi interface (e.g. `wlan0`)
-  Set a Wi-Fi SSID (default: `TunnelNet`)
-  Set a Wi-Fi password (min 8 characters, default: `tunnelproxy`)

---

##  What `setup.sh` Does

- Downloads and installs `sing-box` version **1.11.8**
- Generates `/etc/sing-box/config.json` with routing and tunneling
- Installs `dnsmasq`, `hostapd`, sets up `iptables` and IP forwarding
- Creates Wi-Fi and DHCP configs based on user input
- Registers `init-tunnel.service` in `systemd` to apply on boot
- Sets DNS to `1.1.1.1` and locks `/etc/resolv.conf`
- Enables and starts all services via `systemctl`

---

##  Requirements

- Ubuntu 22.04 or 24.04 (headless, no GUI)
- TUN support (`/dev/net/tun`, `net.ipv4.ip_forward = 1`)
- Wi-Fi adapter that supports **AP mode**
- Internet access on the device

---

##  Additional Notes

- All configs (`sing-box`, `dnsmasq`, `hostapd`) are generated dynamically
- Everything is brought up automatically on reboot
- To reconfigure: remove systemd services and rerun `setup.sh`

---

##  File Structure

```text
setup.sh                 # Main interactive script: asks for URL, interface, SSID
setup-sing-box.sh        # Installs sing-box and creates config.json
install-gateway.sh       # Sets up Wi-Fi AP, DHCP, iptables, systemd services
init-tunnel.sh           # Assigns static IP and restarts dnsmasq
prepare-wifi.sh          # Disables NetworkManager, rfkill, wpa_supplicant
```

---

##  Docker Support (optional)

You can build and run this in Docker using `proxy.ini` config file:

```ini
url = vless://uuid@ip:port?...    # Xray URL
iface = wlan0                     # Wi-Fi interface
ssid = TunnelNet                  # SSID for AP
passphrase = tunnelproxy          # Wi-Fi password
```

```bash
docker build -t singbox-gateway .
docker run --privileged --cap-add=NET_ADMIN --device /dev/net/tun -it singbox-gateway
```

>  Wi-Fi access points typically do not work inside Docker — this is for tunnel testing only.

---

##  Troubleshooting

- If `setup.sh` appears to do nothing — check for accidental `exit` in `setup-sing-box.sh`
- If Wi-Fi doesn’t start — make sure your adapter supports **AP mode** (`iw list`)
- If DNS doesn’t work — check `/etc/resolv.conf` and disable `systemd-resolved`
- If tunneling fails — inspect `systemctl status sing-box`

---

Done! Your device is now broadcasting a Wi-Fi network with full Xray tunneling.

Works on both ARM and x86 Linux devices.
