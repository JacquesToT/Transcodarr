# rffmpeg Load Balancing

Dit document beschrijft het load balancing probleem met rffmpeg en onze oplossing.

## Het Probleem

### rffmpeg Weight Selectie is Broken

**Verwachting:** rffmpeg zou hosts moeten selecteren op basis van gewogen random selectie.
- Weight 4 zou 2x zoveel jobs moeten krijgen als weight 2
- Beide hosts zouden gebruikt moeten worden

**Realiteit:** rffmpeg selecteert hosts op **ID volgorde**, niet op weight.

```
DEBUG - Trying host ID 3 '192.168.175.43'
DEBUG - Running SSH test
DEBUG - SSH test succeeded with retcode 0
DEBUG - Selecting host as idle
DEBUG - Found optimal host ID 3 '192.168.175.43'
```

Het probeert ALLEEN de eerste host (laagste ID), en als die beschikbaar is, wordt die gebruikt. De tweede host wordt **nooit** geprobeerd, tenzij de eerste faalt.

### Geen Load Awareness

rffmpeg checkt NIET:
- Of de host al transcoding jobs draait
- Of de host overbelast is
- Of een andere host "beter" zou zijn

---

## Onze Oplossing: Round-Robin Load Balancer

We hebben **Optie D (Round-Robin via ID Rotatie)** geïmplementeerd. Dit is een daemon die:

1. Actieve ffmpeg processen monitort in de Jellyfin container
2. Detecteert wanneer een transcode voltooid is
3. De host queue roteert zodat de volgende transcode naar een andere node gaat

### Hoe Het Werkt

```
Vóór rotatie:                Na rotatie:
#1 192.168.1.10 <-- NEXT     #1 192.168.1.20 <-- NEXT
#2 192.168.1.20              #2 192.168.1.10
```

Door de eerste host naar het einde van de queue te verplaatsen, krijgt de volgende transcode een andere node toegewezen.

---

## Gebruik

### Via de Installer (Aanbevolen)

1. Start de installer: `./install.sh`
2. Kies **"🔄 Load Balancer"** uit het menu
3. Gebruik de submenu opties:
   - **Start Load Balancer** - Start de daemon
   - **Stop Load Balancer** - Stop de daemon
   - **Rotate Hosts Now** - Handmatig roteren
   - **View Logs** - Bekijk recente log entries

### Via Command Line

```bash
# Status bekijken
./load-balancer.sh status

# Daemon starten
./load-balancer.sh start

# Daemon stoppen
./load-balancer.sh stop

# Handmatig roteren
./load-balancer.sh rotate

# Huidige host volgorde tonen
./load-balancer.sh show

# Logs bekijken
./load-balancer.sh logs
```

### Als Systemd Service (Synology/Linux)

Voor automatische start bij boot:

```bash
cd services/
sudo ./install-service.sh install
```

Dit installeert de load balancer als systemd service:

```bash
# Service beheren
sudo systemctl start transcodarr-lb
sudo systemctl stop transcodarr-lb
sudo systemctl status transcodarr-lb

# Logs volgen
journalctl -u transcodarr-lb -f
```

---

## Configuratie

Environment variabelen:

| Variabele | Default | Beschrijving |
|-----------|---------|--------------|
| `JELLYFIN_CONTAINER` | `jellyfin` | Naam van de Jellyfin Docker container |
| `CHECK_INTERVAL` | `5` | Seconden tussen process checks |

Voorbeeld:
```bash
CHECK_INTERVAL=10 ./load-balancer.sh start
```

---

## Beperkingen

1. **Niet load-aware**: De rotatie is puur sequentieel, niet gebaseerd op CPU/RAM gebruik
2. **Snelle sequentiële transcodes**: Als meerdere transcodes zeer snel starten, kunnen ze naar dezelfde node gaan voordat rotatie plaatsvindt
3. **Vereist 2+ nodes**: Met slechts 1 node is load balancing niet mogelijk

---

## Technische Details

### Bestanden

| Bestand | Beschrijving |
|---------|--------------|
| `load-balancer.sh` | Hoofd daemon script |
| `lib/jellyfin-setup.sh` | Bevat `rotate_rffmpeg_hosts()` functie |
| `services/transcodarr-lb.service` | Systemd service definitie |
| `services/install-service.sh` | Service installer script |

### Detectie Methode

De daemon detecteert transcode-voltooiing door:

1. Elke `CHECK_INTERVAL` seconden het aantal actieve ffmpeg processen te tellen
2. Als het aantal daalt, is er een transcode voltooid
3. Voor elke voltooide transcode wordt de host queue geroteerd

Dit is betrouwbaarder dan log-parsing omdat het niet afhankelijk is van log-formaat.

### Log Locatie

- Daemon logs: `/tmp/transcodarr-lb.log`
- PID file: `/tmp/transcodarr-lb.pid`

---

## Alternatieven (Niet Geïmplementeerd)

### Optie A: rffmpeg Source Aanpassen
- Zou echte weighted random selectie geven
- Nadeel: Wordt overschreven bij container updates

### Optie C: Load-Aware Balancer
- Zou real-time CPU/RAM metrics gebruiken
- Nadeel: Extra complexiteit, latency bij elke transcode

### Optie E: Jellyfin per-Library Configuratie
- Handmatige toewijzing van libraries aan nodes
- Nadeel: Niet dynamisch, vereist handmatig beheer

---

## Commit Historie

| Commit | Beschrijving |
|--------|--------------|
| `c900dfe` | Monitor weight display en priority ranking |
| `bf4dc57` | rffmpeg weight-based host reordering workaround |
| `2955208` | NFS mount stdout pollution fix |
| (nieuw) | Round-robin load balancer implementatie |
