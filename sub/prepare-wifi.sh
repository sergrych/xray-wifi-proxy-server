#!/bin/bash
set -e

IFACE="$1"

if [[ -z "$IFACE" ]]; then
  echo "Usage: $0 wlan0"
  exit 1
fi

echo "Preparing Wi-Fi interface '$IFACE' for Access Point mode..."

# 1. Stop wpa_supplicant if it's running
echo "Disabling wpa_supplicant..."
systemctl stop wpa_supplicant 2>/dev/null || true
systemctl disable wpa_supplicant 2>/dev/null || true

# 2. Remove rfkill block if any
echo "Unblocking Wi-Fi..."
apt install rfkill -y
rfkill unblock all || true

# 3. Set NetworkManager to ignore IFACE
NM_CONF="/etc/NetworkManager/NetworkManager.conf"
if ! grep -q "interface-name:$IFACE" "$NM_CONF"; then
  echo "Updating NetworkManager.conf to unmanaged $IFACE..."
  sed -i "/^\[keyfile\]/a unmanaged-devices=interface-name:$IFACE" "$NM_CONF"
  systemctl restart NetworkManager
else
  echo "$IFACE already unmanaged in NetworkManager"
fi

# 4. Bring interface up
echo "Bringing up $IFACE..."
ip link set "$IFACE" up || true

# 5. Show final status
sleep 1
echo "Interface info:"
iw dev "$IFACE" info || echo "Failed to get info for $IFACE"

echo -e "\nDone. You can now run hostapd or install-gateway.sh."
