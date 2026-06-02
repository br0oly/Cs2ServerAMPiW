#!/bin/bash
set -euo pipefail

# ============================================================
#  CDV_CS2Server_UNINSTALL_PLUGINS — AMPiW CS2 2026
#  Czyszczenie folderu addons przed aktualizacją wtyczek
#  ZACHOWUJE: server.cfg, mecze *.json oraz wpis w gameinfo.gi
#
#  Użycie: bash ~/uninstall_plugins.sh (Uruchamiaj jako użytkownik cs2)
# ============================================================

SCRIPTNAME="[CS2_PLUGIN_UNINSTALLER]"
CSGO_DIR="${HOME}/serverfiles/game/csgo"
ADDONS_DIR="${CSGO_DIR}/addons"

echo "$SCRIPTNAME Rozpoczynam czyszczenie wtyczek przed aktualizacją..."

# 1. Wyłączenie serwera (nie można usuwać plików w trakcie działania gry)
if [ -f "${HOME}/cs2server" ]; then
    echo "$SCRIPTNAME Zatrzymuję serwer CS2 za pomocą LinuxGSM..."
    ./cs2server stop || echo "$SCRIPTNAME Ostrzeżenie: Serwer mógł być już wyłączony."
else
    echo "$SCRIPTNAME BŁĄD: Nie znaleziono skryptu cs2server w katalogu domowym!"
    exit 1
fi

# 2. Usunięcie starego katalogu addons (Metamod + CSSharp + wtyczki)
if [ -d "$ADDONS_DIR" ]; then
    echo "$SCRIPTNAME Usuwam stary katalog addons (${ADDONS_DIR})..."
    rm -rf "$ADDONS_DIR"
    echo "$SCRIPTNAME Stare pliki wtyczek zostały pomyślnie usunięte."
else
    echo "$SCRIPTNAME Informacja: Katalog addons był już pusty — pomijam krok."
fi

# ============================================================
# Podsumowanie
# ============================================================

echo ""
echo "=================================================="
echo "$SCRIPTNAME Folder addons został wyczyszczony!"
echo "=================================================="
echo "Wpis w gameinfo.gi oraz konfiguracje turniejowe"
echo "zostały zachowane."
echo ""
echo "Serwer jest w pełni przygotowany na wgranie nowej"
echo "paczki pluginów."
echo "=================================================="
