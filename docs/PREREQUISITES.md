# Prerequisites - Before You Start

Before running the Transcodarr installer, you need to prepare a few things on your NAS and Mac.

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
