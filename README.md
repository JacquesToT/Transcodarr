# Transcodarr

**Distributed Live Transcoding for Jellyfin using Apple Silicon Macs**

Offload live video transcoding from your NAS to Apple Silicon Macs with hardware-accelerated VideoToolbox encoding. Get 7-13x realtime transcoding speeds.

## What It Does

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
              Shared cache folder
```

---

## Prerequisites

### Same Username on All Macs

> **IMPORTANT**: All Mac nodes MUST use the same SSH username.

rffmpeg (the load balancer) uses a single SSH user configuration for all remote hosts. If you have multiple Macs:
- Use the **same username** on all Macs, OR
- Create a dedicated user (e.g., `transcodarr`) on each Mac

**Example**: If your first Mac uses username `nick`, all other Macs must also have a user `nick`.

### Gather This Information First

Before starting, collect these values:

| What | Example | Where to find |
|------|---------|---------------|
| **Synology IP** | `192.168.1.100` | Control Panel → Network → Network Interface |
| **Synology Username** | `admin` | Your login username |
| **Media Path** | `/volume1/data/media` | File Station → Right-click folder → Properties |
| **Mac IP** | `192.168.1.50` | System Settings → Network |
| **Mac Username** | `nick` | Terminal: `whoami` (must be same on all Macs!) |

---

## Setup Synology

### 1. Enable SSH

1. Open **Control Panel** → **Terminal & SNMP**
2. Check **"Enable SSH service"**
3. Click **Apply**

### 2. Enable User Home Service

1. Open **Control Panel** → **User & Group** → **Advanced**
2. Check **"Enable user home service"**
3. Click **Apply**

### 3. Install Git

1. Open **Package Center**
2. Search for **"Git"**
3. Click **Install**

> **Note:** If Git doesn't appear, go to **Package Center** → **Settings** → **Package Sources** and make sure the Synology official source is enabled.

### 4. Install Homebrew & Gum

SSH into your Synology and run:

```bash
ssh your-username@your-synology-ip
```

Then install Homebrew:

```bash
git clone https://github.com/MrCee/Synology-Homebrew.git ~/Synology-Homebrew
~/Synology-Homebrew/install-synology-homebrew.sh
```

- Choose **option 1 (Minimal)**
- Close your terminal
- Reconnect via SSH

Then install Gum:

```bash
brew install gum
```

### 5. Configure NFS

#### Enable NFS Service

1. Open **Control Panel** → **File Services** → **NFS**
2. Check **"Enable NFS service"**
3. Set **Maximum NFS protocol** to **NFSv4.1**
4. Click **Apply**

#### Set NFS Permissions on Folders

For your **media folder** (e.g., `/volume1/data/media`):

1. Open **Control Panel** → **Shared Folder**
2. Select your media folder → **Edit** → **NFS Permissions**
3. Click **Create** and add:
   - **Hostname or IP:** `*` (or your Mac's IP for more security)
   - **Privilege:** Read Only
   - **Squash:** Map all users to admin
   - **Security:** sys
   - **Enable asynchronous:** ✓
   - **Allow connections from non-privileged ports:** ✓
   - **Allow users to access mounted subfolders:** ✓
4. Click **OK** → **Save**

Repeat for your **Jellyfin cache folder** (e.g., `/volume1/docker/jellyfin/cache`), but set **Privilege** to **Read/Write**.

---

## Setup Mac

The only thing you need to do on your Mac is enable SSH:

### Enable Remote Login (SSH)

1. Open **System Settings** → **General** → **Sharing**
2. Enable **"Remote Login"**
3. Set **"Allow access for:"** to your user or "All users"

> **Note:** Everything else (Homebrew, FFmpeg, mount points) will be installed automatically by the Transcodarr installer via SSH.

---

## Install Transcodarr

SSH into your Synology:

```bash
ssh your-username@your-synology-ip
```

Then run:

```bash
git clone https://github.com/JacquesToT/Transcodarr.git ~/Transcodarr
cd ~/Transcodarr && ./install.sh
```

The installer will:
1. Ask for your Mac's IP address and username
2. Connect to your Mac via SSH (you'll enter your Mac password once)
3. Automatically install Homebrew and FFmpeg on your Mac
4. Create mount points and configure NFS mounts
5. Handle Mac reboot if needed (and wait for it to come back)
6. Set up rffmpeg configuration

**That's it!** The entire setup is done from your Synology.

## Requirements

### Mac (Transcode Node)
- macOS Sequoia 15.x or later
- Apple Silicon (M1/M2/M3/M4)
- Network connection to NAS

### Server (Jellyfin Host)
- Synology NAS with Container Manager (Docker)
- Jellyfin in Docker container (linuxserver/jellyfin)
- NFS enabled

## Performance

| Input | Output | Speed |
|-------|--------|-------|
| 1080p BluRay REMUX (33 Mbps) | H.264 4 Mbps | 7.5x realtime |
| 720p video | H.264 2 Mbps | 13.8x realtime |
| 720p video | HEVC 1.5 Mbps | 12x realtime |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Synology NAS                        │
│  ┌─────────────────┐    ┌─────────────────────────────┐ │
│  │    Jellyfin     │    │         NFS Shares          │ │
│  │   + rffmpeg     │    │  • /volume1/data/media      │ │
│  │     mod         │    │  • /volume1/.../cache       │ │
│  └────────┬────────┘    └─────────────────────────────┘ │
└───────────│─────────────────────────────────────────────┘
            │ SSH (FFmpeg commands)
            ▼
┌─────────────────────────────────────────────────────────┐
│                    Mac Mini / Mac Studio                 │
│  ┌─────────────────┐    ┌─────────────────────────────┐ │
│  │     FFmpeg      │    │       NFS Mounts            │ │
│  │  VideoToolbox   │    │  • /data/media              │ │
│  │                 │    │  • /config/cache            │ │
│  └─────────────────┘    └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Troubleshooting

### "Permission denied" SSH error
1. Check if Remote Login is enabled on Mac (System Settings → Sharing)
2. Verify the SSH key is in `~/.ssh/authorized_keys`
3. Check permissions: `chmod 600 ~/.ssh/authorized_keys`

### "Host marked as bad" in rffmpeg
```bash
docker exec jellyfin rffmpeg clear
docker exec jellyfin rffmpeg add <MAC_IP> --weight 2
```

### Mac not reachable
- Check if Mac is not sleeping
- Check firewall settings (port 22 for SSH)
- Ping test: `ping <MAC_IP>`

### NFS mount fails
1. Verify NFS service is enabled on Synology
2. Check NFS permissions on the shared folder
3. Test mount manually: `mount -t nfs <NAS_IP>:/volume1/data/media /data/media`

## Commands

### Check status
```bash
docker exec jellyfin rffmpeg status
```

### Add node
```bash
docker exec jellyfin rffmpeg add <MAC_IP> --weight 2
```

### Remove node
```bash
docker exec jellyfin rffmpeg remove <MAC_IP>
```

## Uninstall

On Mac:
```bash
cd ~/Transcodarr && ./uninstall.sh
```

## License

MIT

## Credits

- [rffmpeg](https://github.com/joshuaboniface/rffmpeg) - Remote FFmpeg wrapper
- [linuxserver/mods:jellyfin-rffmpeg](https://github.com/linuxserver/docker-mods) - Docker mod
