# AMPiW CS2 2026 - Dokumentacja i Zarządzanie Serwerem Turniejowym

> Wersja przygotowana pod GitHub README.md

## Metadane Operacyjne Turnieju

- Turniej: 09.06.2026 (wtorek)
- Sala: A.003, Collegium Da Vinci
- Plugin: MatchZy 0.8.15 + CounterStrikeSharp
- Veto: fizyczne — sędzia ogląda screen/tablicę i sam wpisuje mapy do pliku JSON

---

# 1. Architektura Sieciowa i Porty

| Komponent | Port | Protokół | Opis |
|------------|------|----------|------|
| Serwer CS2 | 27015 | TCP/UDP | Serwer turniejowy |
| GOTV | 27020 | UDP | Scout AI / Observer |
| Konsola | — | — | Lokalna administracja |

# 2. Struktura Projektu

| Plik | Lokalizacja |
|--------|------------|
| autosetup.sh | ~/ |
| install_plugins.sh | ~/ |
| uninstall_plugins.sh | ~/ |
| server.cfg | cfg/ |
| prac.cfg | cfg/ |
| admins.json | configs/ |
| *.json | cfg/MatchZy/ |

# 3. Skrypty Automatyzacji

## autosetup.sh

```bash
# zawartość zgodna z dokumentacją użytkownika
```

## install_plugins.sh

```bash
# zawartość zgodna z dokumentacją użytkownika
```

## uninstall_plugins.sh

```bash
# zawartość zgodna z dokumentacją użytkownika
```

# 4. Pliki Konfiguracyjne

## server.cfg

```cfg
hostname "AMPiW CS2 2026 - CDV Poznan"
```

## prac.cfg

```cfg
sv_cheats 1
```

## admins.json

```json
{
  "Sedzia_Glowny": {}
}
```

# 5. MatchZy

```json
{
  "num_maps": 1
}
```

# 6. Procedura Veto

1. changelevel
2. odczekaj ~10 sekund
3. get5_loadmatch

# 7. Spis Komend

## Gracze

- !ready
- !unready
- !pause
- !tech

## Administrator

- get5_loadmatch
- get5_status
- matchzy_pause
- matchzy_unpause
- changelevel

# 8. Flow Meczu

### Przed meczem

- Uzupełnij JSON
- Załaduj konfigurację
- Oczekuj na ready

### W trakcie

- Monitoruj logi
- Obsługuj pauzy

### Po meczu

- Archiwizacja dem
- Przygotowanie kolejnego meczu

# 9. Praktyki Operacyjne

## Dobre praktyki

- Przygotuj JSON wcześniej
- Zweryfikuj SteamID64
- Zachowaj unikalny matchid

## Czego unikać

- mp_restartgame podczas meczu
- Nieautoryzowane changelevel

# 10. Checklist Startowy

- [ ] Serwer uruchomiony
- [ ] GOTV aktywne
- [ ] IPv4 przekazane
- [ ] JSON gotowe
- [ ] Minimum 5 GB wolnego miejsca

# 11. Kontakty Operacyjne

## Realizacja transmisji

Szymon Karaszewski

## Head Admin

Do uzupełnienia.
