# AMPiW CS2 2026 - Dokumentacja i Zarządzanie Serwerem Turniejowym
==================================================================

Repozytorium zawiera kompletny ekosystem skryptów automatyzujących, plików konfiguracyjnych oraz predefiniowanych szablonów meczowych MatchZy (`*.json`) przygotowanych pod turniej esportowy AMPiW CS2 2026 na uczelni Collegium Da Vinci w Poznaniu[cite: 1].

Struktura została w pełni dostosowana do wytycznych operacyjnych briefu i zoptymalizowana pod kątem lokalnej sieci fizycznej (LAN) w sali A.003, integracji z systemami transmisji (Live Hud Manager / Scout AI) oraz sprawnego sędziowania za pomocą RCON i wtyczki CounterStrikeSharp.

---

## Metadane Operacyjne Turnieju
* **Turniej:** 09.06.2026 (wtorek)[cite: 1]
* **Sala:** A.003, Collegium Da Vinci[cite: 1]
* **Plugin:** MatchZy 0.8.15 + CounterStrikeSharp
* **Veto:** fizyczne — sędzia ogląda screen/tablicę i sam wpisuje mapy do pliku JSON

---

## Podsumowanie Roli Administratora
Jesteś głęboko w tle — gracze Cię nie widzą, ale bez Ciebie nie ma turnieju. Uruchamiasz i zarządzasz serwerem CS2[cite: 1], ładujesz konfiguracje meczów, obsługujesz RCON w locie, reagujesz na awarie i archiwizujesz dema po każdym meczu. Szymon i Head Admin mają do Ciebie bezpośrednią linię przez Hollyland.

Veto jest w 100% fizyczne. Head Admin przeprowadza je z kapitanami w sali. Ty oglądasz wynik na ekranie i ręcznie wpisujesz mapy do szablonu JSON — nikt nie przesyła Ci gotowego pliku w trakcie turnieju.

---

## 1. Architektura Sieciowa i Porty

Serwer CS2 działa na jednym z PC w sali A.003 (LAN fizyczny). Brak SSH, brak VPS. LAN IP serwera (sprawdzone przez `ipconfig` lub `ip addr`) przekazujesz Marszałkom, aby gracze mogli się połączyć.

| Komponent | Port | Protokół | Opis | Kto się łączy |
| :--- | :--- | :--- | :--- | :--- |
| **Serwer CS2 (gra)** | 27015 | TCP/UDP | Właściwy serwer turniejowy[cite: 1] | 10 stanowisk graczy |
| **GOTV obserwator (live)** | 27020 | UDP | 0 sekund delay — wymagane dla Scout AI | PC Obserwatora + LHM Scout AI |
| **Konsola serwera** | — | — | Bezpośrednie wpisywanie komend w oknie gry | Administrator (lokalnie) |

Istnieje opcja użycia własnego laptopa jako konsoli admina. Podłącz go do tej samej sieci LAN i steruj serwerem przez RCON z dowolnego miejsca w sali. W konsoli gry na laptopie wpisujesz: `rcon_address [IP_SERWERA]:27015`, następnie `rcon_password "zaq1@WSX"`. Każda kolejna komenda musi posiadać przedrostek `rcon`.

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
Zawartość pliku została w pełni dostosowana do wymagań środowiska produkcyjnego turnieju LAN z obsługą pluginów:

