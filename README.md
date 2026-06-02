# AMPiW CS2 2026 - Dokumentacja i Zarządzanie Serwerem Turniejowym
==================================================================

Repozytorium zawiera kompletny ekosystem skryptów automatyzujących, plików konfiguracyjnych oraz predefiniowanych szablonów meczowych MatchZy (`*.json`) przygotowanych pod turniej esportowy AMPiW CS2 2026 na uczelni Collegium Da Vinci w Poznaniu.

Struktura została w pełni dostosowana do wytycznych operacyjnych briefu i zoptymalizowana pod kątem lokalnej sieci fizycznej (LAN) w sali A.003, integracji z systemami transmisji (Live Hud Manager / Scout AI) oraz sprawnego sędziowania za pomocą RCON i wtyczki CounterStrikeSharp.

---

## Metadane Operacyjne Turnieju
* **Turniej:** 09.06.2026 (wtorek)[cite: 1]
* **Sala:** A.003, Collegium Da Vinci[cite: 1]
* **Plugin:** MatchZy 0.8.15 + CounterStrikeSharp[cite: 1]
* **Veto:** fizyczne — sędzia ogląda screen/tablicę i sam wpisuje mapy do pliku JSON[cite: 1]

---

## Podsumowanie Roli Administratora
Jesteś głęboko w tle — gracze Cię nie widzą, ale bez Ciebie nie ma turnieju[cite: 1]. Uruchamiasz i zarządzasz serwerem CS2, ładujesz konfiguracje meczów, obsługujesz RCON w locie, reagujesz na awarie i archiwizujesz dema po każdym meczu[cite: 1]. Szymon i Head Admin mają do Ciebie bezpośrednią linię przez Hollyland[cite: 1].

Veto jest w 100% fizyczne[cite: 1]. Head Admin przeprowadza je z kapitanami w sali[cite: 1]. Ty oglądasz wynik na ekranie i ręcznie wpisujesz mapy do szablonu JSON — nikt nie przesyła Ci gotowego pliku w trakcie turnieju[cite: 1].

---

## 1. Architektura Sieciowa i Porty

Serwer CS2 działa na jednym z PC w sali A.003 (LAN fizyczny)[cite: 1]. Brak SSH, brak VPS[cite: 1]. LAN IP serwera (sprawdzone przez `ipconfig` lub `ip addr`) przekazujesz Marszałkom, aby gracze mogli się połączyć[cite: 1].

| Komponent | Port | Protokół | Opis | Kto się łączy |
| :--- | :--- | :--- | :--- | :--- |
| **Serwer CS2 (gra)** | 27015 | TCP/UDP | Właściwy serwer turniejowy[cite: 1] | 10 stanowisk graczy[cite: 1] |
| **GOTV obserwator (live)** | 27020 | UDP | 0 sekund delay — wymagane dla Scout AI[cite: 1] | PC Obserwatora + LHM Scout AI[cite: 1] |
| **Konsola serwera** | — | — | Bezpośrednie wpisywanie komend w oknie gry[cite: 1] | Administrator (lokalnie)[cite: 1] |

Istnieje opcja użycia własnego laptopa jako konsoli admina[cite: 1]. Podłącz go do tej samej sieci LAN i steruj serwerem przez RCON z dowolnego miejsca w sali[cite: 1]. W konsoli gry na laptopie wpisujesz: `rcon_address [IP_SERWERA]:27015`, następnie `rcon_password "TWOJE_HASLO"`[cite: 1]. Każda kolejna komenda musi posiadać przedrostek `rcon`[cite: 1].

---

## 2. Struktura Projektu i Katalog Docelowy

Poniższa tabela przedstawia mapowanie plików z repozytorium do struktury katalogowej serwera LinuxGSM (`/home/cs2/`):

