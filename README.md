# AMPiW CS2 2026 - Dokumentacja i Zarządzanie Serwerem Turniejowym
==================================================================

Repozytorium zawiera kompletny ekosystem skryptów automatyzujących, plików konfiguracyjnych oraz predefiniowanych szablonów meczowych MatchZy (*.json) przygotowanych pod turniej esportowy AMPiW CS2 2026 na uczelni Collegium Da Vinci w Poznaniu. 

Struktura została zoptymalizowana pod kątem lokalnej sieci fizycznej (LAN) w sali A.003, integracji z systemami transmisji (Live Hud Manager / Scout AI) oraz sprawnego sędziowania za pomocą RCON i wtyczki CounterStrikeSharp.

---

## Metadane Operacyjne Turnieju
* Data eventu: 09.06.2026 (wtorek)
* Lokalizacja: Sala A.003, Collegium Da Vinci, Poznań
* Silnik wtyczek: CounterStrikeSharp
* Menedżer meczów: MatchZy 0.8.15
* System Veto: Fizyczny (ustny z kapitanami, sędzia ręcznie wprowadza mapy do JSON)

---

## 1. Architektura Sieciowa i Porty

Serwer uruchamiany jest bezpośrednio na fizycznym komputerze w sali A.003 (brak maszyn wirtualnych czy VPS).

| Komponent | Port | Protokół | Przeznaczenie |
| :--- | :--- | :--- | :--- |
| Serwer CS2 Game | 27015 | TCP/UDP | Główny kanał rozgrywki dla 10 graczy |
| GOTV Live Broadcaster | 27020 | UDP | Przekaz z 0s delay dla PC Obserwatora i LHM Scout AI |
| Logaddress GSI | 27115 | UDP | Transmisja logów gry do systemu HUD realizatora |

---

## 2. Struktura Projektu i Katalog Docelowy

Poniższa tabela przedstawia mapowanie plików z repozytorium do struktury katalogowej serwera LinuxGSM (`/home/cs2/`):

| Nazwa pliku | Ścieżka docelowa na serwerze | Opis |
| :--- | :--- | :--- |
| autosetup.sh | ~/ | Skrypt instalacyjny (baza, UFW, LinuxGSM, zależności .NET 8.0) |
| install_plugins.sh | ~/ | Skrypt pobierający i rozpakowujący najnowsze wersje Metamod i CSSharp |
| uninstall_plugins.sh | ~/ | Skrypt bezpiecznie czyszczący folder addons przed aktualizacją pluginów |
| server.cfg | ~/serverfiles/game/csgo/cfg/ | Główny plik konfiguracyjny serwera (LAN, GOTV, RCON, raty) |
| prac.cfg | ~/serverfiles/game/csgo/cfg/ | Plik konfiguracji treningowej / swobodnej rozgrzewki przedmeczowej |
| admins.json | ~/serverfiles/game/csgo/addons/counterstrikesharp/configs/ | Plik uprawnień i flag administratorów (SteamID64 sędziów) |
| *.json | ~/serverfiles/game/csgo/cfg/MatchZy/ | Szablony składów drużyn i harmonogramu meczów |

---

## 3. Skrypty Automatyzacji (Katalog Domowy)

### autosetup.sh
Główny skrypt uruchamiany z poziomu użytkownika root na czystym systemie Ubuntu Server w celu przygotowania środowiska.

