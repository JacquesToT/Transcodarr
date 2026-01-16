# Wijzigingslogboek

Alle belangrijke wijzigingen aan dit project worden gedocumenteerd in dit bestand.

## [1.0.1] - 2026-01-16

### Bugfixes
- Opgelost: Hardware transcoding (VideoToolbox) werd niet gebruikt, systeem viel terug op software transcoding
- VideoToolbox wrapper is nu volledig geïntegreerd in de installatie op afstand via lib/remote-ssh.sh

### Verbeteringen
- Oude debug en documentatie bestanden verwijderd
- Codebase opgeschoond voor betere onderhoudbaarheid

## [1.0.0] - 2026-01-15

### Eerste uitgave
- Gedistribueerde live transcoding voor Jellyfin met Apple Silicon Macs
- Hardware-versnelde VideoToolbox encoding ondersteuning
- HDR/HDR10+/Dolby Vision tone mapping via jellyfin-ffmpeg
- Automatische installatiewizard voor Synology NAS en Mac
- Multi-node load balancing via rffmpeg
- NFS mount configuratie voor media en cache