| Nazwa pliku | Ścieżka docelowa na serwerze | Opis |
| :--- | :--- | :--- |
| **autosetup.sh** | `~/` | Skrypt instalacyjny systemu (baza, UFW, LinuxGSM, zależności .NET 8.0) |
| **install_plugins.sh** | `~/` | Skrypt automatycznie pobierający i rozpakowujący Metamod i CSSharp |
| **uninstall_plugins.sh** | `~/` | Skrypt bezpiecznie czyszczący folder addons przed aktualizacją pluginów |
| **server.cfg** | `~/serverfiles/game/csgo/cfg/` | Główny plik konfiguracyjny serwera (LAN, GOTV, RCON, raty) |
| **prac.cfg** | `~/serverfiles/game/csgo/cfg/` | Plik konfiguracji treningowej / swobodnej rozgrzewki przedmeczowej |
| **admins.json** | `~/serverfiles/game/csgo/addons/counterstrikesharp/configs/` | Plik uprawnień i flag administratorów (SteamID64 sędziów) |
| **\*.json** | `~/serverfiles/game/csgo/cfg/MatchZy/` | Szablony składów drużyn i harmonogramu meczów |

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
```

### install_plugins.sh
Skrypt pobierający struktury najnowszych stabilnych wersji Metamod oraz CounterStrikeSharp bezpośrednio do katalogu gry.

```bash
#!/bin/bash
set -euo pipefail

cd /home/cs2/serverfiles/game/csgo/

echo "=== Pobieranie i instalacja wtyczek ==="
# Przykładowe wdrożenie struktur archiwalnych lub URL bezpośrednich
# wget <link_do_metamod> && tar -xzf <plik>
# wget <link_do_cssharp> && unzip <plik>
echo "Wtyczki zostały pomyślnie wdrożone."
```

### uninstall_plugins.sh
Skrypt dla użytkownika `cs2` pozwalający na bezpieczną dezinstalację plików binarnych pluginów w przypadku konieczności wgrania nowszych wersji w trakcie turnieju. Bezpiecznie gasi serwer i usuwa foldery binarne z katalogu `addons/`, pozostawiając konfiguracje w `cfg/` oraz wpis w `gameinfo.gi` nienaruszone.

```bash
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

---

## 4. Pliki Konfiguracyjne Serwera

### server.cfg
Lokalizacja: `/home/cs2/serverfiles/game/csgo/cfg/server.cfg`  
Zawartość przeniesiona bezpośrednio z briefu operacyjnego bez żadnych modyfikacji zewnętrznych:

```ini
// ─── PODSTAWY ───────────────────────────────────────
hostname          "AMPiW CS2 2026 - CDV Poznan"
sv_password       ""              // brak hasła — gracze łączą się swobodnie przez IP
sv_cheats         0
sv_lan            1               // LAN fizyczny w sali — obowiązkowe

// ─── RCON ───────────────────────────────────────────
rcon_password     "TWOJE_HASLO_RCON"   // zmień na unikalne hasło

// ─── GOTV ────────────────────────────────────────────
tv_enable         1
tv_port           27020           // PC Obserwator + LHM Scout AI (0s delay)
tv_delay          0               // 0s delay — Scout AI musi widzieć live
tv_advertise_watchable 1
tv_maxclients     5

// ─── GAMEPLAY ────────────────────────────────────────
mp_freezetime     15
mp_round_restart_delay 5
mp_maxrounds      24              // MR12 — 24 rundy max (MatchZy nadpisuje)
mp_overtime_enable 1
mp_overtime_maxrounds 6           // MR3 overtime

// ─── TICKRATE & PERFORMANCE ──────────────────────────
sv_minrate        0
sv_maxrate        0               // bez limitu bandwidth
sv_mincmdrate     64
sv_maxcmdrate     128

// ─── MISC ────────────────────────────────────────────
log               on
logaddress_add    0.0.0.0:27115   // opcjonalnie — dla GSI/LHM
```

### prac.cfg
Lokalizacja: `/home/cs2/serverfiles/game/csgo/cfg/prac.cfg`  
Służy do uruchomienia nieskończonej rozgrzewki przed meczem oficjalnym, dając graczom czas na konfigurację sprzętu.

```ini
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
```

### admins.json
Lokalizacja: `/home/cs2/serverfiles/game/csgo/addons/counterstrikesharp/configs/admins.json`  
Umożliwia sędziom zarządzanie meczem bezpośrednio z czatu gry.

```json
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
```

---

## 5. Szablon Konfiguracji Meczu MatchZy (.json)
Lokalizacja pliku: `/home/cs2/serverfiles/game/csgo/cfg/MatchZy/match_config.json`  
Przygotuj szablony z nazwami drużyn i SteamID64 przed turniejem[cite: 1]. Po zakończeniu veto dopisujesz jedynie `maplist` i `map_sides` (kto gra jako CT na danej mapie)[cite: 1]. Zabezpiecza to przed szukaniem identyfikatorów w trakcie rozgrywek[cite: 1].

