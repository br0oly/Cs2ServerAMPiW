#!/bin/bash
set -euo pipefail

# ============================================================
#  CDV_CS2Server_PLUGINS — AMPiW CS2 2026
#  Instalacja pluginów: Metamod + CounterStrikeSharp + MatchZy
#
#  Uruchamiać jako użytkownik cs2 (NIE root):
#    bash install_plugins.sh
#
#  Przydatne też przy reinstalacji pluginów po aktualizacji CS2
#  (runbook sekcja 10: "Pluginy nie działają po aktualizacji CS2")
# ============================================================

SCRIPTNAME="[CDV_CS2_PLUGINS]"

# --- Wersje pluginów (zmieniaj tutaj przy aktualizacjach) ---
METAMOD_VERSION="2.0.0-git1401"
METAMOD_FILE="mmsource-2.0.0-git1401-linux.tar.gz"
METAMOD_URL="https://github.com/alliedmodders/metamod-source/releases/download/2.0.0.1401/${METAMOD_FILE}"

CSS_VERSION="1.0.368"
CSS_FILE="counterstrikesharp-with-runtime-linux-${CSS_VERSION}.zip"
CSS_URL="https://github.com/roflmuffin/CounterStrikeSharp/releases/download/v${CSS_VERSION}/${CSS_FILE}"

MATCHZY_VERSION="0.8.15"
MATCHZY_FILE="MatchZy-${MATCHZY_VERSION}.zip"
MATCHZY_URL="https://github.com/shobhit-pathak/MatchZy/releases/download/${MATCHZY_VERSION}/${MATCHZY_FILE}"

# --- Ścieżki zgodne z runbookiem ---
SERVER_ROOT="/home/cs2/serverfiles"
CSGO_DIR="${SERVER_ROOT}/game/csgo"
ADDONS_DIR="${CSGO_DIR}/addons"
VALVE_BIN="${SERVER_ROOT}/game/bin/linuxsteamrt64"
GAMEINFO="${CSGO_DIR}/gameinfo.gi"

# ============================================================
# 0. Sprawdzenie uprawnień i środowiska
# ============================================================

if [ "$EUID" -eq 0 ]; then
    echo "$SCRIPTNAME BŁĄD: Nie uruchamiaj tego skryptu jako root."
    echo "Zaloguj się jako użytkownik cs2:  su - cs2"
    echo "Następnie uruchom:                bash install_plugins.sh"
    exit 1
fi

if [ "$(whoami)" != "cs2" ]; then
    echo "$SCRIPTNAME OSTRZEŻENIE: Skrypt uruchomiony jako '$(whoami)', oczekiwano 'cs2'."
    read -r -p "Kontynuować mimo to? [t/N]: " confirm
    if [[ ! "$confirm" =~ ^[tT]$ ]]; then
        echo "$SCRIPTNAME Przerwano."
        exit 1
    fi
fi

if [ ! -d "$CSGO_DIR" ]; then
    echo "$SCRIPTNAME BŁĄD: Katalog $CSGO_DIR nie istnieje."
    echo "$SCRIPTNAME Upewnij się, że CS2 jest zainstalowany przed instalacją pluginów."
    exit 1
fi

if [ ! -f "$GAMEINFO" ]; then
    echo "$SCRIPTNAME BŁĄD: Plik $GAMEINFO nie istnieje."
    echo "$SCRIPTNAME Upewnij się, że instalacja CS2 zakończyła się poprawnie."
    exit 1
fi

echo ""
echo "$SCRIPTNAME Rozpoczynam instalację pluginów..."
echo "$SCRIPTNAME Katalog docelowy: $CSGO_DIR"
echo ""

cd "$CSGO_DIR"

# ============================================================
# 1. Metamod:Source
# ============================================================

echo "$SCRIPTNAME [1/3] Pobieram Metamod:Source ${METAMOD_VERSION}..."
wget -q --show-progress "$METAMOD_URL"
tar -xzf "$METAMOD_FILE"
rm "$METAMOD_FILE"
echo "$SCRIPTNAME Metamod zainstalowany."

# ============================================================
# 2. CounterStrikeSharp
# ============================================================

