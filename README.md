# 🔊 Retro SFX Daemon

<div align="center">

![Python](https://img.shields.io/badge/Python-3.6+-blue?style=for-the-badge&logo=python)
![Linux](https://img.shields.io/badge/Linux-Systemd-green?style=for-the-badge&logo=linux)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Stable-success?style=for-the-badge)

**A lightweight Linux service that generates retro computer sounds—inspired by classic movie terminals and mainframes—using either the internal PC speaker, external speakers, or a random mix of both.**

*Bring the nostalgic beeps and boops of classic computing to your modern Linux system!*

</div>

---

## 📋 Table of Contents

- [✨ Features](#-features)
- [🎵 Sound Profiles](#-sound-profiles)
- [🔧 Requirements](#-requirements)
- [📦 Installation](#-installation)
- [⚙️ Configuration](#️-configuration)
- [🎮 Usage](#-usage)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [🗑️ Uninstall](#️-uninstall)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎯 **Multiple Profiles** | Switch between WOPR, Mainframe, and Alien Terminal sounds at runtime |
| 🔊 **Flexible Output** | PC speaker, external audio, or randomized mix |
| ⏰ **Quiet Hours** | Scheduled silence during specified times |
| 🎚️ **Sound Selection** | Choose which sound variations to use for each profile |
| 🛡️ **Audio Limiter** | Soft limiter to protect speakers from sudden spikes |
| 🔄 **Live Control** | Change settings without restarting the service |
| 🤖 **Auto-Detection** | Automatically detects available audio hardware |
| 🚀 **Zero Config** | Works out of the box with sensible defaults |

---

## 🎵 Sound Profiles

### 🎮 WOPR
**Fast, chatty, WarGames-style console sounds**
- High-frequency beeps and boops
- Rapid sequences with variable timing
- Perfect for active terminal sessions

### 🖥️ Mainframe
**Slow, low, ambient computer-room noises**
- Deep, rumbling tones
- Long pauses between sounds
- Ideal for background ambiance

### 👽 Alien Terminal
**Higher-pitched, eerie sci-fi terminal tones**
- Sci-fi movie inspired
- Varied frequency ranges
- Mysterious and atmospheric

Each profile has **10 variations** that can be selectively enabled via configuration!

---

## 🔧 Requirements

### Hardware
- ✅ **PC speaker** (optional, for authentic beeps)
- ✅ **OR** external speakers / headphones
- ✅ **OR** USB audio device (for servers without built-in audio)

> 💡 **Note:** The script automatically detects available audio hardware and gracefully handles systems with no audio output (e.g., headless servers).

### Software
- 🐧 Linux with systemd
- 📦 Supported distributions:
  - **RHEL / Rocky / Alma / Fedora** (dnf)
  - **Ubuntu / Debian** (apt)

---

## 📦 Installation

### 1. Clone or Download

```bash
git clone <repository-url>
cd retro-sfxctl
```

### 2. Run the Installer

```bash
chmod +x retro-sfx-installer.sh
sudo ./retro-sfx-installer.sh
```

The installer will:
- ✅ Install dependencies (`beep`, `alsa-utils`, `sox`)
- ✅ Enable the `pcspkr` kernel module
- ✅ Create configuration files
- ✅ Install the daemon and control CLI
- ✅ Create and start the systemd service

### 📁 Installed Files

| Path | Purpose |
|------|---------|
| `/usr/local/bin/retro-sfxd.py` | Background daemon |
| `/usr/local/bin/retro-sfxctl.py` | Runtime control CLI |
| `/etc/retro-sfx.conf` | Main configuration file |
| `/etc/systemd/system/retro-sfx.service` | systemd unit file |
| `/run/retro-sfx/` | Runtime state (profile, enable flag) |

---

## ⚙️ Configuration

### 📝 Configuration File

Edit `/etc/retro-sfx.conf` to customize behavior:

```ini
# Quiet hours in 24h local time
QUIET_ENABLED=1
QUIET_START="22:00"
QUIET_END="07:00"

# Output backend: pcspkr | audio | random
OUTPUT_MODE=random

# If OUTPUT_MODE=random:
# Probability (0-100) of choosing external audio
RANDOM_AUDIO_PERCENT=70

# Audio backend settings
AUDIO_DEVICE=default
AUDIO_GAIN=1.0

# Soft limiter settings (SoX compand)
LIMITER_ENABLED=0
LIM_ATTACK=0.005
LIM_DECAY=0.10
LIM_SOFTKNEE=6
LIM_TARGET_DB=-3

# Sound pattern selection
# Each profile has 10 variations (0-9)
# Use "all" for all variations, or comma-separated list like "0,1,2,3"
WOPR_ENABLED_VARIATIONS=all
MAINFRAME_ENABLED_VARIATIONS=all
ALIENSTERM_ENABLED_VARIATIONS=all
```

> 🔄 **Changes apply automatically** - no service restart required!

---

## 🎮 Usage

### 🔍 Service Management

```bash
# Check service status
sudo systemctl status retro-sfx.service

# Start / stop
sudo systemctl start retro-sfx.service
sudo systemctl stop retro-sfx.service

# Disable at boot
sudo systemctl disable retro-sfx.service
```

### 🎛️ Runtime Control (No Restart Required)

#### Check Current State
```bash
sudo retro-sfxctl status
```

#### Enable or Mute Sounds
```bash
sudo retro-sfxctl on
sudo retro-sfxctl off
```

#### Switch Sound Profiles
```bash
sudo retro-sfxctl profile wopr
sudo retro-sfxctl profile mainframe
sudo retro-sfxctl profile aliensterm
```

#### Set Output Mode
```bash
sudo retro-sfxctl output pcspkr    # PC speaker only
sudo retro-sfxctl output audio     # External audio only
sudo retro-sfxctl output random    # Random mix
```

#### Tune Random Selection
```bash
# Set percentage sent to external speakers (0-100)
sudo retro-sfxctl random-audio 70
```

#### Configure Quiet Hours
```bash
# Set quiet hours (HH:MM format)
sudo retro-sfxctl quiet-time 22:00 07:00

# Enable/disable quiet hours
sudo retro-sfxctl quiet on
sudo retro-sfxctl quiet off
```

#### Select Sound Variations
```bash
# Use only specific variations (0-9)
sudo retro-sfxctl variations wopr "0,1,2,3"        # First 4 variations
sudo retro-sfxctl variations mainframe "all"       # All variations
sudo retro-sfxctl variations aliensterm "5,6,7,8,9" # Last 5 variations
```

#### Audio Limiter
```bash
sudo retro-sfxctl limiter on
sudo retro-sfxctl limiter off
```

---

## 🛠️ Troubleshooting

### 🔇 No Sound from PC Speaker

1. **Ensure the system has a physical speaker**
2. **Check BIOS/UEFI settings** - PC speaker may be disabled
3. **Verify module is loaded:**
   ```bash
   lsmod | grep pcspkr
   ```

### 🔐 PC Speaker Permissions

The installer automatically sets the SUID bit on the `beep` command, allowing regular users to use the PC speaker without sudo.

**Check permissions:**
```bash
ls -l /usr/bin/beep
# Should show 's' in permissions (e.g., -rwsr-xr-x)
```

**If not set:**
```bash
sudo chmod u+s /usr/bin/beep
# OR run the installer: sudo ./retro-sfx-installer.sh
```

### 🎧 External Audio Not Working

**List available devices:**
```bash
aplay -L
```

**Update `AUDIO_DEVICE` in `/etc/retro-sfx.conf`:**
```ini
AUDIO_DEVICE=pipewire  # or pulse, hw:0,0, etc.
```

### 💻 Running in a VM

- PC speaker output usually does **not** work in VMs
- Use `OUTPUT_MODE=audio` instead
- Configure via: `sudo retro-sfxctl output audio`

### 🖥️ Dell PowerEdge Servers (T620, R630, R750, etc.)

- These servers typically have **no built-in audio hardware**
- The script automatically detects this and skips audio output gracefully
- If you connect a **USB audio device**, it will be automatically detected and used
- The daemon continues running without errors even if no audio hardware is present

### 🧪 Testing Sounds

Use the test script to verify audio output:

```bash
# Test PC speaker
./retro-sfx-test.sh pcspkr wopr

# Test external audio
./retro-sfx-test.sh audio mainframe

# Test alien terminal
./retro-sfx-test.sh audio aliensterm
```

---

## 🗑️ Uninstall

```bash
# Stop and disable service
sudo systemctl stop retro-sfx.service
sudo systemctl disable retro-sfx.service

# Remove files
sudo rm -f \
  /usr/local/bin/retro-sfxd.py \
  /usr/local/bin/retro-sfxctl.py \
  /etc/retro-sfx.conf \
  /etc/systemd/system/retro-sfx.service

# Reload systemd
sudo systemctl daemon-reload
```

---

## 📝 Notes

- 🎯 Designed for **labs, desks, NOCs, demos, and ambient fun**
- 🔒 **No network access**, no telemetry, no persistent data beyond config
- 💻 Works best on **physical hardware**
- 🎨 Each sound profile has **10 variations** for maximum variety
- ⚡ **Zero-downtime configuration** - changes apply instantly

---

<div align="center">

**Made with ❤️ for retro computing enthusiasts**

*Bring the nostalgia of classic computing to your modern Linux system!*

</div>
