AMPiW CS2 2026 - Dedykowany Serwer Turniejowy (CDV Poznan)
==========================================================

Repozytorium zawiera kompletny ekosystem skryptów automatyzujacych, plików konfiguracyjnych oraz predefiniowanych meczów MatchZy (*.json) przygotowanych pod turniej esportowy AMPiW CS2 2026 na uczelni Collegium Da Vinci w Poznaniu.

Struktura została w pełni zoptymalizowana pod kątem lokalnej sieci fizycznej (LAN), integracji z systemami HUD (Live Hud Manager / Scout AI) oraz płynnego sędziowania.

----------------------------------------------------------
Struktura Projektu
----------------------------------------------------------

* autosetup.sh
  Opis: Główny skrypt Bash instalujący zależności, zaporę UFW oraz CS2 przez LinuxGSM.
  Lokalizacja docelowa: ~/ (Katalog roota / sędziego)

* uninstall_plugins.sh
  Opis: Skrypt czyszczący folder wtyczek addons przed aktualizacją (zachowuje konfiguracje).
  Lokalizacja docelowa: /home/cs2/

* server.cfg
  Opis: Główny config serwera zoptymalizowany pod LAN (rate, brak autokicka, logowanie GSI).
  Lokalizacja docelowa: /home/cs2/serverfiles/game/csgo/cfg/

* *.json (np. final_cdv_vs_pp.json)
  Opis: Pliki konfiguracyjne MatchZy zawierające składy drużyn i ich SteamID.
  Lokalizacja docelowa: /home/cs2/serverfiles/game/csgo/

----------------------------------------------------------
Instrukcja Wdrożenia Serwera (Od Zera do Live)
----------------------------------------------------------

Instalacja systemu odbywa się na czystym systemie Ubuntu Server. Skrypt automatycznie skonfiguruje zaporę sieciową, pobierze środowisko .NET Runtime 8.0 oraz zainstaluje najnowszą wersję gry.

Krok 1: Klonowanie repozytorium i instalacja bazy
Zaloguj się na serwer jako root i uruchom główny instalator, podając jako argument hasło dla nowo tworzonego użytkownika systemowego "cs2":

sudo bash autosetup.sh "TwojeBezpieczneHaslo123"

Krok 2: Konfiguracja sieci pod stream i HUD (LHM)
Przed uruchomieniem serwera upewnij się, że logi gry trafiają na komputer realizatora streamu. Otwórz plik server.cfg:

nano /home/cs2/serverfiles/game/csgo/cfg/server.cfg

Znajdź linijkę "logaddress_add" na samym dole i podmień adres IP na lokalne IP komputera, na którym odpalony jest Live Hud Manager:

logaddress_add "192.168.1.XX:27115" // IP komputera z HUD-em w sali LAN

Krok 3: Pierwsze uruchomienie serwera
Zaloguj się na dedykowane konto użytkownika "cs2" i podnieś serwer za pomocą menedżera LinuxGSM:

su - cs2
./cs2server start

Aby kontrolować serwer i wpisywać komendy, wejdź do konsoli na żywo:

./cs2server console
(Wyjście z konsoli bez wyłączania gry: Ctrl+B, a następnie klawisz D)

----------------------------------------------------------
Procedura Zarządzania Meczem (Instrukcja Sędziego)
----------------------------------------------------------

Wszystkie pliki turniejowe .json znajdują się bezpośrednio w głównym katalogu gry: /home/cs2/serverfiles/game/csgo/

WAŻNA ZASADA ŁADOWANIA MECZU:
Aby uniknąć błędu silnika gry "Entity system yet is not initialized" (crash serwera), zawsze najpierw ładuj mapę ręcznie, a dopiero potem konfigurację meczu MatchZy!

Poprawna sekwencja komend w konsoli sędziego (RCON):

map de_nuke
(należy odczekać ok. 10 sekund, aż mapa w pełni się załaduje)
matchzy_loadmatch final_cdv_vs_pp.json

Lista dostępnych meczów turniejowych:
1. test_match.json - Mecz próbny (Sędziowie vs Technicy)
2. polfinal_pp_vs_up.json - Półfinał #1 (Politechnika Poznańska vs Uniwersytet Przyrodniczy)
3. polfinal_cdv_vs_wsl.json - Półfinał #2 (Collegium Da Vinci vs Wyższa Szkoła Logistyki)
4. 3rd_place.json - Mecz o 3. miejsce
5. final_cdv_vs_pp.json - Wielki Finał turnieju

----------------------------------------------------------
Administracja i Przydatne Komendy w Grze
----------------------------------------------------------

Podczas trwania meczu sędziowie oraz gracze mogą kontrolować stan rozgrywki bezpośrednio z poziomu czatu tekstowego w CS2:

Komendy dla graczy:
* !ready / !notready - Oznaczenie gotowości zespołu w fazie rozgrzewki.
* !pause / !unpause - Zgłoszenie standardowej pauzy taktycznej.
* !coach t lub !coach ct - Dołączenie do drużyny na slot trenera.

Komendy dla sędziów (wymagany status Admina/RCON):
* !tech - Włączenie nieskończonej pauzy technicznej (sprzętowej).
* !force_ready - Wymuszenie gotowości wszystkich graczy.
* !start - Natychmiastowe przerwanie warmup-u i rozpoczęcie meczu (Match is LIVE).
* !stop - Anulowanie aktualnego meczu i powrót do trybu konfiguracji.

----------------------------------------------------------
Aktualizacja Wtyczek (Metamod / CSSharp)
----------------------------------------------------------

W przypadku wydania aktualizacji CS2, która psuje działanie obecnych pluginów, przygotowany został bezpieczny skrypt czyszczący:

su - cs2
bash ~/uninstall_plugins.sh

* Skrypt bezpiecznie gasi serwer i usuwa foldery binarne z katalogu addons/.
* Wszystkie konfiguracje, pliki server.cfg oraz bazy meczów .json zostają nienaruszone.
* Wpis modyfikujący w pliku gameinfo.gi zostaje zachowany, dzięki czemu po rozpakowaniu nowej wersji wtyczek serwer jest od razu gotowy do pracy.

----------------------------------------------------------
Specyfikacja Techniczna Optymalizacji LAN
----------------------------------------------------------

* sv_lan 0
  Serwer celowo działa w trybie autoryzacji Steam, aby MatchZy bezbłędnie przypisywał graczy po SteamID64 oraz by działały oficjalne skiny zawodników.

* sv_maxroutable 1200
  Zmniejszony rozmiar pakietu sieciowego chroni przed utratą subticków na przełącznikach sieciowych w sali.

* mp_autokick 0
  Blokada automatycznych banów i kicków za Teamkill (FF) oraz AFK. Pełną władzę nad karaniem graczy dzierży sędzia.

* tv_delay 0
  Zerowe opóźnienie GOTV przekazuje surowe dane w czasie rzeczywistym bezpośrednio do systemu nakładek graficznych streamu.