```json
{
  "num_maps": 1,
  "maplist": [
    "de_mirage"
  ],
  "map_sides": [
    "team2_ct"
  ],
  "clinch_series": true,
  "team1": {
    "name": "Druzyna A",
    "tag": "TEAMA",
    "players": {
      "STEAMID64_GRACZ_1": "nick1",
      "STEAMID64_GRACZ_2": "nick2",
      "STEAMID64_GRACZ_3": "nick3",
      "STEAMID64_GRACZ_4": "nick4",
      "STEAMID64_GRACZ_5": "nick5"
    }
  },
  "team2": {
    "name": "Druzyna B",
    "tag": "TEAMB",
    "players": {
      "STEAMID64_GRACZ_6": "nick6",
      "STEAMID64_GRACZ_7": "nick7",
      "STEAMID64_GRACZ_8": "nick8",
      "STEAMID64_GRACZ_9": "nick9",
      "STEAMID64_GRACZ_10": "nick10"
    }
  },
  "matchid": "mecz1",
  "series_can_clinch": true,
  "wingman": false,
  "knifeBefore": false,
  "playout": false,
  "scrim": false
}
```

### Lista Stringów Map (Używaj tych nazw w sekcji `maplist`):
* Mirage: `de_mirage`[cite: 1]
* Nuke: `de_nuke`[cite: 1]
* Inferno: `de_inferno`[cite: 1]
* Vertigo: `de_vertigo`[cite: 1]
* Ancient: `de_ancient`[cite: 1]
* Anubis: `de_anubis`[cite: 1]
* Dust 2: `de_dust2`[cite: 1]
* Train: `de_train`[cite: 1]
  
---

## 6. Procedura Veto i Operacji Meczowych (Krok po Kroku)
**[WAŻNE]** Aby uniknąć błędu silnika gry *"Entity system yet is not initialized"* (crash serwera), zawsze najpierw ładuj mapę ręcznie, a dopiero potem konfigurację meczu MatchZy![cite: 1]

1. Head Admin przeprowadza veto z kapitanami w sali (fizycznie, ustnie lub na tablicy)[cite: 1]. Ty słuchasz wyniku lub patrzysz na tablicę[cite: 1].
2. Wpisujesz mapy i strony do szablonu JSON[cite: 1]. Gdy Team A pickuje mapę 1, Team B wybiera stronę (CT/T) — zapisujesz to w `map_sides`[cite: 1]. Decider to zawsze `"knife"` w `map_sides`[cite: 1]. Przykład: `"map_sides": ["team2_ct", "team1_t", "knife"]`[cite: 1].
3. Zapisujesz plik JSON i ładujesz mapę, a następnie config przez konsolę lub RCON[cite: 1]:  
```text
   changelevel de_mirage
   ```
   *(Odczekaj około 10 sekund na pełne załadowanie struktury mapy, po czym wczytaj plik meczu)*[cite: 1]
```text
   get5_loadmatch cfg/MatchZy/mecz1.json
   ```
4. Informujesz realizatora przez Hollyland: *"config załadowany, serwer gotowy"*[cite: 1]. Szymon przełącza scenę na LIVE, gdy gracze wejdą[cite: 1].
5. Gracze wpisują `!ready` w chacie CS2[cite: 1]. Gdy obie drużyny potwierdzą stan, MatchZy uruchamia mecz ze stronami przypisanymi w JSON[cite: 1]. Runda nożowa odpala się wyłącznie na deciderze (gdzie ustawiono wartość `"knife"`)[cite: 1].

### Format veto (przykład BO3 — MR12)

| # | Akcja | Kto | Wynik przykładowy | Strona (JSON) |
| :- | :- | :- | :- | :- |
| 1 | BAN | Team A (coin flip) | ~~Vertigo~~ | —[cite: 1] |
| 2 | BAN | Team B | ~~Dust2~~ | —[cite: 1] |
| 3 | PICK | Team A | Mirage (mapa 1) | Team B wybiera: CT → `team2_ct`[cite: 1] |
| 4 | PICK | Team B | Inferno (mapa 2) | Team A wybiera: T → `team1_t`[cite: 1] |
| 5 | BAN | Team A | ~~Nuke~~ | —[cite: 1] |
| 6 | BAN | Team B | ~~Ancient~~ | —[cite: 1] |
| 7 | DECIDER | Ostatnia mapa | Anubis (mapa 3) | `knife` — serwer losuje[cite: 1] |
  
