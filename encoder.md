# Encoder Compatibility - Homebrew FFmpeg vs Jellyfin-FFmpeg

## Overview

Transcodarr uses the standard Homebrew FFmpeg on Mac. This has some limitations compared to Jellyfin's custom FFmpeg build.

## Known Limitations

### 1. HDR to SDR Tonemapping

**Problem:** Jellyfin uses the `tonemapx` filter for HDR to SDR conversion. This filter is **NOT available** in standard Homebrew FFmpeg.

**Symptom:**
```
Finished rffmpeg with return code 8
```

**FFmpeg error:**
```
No such filter: 'tonemapx'
```

**Affected content:**
- HDR10 content
- HDR10+ content
- Dolby Vision content

**Workarounds:**

1. **Disable tonemapping in Jellyfin**
   - Dashboard → Playback → Transcoding
   - Set "Tone mapping algorithm" to "None"
   - Note: Colors may look washed out on SDR displays

2. **Use Direct Play for HDR**
   - If your client supports HDR, enable Direct Play
   - No transcoding needed = no tonemapping issue

3. **Accept Synology fallback**
   - rffmpeg automatically falls back to localhost (Synology)
   - Slower, but works for all content

### 2. libfdk_aac Encoder

**Problem:** The `libfdk_aac` encoder is not included in Homebrew FFmpeg due to patent/licensing issues.

**Symptom:** Jellyfin requests `libfdk_aac` but FFmpeg doesn't have it.

**Solution:** FFmpeg automatically falls back to the standard `aac` encoder, which works fine for most use cases. No action needed.

## Content Compatibility Matrix

| Content Type | Mac Transcoding | Notes |
|-------------|-----------------|-------|
| SDR H.264 | ✅ Works | Full support |
| SDR HEVC/H.265 | ✅ Works | Full support |
| SDR AV1 | ✅ Works | Homebrew has libaom |
| HDR10 HEVC | ❌ Fails* | Missing tonemapx filter |
| HDR10+ HEVC | ❌ Fails* | Missing tonemapx filter |
| Dolby Vision | ❌ Fails* | Missing DV processing |
| Audio (any) | ✅ Works | Falls back to standard aac |

*Falls back to Synology transcoding automatically

## Checking Your FFmpeg

```bash
# On Mac - check available filters
/opt/homebrew/bin/ffmpeg -filters 2>&1 | grep tonemap
# Output: "tonemap" (standard) - NOT "tonemapx" (Jellyfin custom)

# Check available encoders
/opt/homebrew/bin/ffmpeg -encoders 2>&1 | grep -E "(x264|x265|aac)"
```

## Future Solutions

### Option 1: Custom FFmpeg Build (Advanced)

Build FFmpeg with additional patches for tonemapx support. This requires:
- Jellyfin's FFmpeg patches
- Manual compilation
- Maintenance burden for updates

### Option 2: Hardware Tonemapping

Apple Silicon has hardware tonemapping capabilities via VideoToolbox. Future Jellyfin/FFmpeg versions may support this natively.

### Option 3: Use Standard Tonemap

Jellyfin could potentially use the standard `tonemap` filter instead of `tonemapx` for software transcoding. This would require Jellyfin configuration changes.

## Recommended Setup

For the best experience with Transcodarr:

1. **SDR content** → Mac transcoding (fast, works perfectly)
2. **HDR content** → One of:
   - Direct Play (if client supports HDR)
   - Synology fallback (automatic, slower)
   - Disable tonemapping (colors may be off)

## Jellyfin Settings for Best Compatibility

```
Dashboard → Playback → Transcoding:

Hardware acceleration: None
Allow encoding in HEVC format: ☑ (optional)
Allow encoding in AV1 format: ☐ (disable - slow on CPU)
Tone mapping algorithm: None (for HDR passthrough)
```

This configuration ensures maximum compatibility with Homebrew FFmpeg while still benefiting from Mac transcoding for the majority of content.