echo ""
echo "$SCRIPTNAME [2/3] Pobieram CounterStrikeSharp v${CSS_VERSION}..."
wget -q --show-progress "$CSS_URL"
unzip -q "$CSS_FILE"
rm "$CSS_FILE"
echo "$SCRIPTNAME CounterStrikeSharp zainstalowany."

# ============================================================
# 3. MatchZy
# ============================================================

echo ""
echo "$SCRIPTNAME [3/3] Pobieram MatchZy v${MATCHZY_VERSION}..."
wget -q --show-progress "$MATCHZY_URL"
unzip -q "$MATCHZY_FILE"
rm "$MATCHZY_FILE"
echo "$SCRIPTNAME MatchZy zainstalowany."

# ============================================================
# 4. Uprawnienia
# ============================================================

echo ""
echo "$SCRIPTNAME Ustawiam uprawnienia w katalogu addons..."
chmod -R +x "$ADDONS_DIR"
chmod -R 755 "$ADDONS_DIR"

# ============================================================
# 5. Modyfikacja gameinfo.gi
# Wymagana linia dla Metamod (runbook sekcja 1 i sekcja 10)
# ============================================================

echo ""
echo "$SCRIPTNAME Sprawdzam gameinfo.gi..."

if grep -q "csgo/addons/metamod" "$GAMEINFO"; then
    echo "$SCRIPTNAME gameinfo.gi już zawiera wpis metamod — pomijam."
else
    echo "$SCRIPTNAME Dodaję wpis metamod do gameinfo.gi..."
    sed -i 's/Game_LowViolence\tcsgo_lv/Game_LowViolence\tcsgo_lv\n\t\t\tGame\tcsgo\/addons\/metamod/' "$GAMEINFO"
    echo "$SCRIPTNAME gameinfo.gi zaktualizowany."
fi

# ============================================================
# 6. Plik VDF dla CounterStrikeSharp
# ============================================================

VDF_FILE="$ADDONS_DIR/metamod/counterstrikesharp.vdf"
mkdir -p "$ADDONS_DIR/metamod"

cat > "$VDF_FILE" << 'VDF_EOF'
"Plugin"
{
	"file"	"addons/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp"
}
VDF_EOF

echo "$SCRIPTNAME Plik VDF CounterStrikeSharp zapisany: $VDF_FILE"

# ============================================================
# 7. Łatki systemowe (patchelf) dla counterstrikesharp.so
# ============================================================

CSS_SO="$ADDONS_DIR/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp.so"

echo ""
echo "$SCRIPTNAME Aplikuję łatki patchelf..."

if [ -f "$CSS_SO" ]; then
    if ! command -v patchelf &>/dev/null; then
        echo "$SCRIPTNAME OSTRZEŻENIE: patchelf nie jest zainstalowany — pomijam łatki."
        echo "$SCRIPTNAME Zainstaluj patchelf jako root: apt install patchelf"
    else
        patchelf --set-rpath "$VALVE_BIN" "$CSS_SO"
        patchelf --clear-execstack "$CSS_SO"
        echo "$SCRIPTNAME Łatki patchelf zastosowane."
    fi
else
    echo "$SCRIPTNAME OSTRZEŻENIE: Plik $CSS_SO nie istnieje — patchelf pominięty."
fi

# ============================================================
# Podsumowanie i weryfikacja
# ============================================================

echo ""
echo "=================================================="
echo "$SCRIPTNAME Instalacja pluginów zakończona!"
echo "=================================================="
echo ""
echo "Zainstalowane:"
echo "  Metamod:Source        ${METAMOD_VERSION}"
echo "  CounterStrikeSharp    v${CSS_VERSION}"
echo "  MatchZy               v${MATCHZY_VERSION}"
echo ""
echo "Weryfikacja po uruchomieniu serwera (w konsoli CS2):"
echo "  meta list        — powinien pokazać CounterStrikeSharp"
echo "  css_plugins list — powinien pokazać MatchZy by WD-"
echo ""
echo "Jeśli po aktualizacji CS2 pluginy przestały działać:"
echo "  1. Uruchom ten skrypt ponownie (nadpisze pliki pluginów)"
echo "  2. Sprawdź czy linia metamod jest w gameinfo.gi:"
echo "     grep 'addons/metamod' $GAMEINFO"