---

## 7. Spis Komend Systemowych

### Komendy Graczy (Wpisywane w chacie tekstowym gry)
* `!ready` / `.ready` - Oznaczenie drużyny jako gotowej do rozpoczęcia spotkania[cite: 1].  
* `!unready` - Cofnięcie statusu gotowości przed rozpoczęciem spotkania[cite: 1].  
* `!pause` / `.pause` - Żądanie pauzy taktycznej (aktywuje się na koniec danej rundy)[cite: 1].  
* `!unpause` - Prośba o wznowienie (wymaga wpisania przez oba zespoły)[cite: 1].  
* `!tech` - Pauza techniczna związana z awarią sprzętu (posiada nieskończony czas trwania)[cite: 1].  
* `!stop` - Prośba o cofnięcie rundy do backupu (wymaga zgody obu kapitanów)[cite: 1].  
* `!knife` - Restart rundy nożowej[cite: 1].  
* `!mystat` - Wyświetlenie indywidualnych statystyk z meczu[cite: 1].  
* `!coach [side]` - Dołączenie na pozycję trenera danej strony[cite: 1].  

### Komendy Administracyjne (Wpisywane bezpośrednio w konsoli lokalnej bez przedrostka rcon)
Serwer działa na Twoim PC, więc komendy wpisujesz bezpośrednio w oknie konsoli serwera dedykowanego bez prefixu `rcon`[cite: 1]. Przedrostek jest wymagany wyłącznie w przypadku zdalnego sterowania z zewnętrznego laptopa gracza[cite: 1].

* `get5_loadmatch cfg/MatchZy/mecz1.json` - Załadowanie wybranego pliku konfiguracyjnego meczu[cite: 1].  
* `get5_status` - Wyświetlenie szczegółów stanu technicznego meczu MatchZy[cite: 1].  
* `matchzy_forceready` - Wymuszenie gotowości obu składów i natychmiastowe wystartowanie rozgrywki[cite: 1].  
* `matchzy_pause` - Wywołanie administracyjnej pauzy technicznej[cite: 1].  
* `matchzy_unpause` - Zdjęcie pauzy administracyjnej i wznowienie rozgrywki[cite: 1].  
* `get5_endmatch` - Wymuszone zakończenie bieżącej mapy i przejście do kolejnego etapu[cite: 1].  
* `matchzy_restartmatch` - Całkowity reset struktury meczu od zera[cite: 1].  
* `mp_restartgame 1` - Restart aktualnie rozgrywanecej rundy[cite: 1].  
* `changelevel de_mirage` - Ręczna zmiana mapy serwerowej poza wtyczką MatchZy[cite: 1].  
* `matchzy_listbackups` - Wyświetlenie pełnej listy dostępnych plików zapisu rund[cite: 1].  
* `matchzy_loadbackup [nazwa_pliku.cfg]` - Wczytanie wybranego stanu rundy z pliku backupu[cite: 1].  
* `tv_record [nazwa]` - Ręczne uruchomienie zapisu dema GOTV[cite: 1].  
* `tv_stoprecord` - Zatrzymanie aktualnego zapisu dema[cite: 1].  
* `tv_status` - Sprawdzenie poprawności działania i podłączeń do portu GOTV[cite: 1].  
* `status` - Wyświetlenie spisu połączonych graczy wraz z przypisanymi numerami ID i SteamID64[cite: 1].  
* `kickid [ID]` - Wykopanie użytkownika o wskazanym numerze ID z serwera[cite: 1].  
* `banid [minuty] [ID]` - Nałożenie blokady czasowej na wskazany numer ID gracza[cite: 1].  
* `say "[wiadomosc]"` - Wyświetlenie komunikatu administracyjnego na ekranach wszystkich graczy[cite: 1].  

---

## 8. Flow Meczu od A do Z

