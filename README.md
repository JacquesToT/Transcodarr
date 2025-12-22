# Transcodarr

**Distributed Live Transcoding for Jellyfin using Apple Silicon Macs**

Offload live video transcoding from your NAS/server to Apple Silicon Macs with hardware-accelerated VideoToolbox encoding. Get 7-13x realtime transcoding speeds with Apple Silicon.

> ## ⚠️ BACKUP FIRST
>
> **Before running the installer, create backups of:**
>
> | Component | What to backup |
> |-----------|----------------|
> | **Jellyfin** | Your entire Jellyfin config folder (e.g., `/volume1/docker/jellyfin`) |
> | **Docker** | Your `docker-compose.yml` and any custom configurations |
> | **Mac** | Note your current energy settings (`pmset -g`) |
>
> The installer modifies system configurations. While it's designed to be safe, having backups ensures you can restore your setup if needed.

---

## What is a "Node"?

In Transcodarr, a **node** is simply a Mac that handles transcoding jobs. Think of it like this:

- Your **server** (Synology/NAS) runs Jellyfin and stores your media
- Your **node(s)** (Mac Mini, Mac Studio, etc.) do the heavy lifting (transcoding)

You can have **one node** (single Mac) or **multiple nodes** (several Macs sharing the workload).

## Features

- **Hardware Acceleration**: Uses Apple Silicon VideoToolbox (H.264/HEVC)
- **Distributed Transcoding**: Offload transcoding from your NAS to Apple Silicon Macs
- **Load Balancing**: Distribute workload across multiple Macs (nodes)
- **Automatic Fallback**: Falls back to local transcoding if Mac is unavailable
- **Easy Setup**: Interactive installer with step-by-step guidance
- **Monitoring**: Prometheus + Grafana dashboard included *(optional)*

## Performance

| Input | Output | Speed |
|-------|--------|-------|
| 1080p BluRay REMUX (33 Mbps) | H.264 4 Mbps | 7.5x realtime |
| 720p video | H.264 2 Mbps | 13.8x realtime |
| 720p video | HEVC 1.5 Mbps | 12x realtime |

## Requirements

### Mac (Transcode Node)
- macOS Sequoia 15.x or later
- Apple Silicon (M1/M2/M3/M4)
- Network connection to NAS

### Server (Jellyfin Host)
- Synology NAS (or other Linux server)
- Docker with docker-compose
- NFS server capability (for media sharing)
- Network connection to Mac transcode node

---

# Installation Guide

## Step 0: Install Required Tools on Synology

Before you can run the installer, you need three tools on your Synology:
1. **Git** - to download Transcodarr
2. **Homebrew** - a package manager (like an app store for command-line tools)
3. **Gum** - makes the installer look nice and interactive

### 0.1 Install Git (via Package Center)

This is the easiest part - Git is available in Synology's built-in app store!

1. Open **Package Center** on your Synology
2. Search for **"Git"** (or find it under "Developer Tools")
3. Click **Install**
4. Wait for it to finish
5. Done!

**To verify:** SSH into your Synology and type:
```bash
git --version
```
You should see something like `git version 2.x.x`

### 0.2 Install Homebrew on Synology

Homebrew is a tool that lets you install software easily. There's a special version made for Synology!

**SSH into your Synology first:**
```bash
ssh your-admin-user@your-synology-ip
```

**Then run this one command to install Homebrew:**
```bash
git clone https://github.com/MrCee/Synology-Homebrew.git ~/Synology-Homebrew && \
~/Synology-Homebrew/install-synology-homebrew.sh
```

**What this does (in simple terms):**
- Downloads the Synology Homebrew installer
- Runs it automatically
- Sets up Homebrew so you can use it

**After installation, close and reopen your terminal**, or run:
```bash
source ~/.bashrc
```

**To verify Homebrew works:**
```bash
brew --version
```
You should see something like `Homebrew 4.x.x`

### 0.3 Install Gum

Now that Homebrew is installed, installing Gum is easy!

```bash
brew install gum
```

**To verify Gum works:**
```bash
gum --version
```
You should see something like `gum version 0.x.x`

---

## Step 1: Download Transcodarr

On your Synology (via SSH):

```bash
git clone https://github.com/JacquesToT/Transcodarr.git ~/Transcodarr
cd ~/Transcodarr
chmod +x install.sh
```

---

## Step 2: Prepare Your NAS (NFS Settings)

