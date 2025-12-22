# Prerequisites - Before You Start

Before running the Transcodarr installer, you need to prepare a few things on your NAS and Mac.

---

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
5. ✅ Done!

**To verify:** Open Terminal (or SSH into your Synology) and type:
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

### 0.4 Download Transcodarr

Now you can download Transcodarr:

```bash
git clone https://github.com/JacquesToT/Transcodarr.git ~/Transcodarr
cd ~/Transcodarr
chmod +x install.sh
```

✅ **You're ready to run the installer!** Continue with the steps below to prepare your NAS settings, then run `./install.sh`

---

## What You'll Need

| Item | Example | Where to find it |
|------|---------|------------------|
| NAS IP address | `192.168.1.100` | Synology: Control Panel → Network → Network Interface |
| Mac IP address | `192.168.1.50` | Mac: System Settings → Network → Wi-Fi/Ethernet → Details |
| Mac username | `John Smith` | Mac: System Settings → Users & Groups (your login name) |
| NAS media path | `/volume1/data/media` | Where your movies/TV shows are stored |
| NAS cache path | `/volume1/docker/jellyfin/cache` | Where Jellyfin stores transcoded files |

---

## Step 1: Synology/NAS Preparation

### 1.1 Enable NFS on Synology

The Mac needs to access your media files via NFS.

1. Open **Control Panel** → **File Services**
2. Go to **NFS** tab
3. ✅ Enable NFS service
4. Click **Apply**

### 1.2 Set NFS Permissions on Shared Folders

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
| Enable async | ✅ Yes |
| Allow connections from non-privileged ports | ✅ Yes |
| Allow users to access mounted subfolders | ✅ Yes |

5. Repeat for the **docker folder** if you want the Mac to write transcoded files back

### 1.3 Find Your Paths

**Media Path:**
```
/volume1/data/media      ← Most common
/volume1/video           ← Alternative
/volume1/Media           ← Alternative
```

To check your actual path, SSH into your Synology:
```bash
ls -la /volume1/
ls -la /volume1/
```

**Cache Path:**
```
/volume1/docker/jellyfin/cache    ← If Jellyfin config is on volume1
/volume1/docker/jellyfin/cache    ← If Jellyfin config is on volume1
```

This is where Jellyfin stores temporary transcoded video segments.

---

## Step 2: Mac Preparation

### 2.1 Enable Remote Login (SSH)

The Jellyfin server needs SSH access to send FFmpeg commands to your Mac.

1. Open **System Settings**
2. Go to **General** → **Sharing**
3. Enable **Remote Login**
4. Under "Allow access for": select **All users** or add specific users

### 2.2 Note Your Username

Your Mac username is needed for SSH connections. Find it:

- **System Settings** → **Users & Groups** → Your account name
- Or run in Terminal: `whoami`

⚠️ **Important:** If your username has spaces (e.g., "John Smith"), that's fine - the installer handles it.

### 2.3 Check Your Mac's IP Address

1. **System Settings** → **Network**
2. Select your connection (Wi-Fi or Ethernet)
3. Click **Details**
4. Note the **IP Address**

💡 **Tip:** For reliability, assign a static IP to your Mac in your router settings.

---

## Step 3: Network Checklist

Before running the installer, verify connectivity:

### From your Mac, test NAS access:
```bash
# Ping the NAS
ping 192.168.1.100

# Test NFS mount (replace with your NAS IP and path)
sudo mount -t nfs -o resvport 192.168.1.100:/volume1/data/media /tmp/test-mount
ls /tmp/test-mount
sudo umount /tmp/test-mount
```

### From your NAS/server, test Mac SSH:
```bash
# Test SSH connection (replace with your Mac's IP and username)
ssh "Your Username@192.168.1.50"
```

---

## Quick Reference Card

Copy this and fill in your values:

```
┌─────────────────────────────────────────────────────┐
│  MY TRANSCODARR CONFIGURATION                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│  NAS/Synology:                                      │
│    IP Address: ___.___.___.___                      │
│    Media Path: /volume_/___________                 │
│    Cache Path: /volume_/docker/jellyfin/cache       │
│                                                     │
│  Mac (Transcode Node):                              │
│    IP Address: ___.___.___.___                      │
│    Username:   ____________________                 │
│                                                     │
│  Jellyfin:                                          │
│    Config Path: /volume_/docker/jellyfin            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Common Issues

### "NFS mount failed"
- Check NFS is enabled on Synology
- Check NFS permissions include your Mac's IP
- Ensure "Allow non-privileged ports" is enabled

### "SSH connection refused"
- Enable Remote Login on Mac
- Check macOS Firewall settings
- Verify the username is correct (including spaces)

### "Permission denied"
- On Synology: Check NFS squash settings
- On Mac: Ensure your user has admin rights

---

## Ready to Install?

Once you have:
- ✅ NFS enabled on Synology
- ✅ NFS permissions set for media folder
- ✅ Remote Login enabled on Mac
- ✅ Noted all IP addresses and paths

Run the installer:
```bash
./install.sh
```