```bash
#!/bin/bash
# Użycie: sudo bash autosetup.sh "HasloDlaUzytkownikaCS2"
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Blad: Skrypt musi byc uruchomiony jako root!"
  exit 1
fi

CS2_PASSWORD=${1:-"CDV_AMPiW_2026"}

echo "=== Aktualizacja systemu i instalacja zaleznosci ==="
apt-get update && apt-get upgrade -y
apt-get install -y lib32gcc-s1 lib32stdc++6 libc6-i386 libgdiplus wget curl tmux ufw sudo

echo "=== Konfiguracja Zapory Sieciowej UFW ==="
ufw allow 22/tcp
ufw allow 27015/tcp
ufw allow 27015/udp
ufw allow 27020/udp
ufw allow 27115/udp
ufw --force enable

echo "=== Tworzenie dedykowanego uzytkownika cs2 ==="
if ! id "cs2" &>/dev/null; then
    useradd -m -s /bin/bash cs2
    echo "cs2:$CS2_PASSWORD" | chpasswd
    usermod -aG sudo cs2
fi

echo "=== Instalacja .NET Runtime 8.0 dla CounterStrikeSharp ==="
apt-get install -y dotnet-runtime-8.0

echo "=== Wdrozenie ukonczone. Przelacz sie na uzytkownika cs2 ==="
uninstall_plugins.sh
Skrypt dla użytkownika cs2 pozwalający na bezpieczną dezinstalację plików binarnych pluginów w przypadku konieczności wgrania nowszych wersji w trakcie turnieju. Nie usuwa konfiguracji w cfg/ ani wpisu w gameinfo.gi.

Bash
#!/bin/bash
set -euo pipefail

SCRIPTNAME="[CS2_PLUGIN_UNINSTALLER]"
CSGO_DIR="${HOME}/serverfiles/game/csgo"
ADDONS_DIR="${CSGO_DIR}/addons"

echo "$SCRIPTNAME Rozpoczynam czyszczenie folderu addons..."

if [ -f "${HOME}/cs2server" ]; then
    echo "$SCRIPTNAME Zatrzymuje serwer za pomoca LinuxGSM..."
    ./cs2server stop || echo "$SCRIPTNAME Ostrzezenie: Serwer mogl byc wylaczony."
else
    echo "$SCRIPTNAME BLAD: Nie znaleziono menedzera cs2server!"
    exit 1
fi

if [ -d "$ADDONS_DIR" ]; then
    echo "$SCRIPTNAME Usuwam katalog addons: $ADDONS_DIR"
    rm -rf "$ADDONS_DIR"
    echo "$SCRIPTNAME Katalog addons zostal wyczyszczony."
else
    echo "$SCRIPTNAME Katalog addons nie istnial. Pomijam."
fi

echo "=== Serwer gotowy na wgranie nowych pluginow ==="
```
4. Pliki Konfiguracyjne Serwera
server.cfg
Lokalizacja: /home/cs2/serverfiles/game/csgo/cfg/server.cfg

Ini, TOML
// Podstawowe ustawienia serwera LAN
hostname          "AMPiW CS2 2026 - CDV Poznan"
sv_password       ""              // Brak hasla wejsciowego dla graczy na LAN
sv_cheats         0
sv_lan            1               // Wymuszenie trybu sieci lokalnej

// Zabezpieczenie konsoli zdalnej
rcon_password     "ZMIEN_TO_NA_BEZPIECZNE_HASLO"

// Konfiguracja GOTV dla PC Obserwatora i HUD (0s opoznienia)
tv_enable         1
tv_port           27020
tv_delay          0               // 0s delay dla live streamu
tv_maxclients     5
tv_advertise_watchable 1

// Parametry rozgrywki turniejowej MR12
mp_freezetime     15
mp_round_restart_delay 5
mp_maxrounds      24[cite: 1]
mp_overtime_enable 1[cite: 1]
mp_overtime_maxrounds 6[cite: 1]

// Optymalizacja pakietow sieciowych pod switche LAN[cite: 1]
sv_minrate        0[cite: 1]
sv_maxrate        0[cite: 1]
sv_mincmdrate     64[cite: 1]
sv_maxcmdrate     128[cite: 1]
sv_maxroutable    1200

