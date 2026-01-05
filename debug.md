# Jellyfin Startup Debug - 2026-01-05

## Status: ✅ OPGELOST

## Probleem
Jellyfin start niet meer na het runnen van de installer.

## Root Cause
```
[ERR] FFmpeg: Failed version check: /usr/local/bin/ffmpeg
[FTL] Error while starting server - Failed to find valid ffmpeg
```

De rffmpeg wrapper kan geen verbinding maken met de Mac, waardoor ffmpeg validatie faalt.

---

## Debug Stappen

### Stap 1: Check rffmpeg symlink
```bash
sudo docker exec jellyfin ls -la /usr/local/bin/ffmpeg
```
**Resultaat:** ✅ OK
```
lrwxrwxrwx 1 root root 7 Jan  4 20:09 /usr/local/bin/ffmpeg -> rffmpeg
```

### Stap 2: Check geregistreerde nodes
```bash
sudo docker exec jellyfin rffmpeg status
```
**Resultaat:** ✅ Node bestaat
```
Hostname        Servername      ID  Weight  State  Active Commands
192.168.175.43  192.168.175.43  1   4       idle   N/A
```

### Stap 3: Test SSH verbinding vanuit container
```bash
sudo docker exec -u abc jellyfin ssh -i /config/rffmpeg/.ssh/id_rsa -o StrictHostKeyChecking=no -o BatchMode=yes nick@192.168.175.43 "echo OK"
```
**Resultaat:** ❌ HANGT - SSH verbinding faalt/timeout

### Stap 4: Check SSH key permissions
```bash
sudo docker exec jellyfin ls -la /config/rffmpeg/.ssh/
```
**Resultaat:** ⚠️ Mogelijk probleem
```
-rw------- 1 911   911 411 Jan  5 13:23 id_rsa
-rw-r--r-- 1 911   911 101 Jan  4 16:34 id_rsa.pub
```
Key ownership is `911:911`, maar abc user uid kan anders zijn.

### Stap 5: Check abc user uid
```bash
sudo docker exec jellyfin id abc
```
**Resultaat:**
```
uid=1026(abc) gid=100(users) groups=100(users)
```

### Stap 6: Test of abc user key kan lezen
```bash
sudo docker exec -u abc jellyfin cat /config/rffmpeg/.ssh/id_rsa | head -1
```
**Resultaat:** ❌ PERMISSION DENIED
```
cat: /config/rffmpeg/.ssh/id_rsa: Permission denied
```

---

## ROOT CAUSE GEVONDEN

**De SSH key is eigendom van uid 911, maar abc user heeft uid 1026!**

De key heeft `chmod 600` (alleen owner kan lezen), dus abc user kan de private key niet lezen.

## OPLOSSING

```bash
# Fix ownership naar correcte abc user
sudo chown -R 1026:100 /volume1/docker/jellyfin/rffmpeg

# Verifieer dat abc nu kan lezen
sudo docker exec -u abc jellyfin cat /config/rffmpeg/.ssh/id_rsa | head -1
# Moet tonen: -----BEGIN OPENSSH PRIVATE KEY-----

# Test SSH verbinding
sudo docker exec -u abc jellyfin ssh -o ConnectTimeout=5 -o BatchMode=yes -i /config/rffmpeg/.ssh/id_rsa nick@192.168.175.43 "echo OK"

# Als dat werkt, restart Jellyfin
sudo docker restart jellyfin
```

---

## Volgende Debug Stappen (indien nodig)

### Stap 5: Check abc user uid in container
```bash
sudo docker exec jellyfin id abc
```

### Stap 6: Test SSH met verbose output (naar correcte IP!)
```bash
sudo docker exec -u abc jellyfin ssh -vvv -i /config/rffmpeg/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 nick@192.168.175.43 "echo OK"
```

### Stap 7: Check of Mac SSH port open is
```bash
nc -zv 192.168.175.43 22
```

### Stap 8: Check of key readable is door abc user
```bash
sudo docker exec -u abc jellyfin cat /config/rffmpeg/.ssh/id_rsa | head -1
```

---

## Mogelijke Oorzaken

1. **SSH key permission probleem** - abc user kan key niet lezen (uid mismatch)
2. **Mac SSH niet bereikbaar** - firewall, Remote Login uit, netwerk
3. **SSH key niet geautoriseerd op Mac** - public key niet in ~/.ssh/authorized_keys
4. **Verkeerd IP adres** - Mac heeft ander IP dan geregistreerd

---

## Oplossingen

### Als SSH key permissions fout zijn:
```bash
# Get abc uid from container
ABC_UID=$(sudo docker exec jellyfin id -u abc)
ABC_GID=$(sudo docker exec jellyfin id -g abc)

# Fix ownership op host
sudo chown -R ${ABC_UID}:${ABC_GID} /volume1/docker/jellyfin/rffmpeg
```

### Als Mac niet bereikbaar is:
1. Check of Mac aan staat
2. Check of Remote Login aan staat (System Settings > General > Sharing)
3. Check firewall settings op Mac

### Als SSH key niet geautoriseerd is op Mac:
```bash
# Op de Mac, voeg public key toe:
cat /volume1/docker/jellyfin/rffmpeg/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```
