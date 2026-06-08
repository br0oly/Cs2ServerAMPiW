#!/bin/bash

# Sprawdzenie czy podano argument
if [ -z "$1" ]; then
    echo "Użycie: $0 <ścieżka_do_pliku_csv>"
    exit 1
fi

FILE="$1"

# Sprawdzenie czy plik istnieje
if [ ! -f "$FILE" ]; then
    echo "Błąd: Plik '$FILE' nie istnieje!"
    exit 1
fi

# Wyciągnięcie podstawowych informacji z pierwszego wiersza danych (wiersz 2)
MATCH_ID=$(awk -F, 'NR==2 {print $1}' "$FILE")
MAP_NUM=$(awk -F, 'NR==2 {print $2}' "$FILE")

echo "====================================================================="
echo "                  PODSUMOWANIE MECZU (MatchZy)                       "
echo "====================================================================="
echo " Mecz ID: $MATCH_ID  |  Numer Mapy: $MAP_NUM"
echo "====================================================================="

# Przetwarzanie danych i grupowanie po drużynach za pomocą awk
awk -F, '
NR > 1 {
    # Przypisanie kolumn do czytelnych zmiennych
    team = $4
    name = $5
    kills = $6
    deaths = $7
    damage = $8
    assists = $9
    util_dmg = $15

    # Filtrowanie pustych lub uszkodzonych rekordów
    if (name == "") next;

    # Jeśli to spectator, zapisujemy oddzielnie, resztę grupujemy w drużyny
    if (team == "Spectator" || team == "spectator") {
        spectators[name] = 1
    } else {
        teams[team] = 1
        # Klucz unikalny dla gracza (team + name) zabezpiecza przed nadpisaniem
        p_team[team, name] = team
        p_kills[team, name] = kills
        p_deaths[team, name] = deaths
        p_assists[team, name] = assists
        p_damage[team, name] = damage
        p_util_dmg[team, name] = util_dmg
    }
}
END {
    # Iteracja po znalezionych drużynach
    for (t in teams) {
        print "\nDRUŻYNA: " t
        print "---------------------------------------------------------------------"
        printf "%-18s | %-4s | %-4s | %-4s | %-8s | %-12s\n", "Gracz", "K", "D", "A", "Suma DMG", "Utility DMG"
        print "---------------------------------------------------------------------"
        
        for (k in p_team) {
            split(k, idx, SUBSEP)
            if (idx[1] == t) {
                p_name = idx[2]
                printf "%-18s | %-4d | %-4d | %-4d | %-8d | %-12d\n", 
                    p_name, p_kills[k], p_deaths[k], p_assists[k], p_damage[k], p_util_dmg[k]
            }
        }
    }

    # Sekcja dla Spectatorów (jeśli istnieją)
    has_specs = 0
    for (s in spectators) { has_specs = 1; break }
    
    if (has_specs) {
        print "\nOBSERWATORZY (Spectators):"
        print "---------------------------------------------------------------------"
        for (s in spectators) {
            print " - " s
        }
    }
    print "=====================================================================\n"
}' "$FILE"