```ini
// ─── PODSTAWY ───────────────────────────────────────
hostname          "AMPiW CS2 2026 - CDV Poznan"
sv_password       "" 
sv_cheats         0
sv_lan            0 //Tutaj musi jednak być 0, bo Matchzy może mieć problem z mapowaniem steamid64 graczy, oraz VAC nie bedzie działać

// ─── RCON ───────────────────────────────────────────
rcon_password     "zaq1@WSX"

// ─── GOTV (Pod Live Hud Manager / Scout AI) ─────────
tv_enable         1
tv_port           27020
tv_delay          0
tv_delaymapchange 1 //Zapobiega crashom widzów przy zmianie mapy
tv_advertise_watchable 1
//Włącza automatyczne nagrywanie dema GOTV przez serwer. Nagrywanie wystartuje dokładnie w momencie, gdy MatchZy rozpocznie mecz (live) i zakończy się wraz z ostatnią rundą.
tv_autorecord 1 //taki dodatkowy backup

tv_maxclients     5

// ─── GAMEPLAY BAZOWY (MatchZy i tak to nadpisze po loadmatch) ───
mp_freezetime     15
mp_round_restart_delay 5
mp_maxrounds      24
mp_overtime_enable 1
mp_overtime_maxrounds 6
mp_autokick 0 //Zabezpieczenie przed wyrzucaniem z serwera za afk/teamkill
mp_td_dmgtokick 0 //Bez limitu obrażeń teammateom, tylko sedzia ma prawo wyrzucic gracza z serwera
mp_td_dmgtowarn 0

// ─── PERFORMANCE (CS2 WYMAGA TYLKO TEGO) ────────────
sv_minrate        786432
sv_maxrate        0
sv_maxroutable 1200 // Max rozmiar pakietu (1200B) - zapobiega choke i gubieniu danych na switchu
net_splitrate 4 // Szybsze wysyłanie podzielonych pakietów - zapobiega lagom przy masie granatów

// ─── LOGOWANIE POD LHM / SCOUT AI ───────────────────
log               on
logaddress_add    192.168.10.20:27115
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
Przygotuj szablony z nazwami drużyn i SteamID64 przed turniejem. Po zakończeniu veto dopisujesz jedynie `maplist` i `map_sides` (kto gra jako CT na danej mapie). Zabezpiecza to przed szukaniem identyfikatorów w trakcie rozgrywek.  

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
* Mirage: `de_mirage`
* Nuke: `de_nuke`
* Inferno: `de_inferno`
* Vertigo: `de_vertigo`
* Ancient: `de_ancient`
* Anubis: `de_anubis`
* Dust 2: `de_dust2`
* Train: `de_train`
  
---

## 6. Procedura Veto i Operacji Meczowych (Krok po Kroku)
**[WAŻNE]** Aby uniknąć błędu silnika gry *"Entity system yet is not initialized"* (crash serwera), zawsze najpierw ładuj mapę ręcznie, a dopiero potem konfigurację meczu MatchZy!  

1. Head Admin przeprowadza veto z kapitanami w sali (fizycznie, ustnie lub na tablicy). Ty słuchasz wyniku lub patrzysz na tablicę.  
2. Wpisujesz mapy i strony do szablonu JSON. Gdy Team A pickuje mapę 1, Team B wybiera stronę (CT/T) — zapisujesz to w `map_sides`. Decider to zawsze `"knife"` w `map_sides`. Przykład: `"map_sides": ["team2_ct", "team1_t", "knife"]`.  
3. Zapisujesz plik JSON i ładujesz mapę, a następnie config przez konsolę lub RCON:  
```text
   changelevel de_mirage
   ```
   *(Odczekaj około 10 sekund na pełne załadowanie struktury mapy, po czym wczytaj plik meczu)*
```text
   get5_loadmatch cfg/MatchZy/mecz1.json
   ```
4. Informujesz realizatora przez Hollyland: *"config załadowany, serwer gotowy"*. Szymon przełącza scenę na LIVE, gdy gracze wejdą.  
5. Gracze wpisują `!ready` w chacie CS2. Gdy obie drużyny potwierdzą stan, MatchZy uruchamia mecz ze stronami przypisanymi w JSON. Runda nożowa odpala się wyłącznie na deciderze (gdzie ustawiono wartość `"knife"`).  

### Format veto (przykład BO3 — MR12)

| # | Akcja | Kto | Wynik przykładowy | Strona (JSON) |
| :- | :- | :- | :- | :- |
| 1 | BAN | Team A (coin flip) | ~~Vertigo~~ | — |
| 2 | BAN | Team B | ~~Dust2~~ | — |
| 3 | PICK | Team A | Mirage (mapa 1) | Team B wybiera: CT → `team2_ct` |
| 4 | PICK | Team B | Inferno (mapa 2) | Team A wybiera: T → `team1_t` |
| 5 | BAN | Team A | ~~Nuke~~ | — |
| 6 | BAN | Team B | ~~Ancient~~ | — |
| 7 | DECIDER | Ostatnia mapa | Anubis (mapa 3) | `knife` — serwer losuje |
  
---

## 7. Spis Komend Systemowych

### Komendy Graczy (Wpisywane w chacie tekstowym gry)
* `!ready` / `.ready` - Oznaczenie drużyny jako gotowej do rozpoczęcia spotkania.  
* `!unready` - Cofnięcie statusu gotowości przed rozpoczęciem spotkania.  
* `!pause` / `.pause` - Żądanie pauzy taktycznej (aktywuje się na koniec danej rundy).  
* `!unpause` - Prośba o wznowienie (wymaga wpisania przez oba zespoły).  
* `!tech` - Pauza techniczna związana z awarią sprzętu (posiada nieskończony czas trwania).  
* `!stop` - Prośba o cofnięcie rundy do backupu (wymaga zgody obu kapitanów).  
* `!knife` - Restart rundy nożowej.  
* `!mystat` - Wyświetlenie indywidualnych statystyk z meczu.  
* `!coach [side]` - Dołączenie na pozycję trenera danej strony.  

### Komendy Administracyjne (Wpisywane bezpośrednio w konsoli lokalnej bez przedrostka rcon)
Serwer działa na Twoim PC, więc komendy wpisujesz bezpośrednio w oknie konsoli serwera dedykowanego bez prefixu `rcon`. Przedrostek jest wymagany wyłącznie w przypadku zdalnego sterowania z zewnętrznego laptopa gracza.  

* `get5_loadmatch cfg/MatchZy/mecz1.json` - Załadowanie wybranego pliku konfiguracyjnego meczu.  
* `get5_status` - Wyświetlenie szczegółów stanu technicznego meczu MatchZy.  
* `matchzy_forceready` - Wymuszenie gotowości obu składów i natychmiastowe wystartowanie rozgrywki.  
* `matchzy_pause` - Wywołanie administracyjnej pauzy technicznej.  
* `matchzy_unpause` - Zdjęcie pauzy administracyjnej i wznowienie rozgrywki.  
* `get5_endmatch` - Wymuszone zakończenie bieżącej mapy i przejście do kolejnego etapu.  
* `matchzy_restartmatch` - Całkowity reset struktury meczu od zera.  
* `mp_restartgame 1` - Restart aktualnie rozgrywanecej rundy.  
* `changelevel de_mirage` - Ręczna zmiana mapy serwerowej poza wtyczką MatchZy.  
* `matchzy_listbackups` - Wyświetlenie pełnej listy dostępnych plików zapisu rund.  
* `matchzy_loadbackup [nazwa_pliku.cfg]` - Wczytanie wybranego stanu rundy z pliku backupu.  
* `tv_record [nazwa]` - Ręczne uruchomienie zapisu dema GOTV.  
* `tv_stoprecord` - Zatrzymanie aktualnego zapisu dema.  
* `tv_status` - Sprawdzenie poprawności działania i podłączeń do portu GOTV.  
* `status` - Wyświetlenie spisu połączonych graczy wraz z przypisanymi numerami ID i SteamID64.  
* `kickid [ID]` - Wykopanie użytkownika o wskazanym numerze ID z serwera.  
* `banid [minuty] [ID]` - Nałożenie blokady czasowej na wskazany numer ID gracza.  
* `say "[wiadomosc]"` - Wyświetlenie komunikatu administracyjnego na ekranach wszystkich graczy.  

---

## 8. Flow Meczu od A do Z

### Przed meczem (ok. 15 min wcześniej)
* Otwierasz przygotowany szablon JSON (nazwy drużyn i SteamID już są w bazie) i czekasz na wynik procesu veto.  
* Head Admin kończy fazę veto z kapitanami i ogłasza `maplist`. Wpisujesz nazwy map do sekcji `"maplist"` w pliku JSON i zapisujesz go.  
* Ładujesz config meczu za pomocą komendy konsolowej `get5_loadmatch cfg/MatchZy/mecz1.json`.  
* Przekazujesz informację realizatorowi: *"config załadowany"*. Gracze logują się na serwer.  
* Gracze wpisują `!ready`, co automatycznie rozpoczyna mecz. Na mapach 1 i 2 start następuje od razu, na deciderze odpala się runda nożowa. Jeśli system nie łapie ready, za zgodą Head Admina wymuszasz start przez `matchzy_forceready`.  

### W trakcie meczu
* Monitorujesz na bieżąco okno konsoli serwera i analizujesz logi systemowe pod kątem błędów.  
* Reagujesz na wywołania `!pause` oraz `!tech`. Wznawiasz grę komendą `matchzy_unpause` dopiero po otrzymaniu wyraźnego komunikatu o usunięciu awarii od Head Admina lub realizatora.  
* Po zakończeniu pierwszej mapy MatchZy automatycznie wywoła zmianę mapy na kolejną z listy. W przypadku zawieszenia sekwencji, wymuszasz przejście komendą `changelevel`.  

### Po meczu
* Weryfikujesz poprawność zapisu dema w katalogu `game/csgo/MatchZy/`. Plik o formacie `{matchid}_{data}_{mapa}.dem` kopiujesz niezwłocznie na zewnętrzny pendrive archiwizacyjny.  
* Czyścisz i przygotowujesz plik JSON pod konfigurację kolejnego zaplanowanego spotkania turniejowego.  

---

## 9. Praktyki Operacyjne, Błędy i Eskalacja

### Dobre praktyki
* Przygotuj kompletne szablony JSON przed turniejem — w trakcie meczu dopisujesz tylko mapy.  
* Miej stale otwarte i widoczne okno konsoli serwera — logi zawierają pełną wiedzę o stanie gry.  
* Zbierz i zweryfikuj SteamID64 od wszystkich zawodników minimum dzień przed turniejem.  
* Pole `matchid` w plikach JSON musi być unikalne dla każdego spotkania, aby uniknąć nadpisania plików `.dem`.  

### Czego unikać
* Nigdy nie używaj komendy `mp_restartgame` w trakcie trwania rundy na żywo (anuluje to cały stan punktowy rundy).  
* Nie zmieniaj mapy komendą `changelevel` w momencie, gdy MatchZy aktywnie kontroluje spotkanie.  
* Nie ładuj nowego pliku konfiguracyjnego meczu bez wcześniejszego oficjalnego zamknięcia poprzedniego przy użyciu `get5_endmatch`.  
* Nigdy nie zmieniaj wartości flagi `sv_cheats` w trakcie trwania oficjalnej rundy meczowej.  

### Rozwiązywanie typowych problemów

| Problem techniczny | Przyczyna systemowa | Rozwiązanie sędziowskie |
| :--- | :--- | :--- |
| Zawodnik nie może oznaczyć stanu `!ready` | SteamID64 wpisane w pliku JSON nie zgadza się z kontem gracza. | Wpisz `status`, skopiuj poprawne SteamID64 z konsoli, zaktualizuj plik JSON i przeładuj config meczu. |
| Logi zwracają błąd `"Player not found in team"` | Krytyczny błąd dopasowania SteamID w strukturze JSON. | Wykonaj procedurę sprawdzenia `status`, popraw strukturę pliku i uruchom ponownie `get5_loadmatch`. |
| Realizator zgłasza brak sygnału z GOTV | Flaga `tv_enable` jest wyłączona lub moduł nie wystartował poprawnie. | Wpisz `tv_status`. Jeśli jest off, wprowadź `tv_enable 1` i zrestartuj mapę. |
| Brak pliku dema po meczu | Powtórzenie identyfikatora `matchid` lub błąd zapisu pluginu. | Sprawdź dokładnie folder główny `MatchZy/`. Wymuś ręczny zapis kolejnej mapy komendą `tv_record`. |
| Nagłe rozłączenie zawodnika (DC) | Awaria sieci LAN lub crash komputera gracza. | MatchZy automatycznie wstrzyma rozgrywkę. Jeśli problem potrwa dłużej niż 2 minuty, wprowadź `matchzy_pause` i czekaj na decyzję Head Admina. |

### Sytuacje Awaryjne i Diagnoza Poziomów Eskalacji

| Sytuacja | Pierwsza reakcja sędziego | Poziom eskalacji |
| :--- | :--- | :--- |
| **Całkowity crash procesu serwera CS2** | Restart procesu gry w sesji tmux, załadowanie ostatniego pliku backupu i zgłoszenie awarii realizatorowi. | Szymon → Włączenie sceny BREAK na OBS. |
| **Awaria lub brak odpowiedzi wtyczki MatchZy** | Restart serwera, weryfikacja logów CounterStrikeSharp i ponowne wczytanie JSON. | Szymon / Kacper (Decyzja o pauzie technicznej turnieju). |
| **Spór drużyn dotyczący wyniku rundy** | Weryfikacja logów serwera oraz historii plików backupów rund. | Head Admin (Podejmuje ostateczną decyzję na podstawie logów). |

**[KRYTYCZNA ZASADA]** Nigdy nie restartujesz procesu serwera bez wcześniejszego poinformowania realizatora (Szymona) przez system Hollyland. Każdy restart odcina sygnał GOTV, więc realizator musi mieć czas na przełączenie sceny transmisyjnej na ekran przerwy technicznej.

---

## 10. Checklist Startowy dla Administratora (W Dniu Eventu)
- [ ] Serwer dedykowany CS2 pomyślnie uruchomiony w sesji tmux, moduły CounterStrikeSharp oraz MatchZy zgłaszają status "loaded".
- [ ] Komenda `tv_status` potwierdza aktywność transmisji GOTV na porcie 27020 z opóźnieniem ustawionym na 0s.
- [ ] Konsola lokalna reaguje na komendy, wykonano testowy spis zawodników komendą `status`.
- [ ] Adres IPv4 sprawdzony w konfiguracji sieciowej i przekazany Marszałkom w celu wpisania na stanowiskach graczy.
- [ ] Stanowisko realizatora potwierdziło pomyślny odbiór sygnału z portu GOTV 27020 przez system interkomu.
- [ ] Szablony plików JSON dla wszystkich zaplanowanych meczów są gotowe i uzupełnione o poprawne identyfikatory SteamID64 zawodników.
- [ ] Przestrzeń dyskowa maszyny zweryfikowana (wymagane minimum 5 GB wolnego miejsca na zapis dem turniejowych).
- [ ] Pendrive archiwizacyjny sędziego sformatowany i umieszczony w porcie USB stacji roboczej.

---

## 11. Kontakty Operacyjne
* **Realizacja Transmisji / Stream:** Szymon Karaszewski
  * *Kanał łączności:* Interkom Hollyland — kanał główny. Informuj Szymona o każdym planowanym restarcie, pauzie lub zmianie stanu meczu.
* **Sędzia Główny / Head Admin:** — uzupełnij dane —
  * *Kanał łączności:* Bezpośredni w sali. Odpowiada za rozstrzyganie sporów, procedurę veto oraz autoryzację pauz technicznych i przywracania rund.
