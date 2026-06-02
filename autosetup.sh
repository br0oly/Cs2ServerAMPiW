#!/bin/bash
set -euo pipefail

# ============================================================
#  CDV_CS2Server_AUTOSETUP — AMPiW CS2 2026
#  Instalacja systemu, CS2 i wywołanie install_plugins.sh
#  Zgodnie z runbookiem operacyjnym (wersja 1.0, 29.05.2026)
#
#  Użycie: sudo bash skrypt.sh <hasło_dla_cs2>
#  Wymagany obok: install_plugins.sh
# ============================================================

SCRIPTNAME="[CDV_CS2Server_AUTOSETUP]"

# --- Ścieżki zgodne z runbookiem ---
# Runbook zakłada: użytkownik=cs2, katalog=/home/cs2/cs2-server
SERVER_USER="cs2"
SERVER_HOME="/home/${SERVER_USER}"
SERVER_ROOT="${SERVER_HOME}/serverfiles"
CSGO_DIR="${SERVER_ROOT}/game/csgo"
ADDONS_DIR="${CSGO_DIR}/addons"
VALVE_BIN="${SERVER_ROOT}/game/bin/linuxsteamrt64"

# ============================================================
# 0. Sprawdzenie uprawnień i argumentów
# ============================================================

if [ "$EUID" -ne 0 ]; then
    echo "$SCRIPTNAME BŁĄD: Uruchom skrypt z uprawnieniami root (sudo $0 <hasło>)"
    exit 1
fi

if [ -z "${1-}" ]; then
    echo "$SCRIPTNAME BŁĄD: Podaj hasło dla użytkownika ${SERVER_USER} jako argument."
    echo "Użycie: sudo $0 <hasło>"
    exit 1
fi

SERVER_PASS="$1"

# ============================================================
# 1. Aktualizacja systemu i zapora sieciowa
# ============================================================

echo ""
echo "$SCRIPTNAME [1/4] Aktualizuję system oraz konfiguruję zaporę sieciową..."

apt update && apt upgrade -y

ufw --force enable

# CS2 — port główny
ufw allow 27015/tcp
ufw allow 27015/udp

# GOTV — port dla obserwatorów/streamu (eNStudios, runbook sekcja 1 i 10)
ufw allow 27020/tcp
ufw allow 27020/udp

echo "$SCRIPTNAME Zapora skonfigurowana (27015 + 27020)."

# ============================================================
# 2. Architektura i zależności
# ============================================================

echo ""
echo "$SCRIPTNAME [2/4] Zmieniam architekturę oraz pobieram wymagane biblioteki..."

dpkg --add-architecture i386
apt update && apt upgrade -y

apt install -y \
    libsdl2-2.0-0:i386 libstdc++6:i386 libgcc-s1:i386 zlib1g:i386 \
    unzip wget screen tmux base-files \
    binutils bsdmainutils bzip2 lib32gcc-s1 lib32stdc++6 pigz steamcmd \
    dotnet-runtime-8.0 libicu-dev patchelf curl jq

echo "$SCRIPTNAME Zależności zainstalowane."

# ============================================================
# 3. Tworzenie użytkownika
# ============================================================

echo ""
echo "$SCRIPTNAME [3/4] Tworzenie użytkownika ${SERVER_USER}..."

if ! id "${SERVER_USER}" &>/dev/null; then
    useradd -m -s /bin/bash "${SERVER_USER}"
    echo "${SERVER_USER}:${SERVER_PASS}" | chpasswd
    echo "$SCRIPTNAME Użytkownik '${SERVER_USER}' został utworzony."
else
    echo "$SCRIPTNAME Użytkownik '${SERVER_USER}' już istnieje — pomijam tworzenie."
    # Aktualizujemy hasło nawet jeśli użytkownik istnieje
    echo "${SERVER_USER}:${SERVER_PASS}" | chpasswd
    echo "$SCRIPTNAME Hasło użytkownika '${SERVER_USER}' zostało zaktualizowane."
fi

# ============================================================
# 4. Instalacja CS2 + pluginów (jako użytkownik cs2)
# ============================================================

echo ""
echo "$SCRIPTNAME [4/4] Instalacja CS2 i pluginów (jako ${SERVER_USER})..."

# Kopiujemy skrypt pluginów do katalogu domowego użytkownika przed su
PLUGINS_SCRIPT_SRC="$(dirname "$(realpath "$0")")/install_plugins.sh"
PLUGINS_SCRIPT_DST="${SERVER_HOME}/install_plugins.sh"

if [ ! -f "$PLUGINS_SCRIPT_SRC" ]; then
    echo "$SCRIPTNAME BŁĄD: Nie znaleziono install_plugins.sh obok tego skryptu."
    echo "$SCRIPTNAME Oczekiwano: $PLUGINS_SCRIPT_SRC"
    exit 1
fi

cp "$PLUGINS_SCRIPT_SRC" "$PLUGINS_SCRIPT_DST"
chown "${SERVER_USER}:${SERVER_USER}" "$PLUGINS_SCRIPT_DST"
chmod +x "$PLUGINS_SCRIPT_DST"

# UWAGA: heredoc bez apostrofów — zmienne zewnętrzne są rozwijane
su - "${SERVER_USER}" << EOF

set -euo pipefail

SCRIPTNAME="${SCRIPTNAME}"
SERVER_ROOT="${SERVER_ROOT}"
CSGO_DIR="${CSGO_DIR}"

# --- Instalacja LinuxGSM i CS2 ---

echo "\$SCRIPTNAME Pobieram LinuxGSM..."
curl -Lo linuxgsm.sh https://linuxgsm.sh
chmod +x linuxgsm.sh
bash linuxgsm.sh cs2server

echo "\$SCRIPTNAME Instaluję CS2 przez LinuxGSM..."
yes | ./cs2server install || {
    echo "\$SCRIPTNAME BŁĄD: Instalacja CS2 nie powiodła się."
    exit 1
}

echo "\$SCRIPTNAME CS2 zainstalowany pomyślnie."

# Sprawdzenie czy katalog gry istnieje po instalacji
if [ ! -d "\$CSGO_DIR" ]; then
    echo "\$SCRIPTNAME BŁĄD: Katalog \$CSGO_DIR nie istnieje po instalacji CS2."
    echo "\$SCRIPTNAME Sprawdź logi LinuxGSM i uruchom instalację ponownie."
    exit 1
fi

# --- Instalacja pluginów przez osobny skrypt ---
echo "\$SCRIPTNAME Uruchamiam install_plugins.sh..."
bash ~/install_plugins.sh

echo ""
echo "=================================================="
echo "\$SCRIPTNAME Instalacja zakończona pomyślnie!"
echo "=================================================="
echo ""
echo "Otwarte porty:"
echo "  27015 TCP/UDP — CS2 (główny)"
echo "  27020 TCP/UDP — GOTV (dla eNStudios)"

EOF

# ============================================================
# Podsumowanie (poziom root)
# ============================================================

echo ""
echo "$SCRIPTNAME Skrypt zakończył działanie."
echo "$SCRIPTNAME Użytkownik serwera: ${SERVER_USER}"
echo "$SCRIPTNAME Katalog serwera:    ${SERVER_ROOT}"
echo "$SCRIPTNAME Pamiętaj o teście technicznym 07.06 przed eventem!"