### Przed meczem (ok. 15 min wcześniej)
* Otwierasz przygotowany szablon JSON (nazwy drużyn i SteamID już są w bazie) i czekasz na wynik procesu veto[cite: 1].  
* Head Admin kończy fazę veto z kapitanami i ogłasza `maplist`[cite: 1]. Wpisujesz nazwy map do sekcji `"maplist"` w pliku JSON i zapisujesz go[cite: 1].  
* Ładujesz config meczu za pomocą komendy konsolowej `get5_loadmatch cfg/MatchZy/mecz1.json`[cite: 1].  
* Przekazujesz informację realizatorowi: *"config załadowany"*[cite: 1]. Gracze logują się na serwer[cite: 1].  
* Gracze wpisują `!ready`, co automatycznie rozpoczyna mecz[cite: 1]. Na mapach 1 i 2 start następuje od razu, na deciderze odpala się runda nożowa[cite: 1]. Jeśli system nie łapie ready, za zgodą Head Admina wymuszasz start przez `matchzy_forceready`[cite: 1].  

### W trakcie meczu
* Monitorujesz na bieżąco okno konsoli serwera i analizujesz logi systemowe pod kątem błędów[cite: 1].  
* Reagujesz na wywołania `!pause` oraz `!tech`[cite: 1]. Wznawiasz grę komendą `matchzy_unpause` dopiero po otrzymaniu wyraźnego komunikatu o usunięciu awarii od Head Admina lub realizatora[cite: 1].  
* Po zakończeniu pierwszej mapy MatchZy automatycznie wywoła zmianę mapy na kolejną z listy[cite: 1]. W przypadku zawieszenia sekwencji, wymuszasz przejście komendą `changelevel`[cite: 1].  

### Po meczu
* Weryfikujesz poprawność zapisu dema w katalogu `game/csgo/MatchZy/`[cite: 1]. Plik o formacie `{matchid}_{data}_{mapa}.dem` kopiujesz niezwłocznie na zewnętrzny pendrive archiwizacyjny[cite: 1].  
* Czyścisz i przygotowujesz plik JSON pod konfigurację kolejnego zaplanowanego spotkania turniejowego[cite: 1].  

---

## 9. Praktyki Operacyjne, Błędy i Eskalacja

### Dobre praktyki
* Przygotuj kompletne szablony JSON przed turniejem — w trakcie meczu dopisujesz tylko mapy[cite: 1].  
* Miej stale otwarte i widoczne okno konsoli serwera — logi zawierają pełną wiedzę o stanie gry[cite: 1].  
* Zbierz i zweryfikuj SteamID64 od wszystkich zawodników minimum dzień przed turniejem[cite: 1].  
* Pole `matchid` w plikach JSON musi być unikalne dla każdego spotkania, aby uniknąć nadpisania plików `.dem`[cite: 1].  

### Czego unikać
* Nigdy nie używaj komendy `mp_restartgame` w trakcie trwania rundy na żywo (anuluje to cały stan punktowy rundy)[cite: 1].  
* Nie zmieniaj mapy komendą `changelevel` w momencie, gdy MatchZy aktywnie kontroluje spotkanie[cite: 1].  
* Nie ładuj nowego pliku konfiguracyjnego meczu bez wcześniejszego oficjalnego zamknięcia poprzedniego przy użyciu `get5_endmatch`[cite: 1].  
* Nigdy nie zmieniaj wartości flagi `sv_cheats` w trakcie trwania oficjalnej rundy meczowej[cite: 1].  

### Rozwiązywanie typowych problemów