// Integracja z Live Hud Manager[cite: 1]
log               on[cite: 1]
logaddress_add    "192.168.1.XX:27115" // Zmien na IP stanowiska realizatora streamu[cite: 1]
prac.cfg
Lokalizacja: /home/cs2/serverfiles/game/csgo/cfg/prac.cfg
Służy do uruchomienia nieskończonej rozgrzewki przed meczem oficjalnym, dając graczom czas na konfigurację sprzętu.

Ini, TOML
sv_cheats 1
mp_warmuptime 9999
mp_warmup_start
mp_buy_anywhere 1
mp_buytime 6000
mp_maxmoney 60000
mp_startmoney 60000
sv_infinite_ammo 1
ammo_grenade_limit_total 5
mp_restartgame 1
say ">>> URUCHOMIONO TRYB TRENINGOWY - ROZGRZEWKA GRACZY <<<"
admins.json
Lokalizacja: /home/cs2/serverfiles/game/csgo/addons/counterstrikesharp/configs/admins.json
Nadaje pełne uprawnienia do sędziowania meczów z poziomu czatu w grze.

JSON
{
  "Sedzia_Glowny": {
    "identity": "7656119XXXXXXXXXX",
    "flags": [
      "@css/root"
    ]
  },
  "Sedzia_Asystent": {
    "identity": "7656119YYYYYYYYYY",
    "flags": [
      "@css/root"
    ]
  }
}
5. Szablon Konfiguracji Meczu MatchZy (.json)
Pliki tworzone przed turniejem na podstawie zebranych SteamID64 graczy[cite: 1]. Pola maplist oraz map_sides są uzupełniane przez sędziego niezwłocznie po zakończeniu fazy veto[cite: 1].

Lokalizacja pliku: /home/cs2/serverfiles/game/csgo/cfg/MatchZy/final_cdv_vs_pp.json
```
JSON
{
  "num_maps": 1,[cite: 1]
  "maplist": [
    "de_mirage"[cite: 1]
  ],
  "map_sides": [
    "team2_ct"[cite: 1]
  ],
  "clinch_series": true,[cite: 1]
  "team1": {
    "name": "Collegium Da Vinci",[cite: 1]
    "tag": "CDV",[cite: 1]
    "players": {
      "76561190000000001": "gracz1",
      "76561190000000002": "gracz2",
      "76561190000000003": "gracz3",
      "76561190000000004": "gracz4",
      "76561190000000005": "gracz5"
    }
  },
  "team2": {
    "name": "Politechnika Poznanska",[cite: 1]
    "tag": "PP",[cite: 1]
    "players": {
      "76561190000000006": "gracz6",
      "76561190000000007": "gracz7",
      "76561190000000008": "gracz8",
      "76561190000000009": "gracz9",
      "76561190000000010": "gracz10"
    }
  },
  "matchid": "final_bo1",[cite: 1]
  "series_can_clinch": true,[cite: 1]
  "wingman": false,[cite: 1]
  "knifeBefore": false,[cite: 1]
  "playout": false,[cite: 1]
  "scrim": false[cite: 1]
}
```
Lista Stringów Map (Do wpisania w JSON):
Mirage: de_mirage

[cite: 1]

Nuke: de_nuke

[cite: 1]

Inferno: de_inferno

[cite: 1]

Vertigo: de_vertigo

[cite: 1]

Ancient: de_ancient

[cite: 1]

Anubis: de_anubis

[cite: 1]

Dust 2: de_dust2

[cite: 1]

Train: de_train

[cite: 1]

6. Procedura Veto i Operacji Meczowych (Krok po Kroku)
[UWAGA] Aby uniknąć błędu silnika gry "Entity system yet is not initialized" i wyłączenia procesu serwera, sędzia zobowiązany jest zachować kolejność działań: najpierw załadowanie mapy, potem wczytanie konfiguracji meczu.

Head Admin przeprowadza fizyczne veto w sali z kapitanami drużyn[cite: 1].

Sędzia serwerowy obserwuje wynik veto, otwiera odpowiedni plik .json i wpisuje wybrane mapy w sekcji maplist[cite: 1].

