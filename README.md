# Transcodarr

**Distributed Live Transcoding for Jellyfin using Apple Silicon Macs**

Offload live video transcoding from your NAS to Apple Silicon Macs with hardware-accelerated VideoToolbox encoding.

## How It Works

```
┌─────────────────┐         ┌─────────────────┐
│    Jellyfin     │   SSH   │   Apple Mac     │
│   (Synology)    │ ──────> │  (VideoToolbox) │
│                 │         │                 │
│  Requests       │         │  Transcodes     │
│  transcode      │         │  with hardware  │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │         NFS               │
         └───────────────────────────┘
              Shared media & cache
```

## Requirements

**Synology NAS:**
- Docker / Container Manager
- NFS enabled
- Jellyfin using `linuxserver/jellyfin` image (required for rffmpeg)

**Mac (Apple Silicon):**
- M1/M2/M3/M4
- macOS Sequoia 15.x or later
- Remote Login (SSH) enabled

## Before You Start

Collect these values:

| What | Example | Where to find |
|------|---------|---------------|
| **Synology IP** | `192.168.1.100` | Control Panel → Network |
| **Mac IP** | `192.168.1.50` | System Settings → Network |
| **Mac Username** | `nick` | Terminal: `whoami` |
| **Media Path** | `/volume1/data/media` | File Station → Right-click → Properties |
| **Jellyfin Config** | `/volume1/docker/jellyfin` | Your docker-compose volume |

---

## Step 1: Setup Jellyfin

Create or update your Jellyfin container with rffmpeg support:

```yaml
services:
  jellyfin:
    image: linuxserver/jellyfin
    container_name: jellyfin
    environment:
      - PUID=1026                                      # Your user ID (run: id)
      - PGID=100                                       # Your group ID (run: id)
      - TZ=Europe/Amsterdam                            # Your timezone
      - JELLYFIN_PublishedServerUrl=192.168.1.100     # Your Synology IP
      - DOCKER_MODS=linuxserver/mods:jellyfin-rffmpeg # Required for remote transcoding
      - FFMPEG_PATH=/usr/local/bin/ffmpeg             # Required for rffmpeg
    volumes:
      - /volume1/docker/jellyfin:/config
      - /volume1/data/media:/data/media
      - /volume1/docker/jellyfin/cache:/cache         # Transcode cache (needs NFS)
    ports:
      - 8096:8096/tcp
      - 7359:7359/udp
    network_mode: bridge
    security_opt:
      - no-new-privileges:true
    restart: always
```

> **Note:** Find your PUID/PGID by running `id` in SSH on your Synology.

---

## Step 2: Configure NFS

The Mac needs NFS access to your media and cache folders.

### Enable NFS Service

1. Open **Control Panel** → **File Services** → **NFS**
2. Check **"Enable NFS service"**
3. Set Maximum NFS protocol to **NFSv4.1**
4. Click **Apply**

### Set NFS Permissions

Go to **Control Panel** → **Shared Folder**, select each folder, click **Edit** → **NFS Permissions** → **Create**:

| Folder | Privilege | Squash |
|--------|-----------|--------|
| Media (e.g. `/volume1/data/media`) | Read Only | Map all users to admin |
| Cache (e.g. `/volume1/docker/jellyfin/cache`) | **Read/Write** | Map all users to admin |

**For both folders, also enable:**
- ✓ Allow connections from non-privileged ports
- ✓ Allow users to access mounted subfolders

---

## Step 3: Install Transcodarr

### On your Mac

1. Open **System Settings** → **General** → **Sharing**
2. Enable **"Remote Login"**

### On your Synology

SSH into your Synology and run:

```bash
git clone https://github.com/JacquesToT/Transcodarr.git ~/Transcodarr
cd ~/Transcodarr && ./install.sh
```

The installer will:
1. Connect to your Mac via SSH
2. Install Homebrew and FFmpeg with VideoToolbox
3. Create mount points and configure NFS
4. Handle Mac reboot if needed
5. Register the Mac with rffmpeg

**That's it!** Start a video in Jellyfin and watch it transcode on your Mac.

---

## Adding Another Mac

To add more Macs to your transcoding cluster:

> **Important:** All Macs must use the **same username** for SSH.
> rffmpeg uses a single SSH user configuration for all nodes.

1. Enable **Remote Login** on the new Mac (System Settings → Sharing)
2. Run the installer on your Synology: `cd ~/Transcodarr && ./install.sh`
3. Select **"➕ Add a new Mac node"**

The installer will configure everything automatically.

---

## Commands

### Check status
```bash
docker exec jellyfin rffmpeg status
```

### Add node manually
```bash
docker exec jellyfin rffmpeg add <MAC_IP> --weight 2
```

### Remove node
```bash
docker exec jellyfin rffmpeg remove <MAC_IP>
```

### Clear bad host status
```bash
docker exec jellyfin rffmpeg clear
```

---

## Troubleshooting

### "Permission denied" SSH error
1. Check Remote Login is enabled on Mac (System Settings → Sharing)
2. Run **"Fix SSH Keys"** from the installer menu
3. Verify permissions: `chmod 600 ~/.ssh/authorized_keys`

### "Host marked as bad" in rffmpeg
```bash
docker exec jellyfin rffmpeg clear
docker exec jellyfin rffmpeg status
```

### NFS mount fails on Mac
1. Verify NFS is enabled on Synology
2. Check NFS permissions include "non-privileged ports"
3. Test manually: `sudo mount -t nfs <NAS_IP>:/volume1/data/media /data/media`

### Mac not reachable
- Ensure Mac is not sleeping (Energy settings)
- Check firewall allows SSH (port 22)
- Test: `ping <MAC_IP>`

---

## Installer Menu Reference

### Fix SSH Keys

Repairs SSH key authentication between Jellyfin and Mac nodes:
1. Checks the SSH key in the container has correct permissions
2. Tests SSH connectivity to each registered Mac
3. Reinstalls keys where authentication is failing

**Use when:** rffmpeg shows connection errors, after recreating the Jellyfin container, or after restoring from backup.

### Configure Monitor

Configures SSH settings for the Transcodarr Monitor (TUI dashboard):
- **NAS IP** - Your Synology's IP address
- **NAS User** - SSH username for the Synology

---

## Performance

| Input | Output | Speed |
|-------|--------|-------|
| 1080p BluRay (33 Mbps) | H.264 4 Mbps | ~7x realtime |
| 720p video | H.264 2 Mbps | ~13x realtime |

---

## License

MIT

## Credits

- [rffmpeg](https://github.com/joshuaboniface/rffmpeg) - Remote FFmpeg wrapper
- [linuxserver/mods:jellyfin-rffmpeg](https://github.com/linuxserver/docker-mods) - Docker mod