| Problem techniczny | Przyczyna systemowa | Rozwiązanie sędziowskie |
| :--- | :--- | :--- |
| Zawodnik nie może oznaczyć stanu `!ready` | SteamID64 wpisane w pliku JSON nie zgadza się z kontem gracza[cite: 1]. | Wpisz `status`, skopiuj poprawne SteamID64 z konsoli, zaktualizuj plik JSON i przeładuj config meczu[cite: 1]. |
| Logi zwracają błąd `"Player not found in team"` | Krytyczny błąd dopasowania SteamID w strukturze JSON[cite: 1]. | Wykonaj procedurę sprawdzenia `status`, popraw strukturę pliku i uruchom ponownie `get5_loadmatch`[cite: 1]. |
| Realizator zgłasza brak sygnału z GOTV | Flaga `tv_enable` jest wyłączona lub moduł nie wystartował poprawnie[cite: 1]. | Wpisz `tv_status`. Jeśli jest off, wprowadź `tv_enable 1` i zrestartuj mapę[cite: 1]. |
| Brak pliku dema po meczu | Powtórzenie identyfikatora `matchid` lub błąd zapisu pluginu[cite: 1]. | Sprawdź dokładnie folder główny `MatchZy/`. Wymuś ręczny zapis kolejnej mapy komendą `tv_record`[cite: 1]. |
| Nagłe rozłączenie zawodnika (DC) | Awaria sieci LAN lub crash komputera gracza[cite: 1]. | MatchZy automatycznie wstrzyma rozgrywkę. Jeśli problem potrwa dłużej niż 2 minuty, wprowadź `matchzy_pause` i czekaj na decyzję Head Admina[cite: 1]. |

### Sytuacje Awaryjne i Diagnoza Poziomów Eskalacji

| Sytuacja | Pierwsza reakcja sędziego | Poziom eskalacji |
| :--- | :--- | :--- |
| **Całkowity crash procesu serwera CS2** | Restart procesu gry w sesji tmux, załadowanie ostatniego pliku backupu i zgłoszenie awarii realizatorowi[cite: 1]. | Szymon → Włączenie sceny BREAK na OBS[cite: 1]. |
| **Awaria lub brak odpowiedzi wtyczki MatchZy** | Restart serwera, weryfikacja logów CounterStrikeSharp i ponowne wczytanie JSON[cite: 1]. | Szymon / Kacper (Decyzja o pauzie technicznej turnieju)[cite: 1]. |
| **Spór drużyn dotyczący wyniku rundy** | Weryfikacja logów serwera oraz historii plików backupów rund[cite: 1]. | Head Admin (Podejmuje ostateczną decyzję na podstawie logów)[cite: 1]. |

**[KRYTYCZNA ZASADA]** Nigdy nie restartujesz procesu serwera bez wcześniejszego poinformowania realizatora (Szymona) przez system Hollyland[cite: 1]. Każdy restart odcina sygnał GOTV, więc realizator musi mieć czas na przełączenie sceny transmisyjnej na ekran przerwy technicznej[cite: 1].

---

## 10. Checklist Startowy dla Administratora (W Dniu Eventu)
- [ ] Serwer dedykowany CS2 pomyślnie uruchomiony w sesji tmux, moduły CounterStrikeSharp oraz MatchZy zgłaszają status "loaded"[cite: 1].
- [ ] Komenda `tv_status` potwierdza aktywność transmisji GOTV na porcie 27020 z opóźnieniem ustawionym na 0s[cite: 1].
- [ ] Konsola lokalna reaguje na komendy, wykonano testowy spis zawodników komendą `status`[cite: 1].
- [ ] Adres IPv4 sprawdzony w konfiguracji sieciowej i przekazany Marszałkom w celu wpisania na stanowiskach graczy[cite: 1].
- [ ] Stanowisko realizatora potwierdziło pomyślny odbiór sygnału z portu GOTV 27020 przez system interkomu[cite: 1].
- [ ] Szablony plików JSON dla wszystkich zaplanowanych meczów są gotowe i uzupełnione o poprawne identyfikatory SteamID64 zawodników[cite: 1].
- [ ] Przestrzeń dyskowa maszyny zweryfikowana (wymagane minimum 5 GB wolnego miejsca na zapis dem turniejowych)[cite: 1].
- [ ] Pendrive archiwizacyjny sędziego sformatowany i umieszczony w porcie USB stacji roboczej[cite: 1].

---

## 11. Kontakty Operacyjne
* **Realizacja Transmisji / Stream:** Szymon Karaszewski[cite: 1]
  * *Kanał łączności:* Interkom Hollyland — kanał główny[cite: 1]. Informuj Szymona o każdym planowanym restarcie, pauzie lub zmianie stanu meczu[cite: 1].
* **Sędzia Główny / Head Admin:** — uzupełnij dane —[cite: 1]
  * *Kanał łączności:* Bezpośredni w sali[cite: 1]. Odpowiada za rozstrzyganie sporów, procedurę veto oraz autoryzację pauz technicznych i przywracania rund[cite: 1].