The Mac needs to access your media files via NFS.

### 2.1 Enable NFS on Synology

1. Open **Control Panel** → **File Services**
2. Go to **NFS** tab
3. Enable NFS service
4. Click **Apply**

### 2.2 Set NFS Permissions on Shared Folders

1. Open **Control Panel** → **Shared Folder**
2. Select your **media folder** (e.g., `data` or `media`)
3. Click **Edit** → **NFS Permissions** tab
4. Click **Create** and add:

| Setting | Value |
|---------|-------|
| Hostname or IP | `*` (or your Mac's IP for security) |
| Privilege | Read/Write |
| Squash | Map all users to admin |
| Security | sys |
| Enable async | Yes |
| Allow connections from non-privileged ports | Yes |
| Allow users to access mounted subfolders | Yes |

5. Repeat for the **docker folder** if you want the Mac to write transcoded files back

### 2.3 Find Your Paths

**Media Path:**
```
/volume1/data/media      ← Most common
/volume1/video           ← Alternative
/volume1/Media           ← Alternative
```

To check your actual path:
```bash
ls -la /volume1/
```

**Cache Path:**
```
/volume1/docker/jellyfin/cache
```

This is where Jellyfin stores temporary transcoded video segments.

---

## Step 3: Prepare Your Mac

### 3.1 Enable Remote Login (SSH)

The Jellyfin server needs SSH access to send FFmpeg commands to your Mac.

1. Open **System Settings**
2. Go to **General** → **Sharing**
3. Enable **Remote Login**
4. Under "Allow access for": select **All users** or add specific users

### 3.2 Note Your Username

Your Mac username is needed for SSH connections. Find it:

- **System Settings** → **Users & Groups** → Your account name
- Or run in Terminal: `whoami`

**Note:** If your username has spaces (e.g., "John Smith"), that's fine - the installer handles it.

### 3.3 Check Your Mac's IP Address

1. **System Settings** → **Network**
2. Select your connection (Wi-Fi or Ethernet)
3. Click **Details**
4. Note the **IP Address**

**Tip:** For reliability, assign a static IP to your Mac in your router settings.

---

## Step 4: Gather Your Information

Before running the installer, have these ready:

| Item | Example | Where to find it |
|------|---------|------------------|
| NAS IP address | `192.168.1.100` | Synology: Control Panel → Network |
| Mac IP address | `192.168.1.50` | Mac: System Settings → Network |
| Mac username | `John Smith` | Mac: `whoami` in Terminal |
| NAS media path | `/volume1/data/media` | Where your movies/TV shows are stored |
| Jellyfin config path | `/volume1/docker/jellyfin` | Where Jellyfin config is stored |

---

## Step 5: Run the Installer

```bash
cd ~/Transcodarr
./install.sh
```

The interactive installer will guide you through:
- Apple Silicon Mac setup (FFmpeg, NFS, energy settings)
- Jellyfin/Docker configuration (rffmpeg, SSH keys)
- Monitoring setup (Prometheus/Grafana) — *optional*

> **Note:** On first-time Mac setup, a **reboot is required** for NFS mount points to work. The installer will show you exactly what to do after rebooting.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    TRANSCODARR                           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   SERVER (Synology/Docker)         MAC MINI (M1/M4)     │
│   ┌──────────────────┐            ┌──────────────────┐  │
│   │    Jellyfin      │            │     FFmpeg       │  │
│   │    Container     │───SSH────▶│   VideoToolbox   │  │
│   │    + rffmpeg     │            │   H.264/HEVC     │  │
│   └────────┬─────────┘            └────────┬─────────┘  │
│            │                               │            │
│            │         NFS                   │            │
│            ▼                               ▼            │
│   ┌──────────────────────────────────────────────────┐  │
│   │              Media & Cache Storage               │  │
│   └──────────────────────────────────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| SSH connection fails | Check Remote Login is enabled on Mac |
| Video doesn't play | Verify libfdk-aac is installed |
| Transcoding is slow | Check if using hardware encoder |
| NFS mount hangs | Use `soft,timeo=10` mount options |

### Useful Commands

```bash
# Check rffmpeg status
docker exec jellyfin rffmpeg status

# Clear bad host state
docker exec -u abc jellyfin rffmpeg clear

# Test SSH from container
docker exec -u abc jellyfin ssh -i /config/rffmpeg/.ssh/id_rsa user@mac-ip

# Check FFmpeg on Mac
/opt/homebrew/bin/ffmpeg -encoders | grep videotoolbox
```

### NFS Issues

**"NFS mount failed"**
- Check NFS is enabled on Synology
- Check NFS permissions include your Mac's IP
- Ensure "Allow non-privileged ports" is enabled

**"SSH connection refused"**
- Enable Remote Login on Mac
- Check macOS Firewall settings
- Verify the username is correct (including spaces)

**"Permission denied"**
- On Synology: Check NFS squash settings
- On Mac: Ensure your user has admin rights

---

## Manual Setup

Prefer to set things up manually? See **[MANUAL_SETUP.md](MANUAL_SETUP.md)**

### Mac Quick Setup

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install FFmpeg with VideoToolbox + libfdk-aac
brew tap homebrew-ffmpeg/ffmpeg
brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-fdk-aac

# Verify
ffmpeg -encoders | grep videotoolbox
ffmpeg -encoders | grep fdk

# Prevent sleep
sudo pmset -a sleep 0 displaysleep 0 disksleep 0 autorestart 1
```

### Jellyfin Quick Setup

```yaml
# docker-compose.yml
services:
  jellyfin:
    image: linuxserver/jellyfin:latest
    environment:
      - DOCKER_MODS=linuxserver/mods:jellyfin-rffmpeg
      - FFMPEG_PATH=/usr/local/bin/ffmpeg
    volumes:
      - /path/to/config:/config
      - /path/to/media:/data/media
```

```bash
# Add Mac to rffmpeg
docker exec jellyfin rffmpeg add 192.168.1.50 --weight 2
docker exec jellyfin rffmpeg status
```

---

## Monitoring

Import the included Grafana dashboard (`grafana-dashboard.json`) to monitor:
- CPU usage per transcode node
- Memory usage
- Network traffic
- Node status (UP/DOWN)

---

## File Structure

```
transcodarr/
├── install.sh              # Interactive installer
├── lib/
│   ├── mac-setup.sh        # Mac setup module
│   └── jellyfin-setup.sh   # Jellyfin/Docker setup module
├── scripts/
│   ├── add-mac-node.sh     # Add Mac to rffmpeg
│   └── test-ssh.sh         # Test SSH connection
├── rffmpeg/
│   └── rffmpeg.yml         # rffmpeg configuration template
├── docs/
│   ├── MAC_SETUP.md        # Detailed Mac setup guide
│   └── JELLYFIN_SETUP.md   # Detailed Jellyfin guide
├── grafana-dashboard.json  # Grafana monitoring dashboard
└── docker-compose.yml      # Generated Docker Compose
```

---

## Good to Know

### Triggering Transcoding in Jellyfin

Transcoding only happens when needed. Here's how to force it:

**Option 1: Set a bitrate limit per user** *(admin setting)*
1. Go to **Dashboard → Users → [User] → Playback**
2. Set a **Maximum bitrate** (e.g., 8 Mbps)
3. Any video above this bitrate will automatically transcode

**Option 2: User changes quality during playback** *(user setting)*
1. While watching, click the **settings/gear icon** in the player
2. Select a **lower quality** (e.g., "1080p 8Mbps" instead of "Original")
3. The stream will transcode to that quality

> **Note:** When switching from direct play (original quality) to a transcoded stream, playback will pause briefly while the transcoded stream starts. This is normal behavior.

### Server-wide Limits

You can also set global bitrate limits:
- **Dashboard → Playback → Streaming → Internet streaming bitrate limit**

This is useful for remote users on slower connections.

---

## Tested Setup

This project has been tested with:

| Component | Model |
|-----------|-------|
| **NAS** | Synology DS1821+ |
| **Transcode Nodes** | M1 Mac Mini, M4 Mac Mini, M4 Mac Studio |

I can only test with the hardware I have available. If you encounter issues with other setups, please [open an issue](https://github.com/JacquesToT/Transcodarr/issues).

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [rffmpeg](https://github.com/joshuaboniface/rffmpeg) - Remote FFmpeg wrapper
- [Gum](https://github.com/charmbracelet/gum) - Terminal UI toolkit
- [LinuxServer.io](https://linuxserver.io) - Jellyfin Docker image with rffmpeg mod
- [Synology-Homebrew](https://github.com/MrCee/Synology-Homebrew) - Homebrew for Synology
- This project was 99% built with [Claude Code](https://claude.com/claude-code)
