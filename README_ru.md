#  Sing-box Wi-Fi Gateway через Xray внешний прокси.

Автоматическая установка и настройка локального Wi-Fi-прокси шлюза с туннелированием трафика через Xray (sing-box).

Скрипт:
- устанавливает **sing-box** и генерирует конфиг пока по ссылке вида `vless://`
- разворачивает точку доступа (**hostapd**) и DHCP (**dnsmasq**)
- прокидывает весь трафик через **tun0**-интерфейс
- сохраняет **iptables**, настраивает **DNS**, запускает **systemd-сервисы**
- работает с любой архитектурой: `amd64`, `arm64` (например, Orange Pi, Raspberry Pi)
- самое главное, делает "уное" разделение трафика ru и не ru (русский трафик идет напрямую)

---

##  Быстрый старт

### 1. Клонируй репозиторий на устройство с Linux (Ubuntu 22/24+)

```bash
git clone https://github.com/sergrych/xray-wifi-proxy-server.git
cd xray-wifi-proxy-server
```

### 2. Запусти установку

```bash
bash setup.sh
```

### 3. Ответь на вопросы:

-  Вставь Xray ссылку (например: `vless://uuid@ip:port?...`)
-  Выбери Wi-Fi интерфейс (например `wlan0`)
-  Введи имя Wi-Fi сети (SSID), по умолчанию `TunnelNet`
-  Введи пароль Wi-Fi, минимум 8 символов (по умолчанию `tunnelproxy`)

---

##  Что делает `setup.sh`

- Скачивает и устанавливает `sing-box` версии **1.13.12**
- Генерирует конфиг `/etc/sing-box/config.json` с маршрутизацией трафика
- Устанавливает `dnsmasq`, `hostapd`, `iptables`, включает **IP форвардинг**
- Генерирует конфиги Wi-Fi и DHCP по выбранному интерфейсу и имени сети
- Создаёт `systemd`-сервис `init-tunnel.service` для настройки при загрузке
- Прописывает `nameserver 1.1.1.1` и защищает `/etc/resolv.conf`
- Запускает всё через `systemctl enable ...` и стартует

---

##  Требования

- Ubuntu 22.04 или 24.04 (без GUI), проверено на Ubuntu 24.04.4 LTS
- Поддержка **tun** (`/dev/net/tun`, `net.ipv4.ip_forward = 1`)
- Wi-Fi адаптер с режимом **точки доступа (AP mode)**
- Интернет-доступ на устройстве

---

##  Дополнительно

- Все конфиги (`sing-box`, `dnsmasq`, `hostapd`) генерируются **динамически**
- При перезагрузке всё поднимается **автоматически**
- Для смены настроек: удали `systemd`-сервисы и запусти `setup.sh` заново

---

##  Структура файлов

```text
setup.sh                 # Главный скрипт: спрашивает URL, интерфейс, SSID
setup-sing-box.sh        # Устанавливает sing-box и создаёт config.json
install-gateway.sh       # Настраивает Wi-Fi, DHCP, iptables, systemd
init-tunnel.sh           # Назначает IP интерфейсу, рестартует dnsmasq
prepare-wifi.sh          # Отключает NetworkManager, rfkill, wpa_supplicant
```

---

## Поддержка

- Если `setup.sh` ничего не делает — проверь, нет ли `exit` внутри `setup-sing-box.sh`
- Если Wi-Fi не поднимается — проверь, что адаптер поддерживает **AP Mode** (`iw list`)
- Если не работает DNS — проверь `/etc/resolv.conf`, отключи `systemd-resolved`
- Если туннель не стартует — проверь `systemctl status sing-box`

---

## Полезные команды (для самоконтроля)
bash

Статус сервисов
```bash
systemctl status hostapd dnsmasq sing-box
```
Интерфейс tun0 (должен быть UP)
```bash
ip a show tun0
```
Правила NAT (должно быть MASQUERADE через tun0)
```bash
iptables -t nat -L POSTROUTING -v -n
```
Логи sing-box в реальном времени
```bash
journalctl -u sing-box -f
```
Проверка, куда идёт трафик (с клиента)
```bash
curl ifconfig.me          # должен показать IP вашего внешнего прокси сервера
curl --interface wlx... yandex.ru   # должен идти напрямую
```
Проверка конфига sing-box
```bash
sing-box -c /etc/sing-box/config.json check
```

Готово! Устройство теперь раздаёт Wi-Fi с туннелем через Xray.

Поддерживаются любые устройства с ARM или x86 архитектурой.