Sędzia wprowadza decyzję stron do map_sides[cite: 1]. Jeśli Team 1 wybrał mapę, Team 2 wybiera stronę początkową (np. "team2_ct")[cite: 1]. W przypadku mapy typu decider, należy wpisać wartość "knife"[cite: 1].

Sędzia zapisuje plik JSON i wymusza zmianę mapy w konsoli serwera[cite: 1]:

Plaintext
   changelevel de_mirage
Po pełnym załadowaniu mapy (odczekaniu około 10 sekund), sędzia aktywuje mecz komendą[cite: 1]:

Plaintext
   matchzy_loadmatch cfg/MatchZy/final_cdv_vs_pp.json
Sędzia zgłasza gotowość systemu realizatorowi streamu poprzez system łączności Hollyland[cite: 1].

Gracze wchodzą na serwer. Po wpisaniu przez nich komendy !ready w czacie gry, MatchZy automatycznie rozpoczyna oficjalne starcie[cite: 1].

7. Komendy Administracyjne i Zarządzanie Kryzysowe
Komendy dla Sędziów (Wpisywane bezpośrednio w konsoli bez przedrostka rcon)
matchzy_forceready - Wymuszenie statusu gotowości obu zespołów i natychmiastowe rozpoczęcie meczu[cite: 1].

matchzy_pause - Aktywacja nieskończonej pauzy technicznej sędziego[cite: 1].

matchzy_unpause - Zdjęcie pauzy technicznej i wznowienie rozgrywki[cite: 1].

get5_status - Wyświetlenie aktualnego statusu konfiguracyjnego MatchZy[cite: 1].

get5_endmatch - Przedwczesne zakończenie bieżącej mapy z zachowaniem wyniku[cite: 1].

matchzy_listbackups - Wyświetlenie listy dostępnych plików kopii zapasowych rund[cite: 1].

Procedura Awaryjna: Przywracanie rundy po awarii sprzętu (Crash komputera gracza)
MatchZy automatycznie wykonuje zrzut stanu gry na końcu każdej rundy do katalogu /game/csgo/MatchZy/backup/[cite: 1].

Sędzia aktywuje pauzę techniczną wpisując w konsoli: matchzy_pause[cite: 1].

Po rozwiązaniu problemu technicznego, sędzia sprawdza listę kopii zapasowych za pomocą matchzy_listbackups[cite: 1].

Przywrócenie stanu z początku rundy, w której wystąpiła awaria, następuje poprzez komendę[cite: 1]:

Plaintext
   matchzy_loadbackup MatchZy_final_bo1_round14.cfg
Po załadowaniu backupu sędzia wznawia mecz komendą: matchzy_unpause[cite: 1].

8. Checklist Startowy dla Administratora (W Dniu Eventu)
[ ] Proces serwera CS2 pomyślnie uruchomiony w sesji tmux.

[ ] Logi startowe potwierdzają załadowanie modułów CounterStrikeSharp oraz MatchZy[cite: 1].

[ ] Wynik komendy tv_status wykazuje aktywność serwera GOTV na porcie 27020 z opóźnieniem 0s[cite: 1].

[ ] Adres IPv4 serwera zweryfikowany poleceniem ipconfig lub ip addr i przekazany Marszałkom sali w celu umieszczenia na stanowiskach graczy[cite: 1].

[ ] PC Obserwatora realizatora streamu połączył się z adresem GOTV i potwierdził odbiór obrazu[cite: 1].

[ ] Zweryfikowano poprawność SteamID sędziów w pliku admins.json.

[ ] Sprawdzono wolną przestrzeń dyskową serwera (wymagane minimum 5 GB wolnego miejsca na zapis plików demonstracyjnych .dem)[cite: 1].

[ ] Przygotowano fizyczny nośnik pendrive do natychmiastowej archiwizacji dem po zakończeniu każdego etapu turnieju[cite: 1].
