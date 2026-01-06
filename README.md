# 🔊 Retro SFX Daemon

<div align="center">

![Python](https://img.shields.io/badge/Python-3.6+-blue?style=for-the-badge&logo=python)
![Linux](https://img.shields.io/badge/Linux-Systemd-green?style=for-the-badge&logo=linux)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Stable-success?style=for-the-badge)

**A lightweight Linux service that generates retro computer sounds—inspired by classic movie terminals, mainframes, and dial-up modems—using either the internal PC speaker, external speakers, or a random mix of both.**

*Bring the nostalgic beeps and boops of classic computing to your modern Linux system!*

**Features 4 unique sound profiles** with 10 variations each, runtime control, quiet hours, and automatic hardware detection.

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
- [📝 Notes](#-notes)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎯 **4 Sound Profiles** | WOPR, Mainframe, Alien Terminal, and Modem - switch at runtime |
| 🔊 **Flexible Output** | PC speaker, external audio, or randomized mix |
| ⏰ **Quiet Hours** | Scheduled silence during specified times |
| 🎚️ **Sound Selection** | Choose which sound variations (0-9) to use for each profile |
| ⏱️ **Configurable Intervals** | Set pattern intervals from 1 to 100 minutes |
| 🔢 **Beep Count Control** | Configure number of beeps per pattern (1-20) |
| 🎵 **Sound File Playback** | Play random sound files from a directory (1-30 seconds, PC speaker compatible) |
| 🛡️ **Audio Limiter** | Soft limiter to protect speakers from sudden spikes |
| 🔄 **Live Control** | Change settings without restarting the service |
| 🤖 **Auto-Detection** | Automatically detects available audio hardware |
| 🚀 **Zero Config** | Works out of the box with sensible defaults |
| 📊 **40 Variations** | 10 unique variations per profile for maximum variety |

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

### 📞 Modem
**Classic dial-up modem connection sounds**
- Dial tones (350Hz + 440Hz) and DTMF dialing sequences
- Handshake negotiation sounds (v.90/v.92 style)
- Connection establishment sequences
- Data transmission beeps
- Failed connection attempts
- Authentic 56k modem experience

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

### Quick Start

```bash
# Download and install
git clone <repository-url>
cd retro-sfxctl
chmod +x retro-sfx-installer.sh
sudo ./retro-sfx-installer.sh
```

### Detailed Steps

#### 1. Clone or Download

```bash
git clone <repository-url>
cd retro-sfxctl
```

#### 2. Run the Installer

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
| `/usr/local/bin/retro-sfxd.py` | Background daemon (Python) |
| `/usr/local/bin/retro-sfxctl.py` | Runtime control CLI |
| `/etc/retro-sfx.conf` | Main configuration file |
| `/etc/systemd/system/retro-sfx.service` | systemd unit file |
| `/run/retro-sfx/` | Runtime state (profile, enable flag) |

### ✅ Verify Installation

After installation, verify the service is running:

```bash
sudo systemctl status retro-sfx.service
sudo retro-sfxctl status
```

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
MODEM_ENABLED_VARIATIONS=all

# Interval between patterns (in minutes, range 1-100 minutes)
# Format: PROFILE_INTERVAL_MIN and PROFILE_INTERVAL_MAX
# Defaults shown (converted from original seconds)
WOPR_INTERVAL_MIN=0.003
WOPR_INTERVAL_MAX=0.025
MAINFRAME_INTERVAL_MIN=0.067
MAINFRAME_INTERVAL_MAX=0.183
ALIENSTERM_INTERVAL_MIN=0.003
ALIENSTERM_INTERVAL_MAX=0.015
MODEM_INTERVAL_MIN=0.017
MODEM_INTERVAL_MAX=0.067

# Number of beeps per pattern run (range 1-20)
# Format: PROFILE_BEEPS_MIN and PROFILE_BEEPS_MAX
WOPR_BEEPS_MIN=1
WOPR_BEEPS_MAX=6
MAINFRAME_BEEPS_MIN=1
MAINFRAME_BEEPS_MAX=2
ALIENSTERM_BEEPS_MIN=1
ALIENSTERM_BEEPS_MAX=4
MODEM_BEEPS_MIN=1
MODEM_BEEPS_MAX=6

# Sound files playback
# Enable/disable playing random sound files from a directory
SOUNDS_ENABLED=0
SOUNDS_DIR=/usr/local/share/retro-sfx/sounds
SOUNDS_DURATION_MIN=5.0
SOUNDS_DURATION_MAX=30.0
SOUNDS_INTERVAL_MIN=1.0
SOUNDS_INTERVAL_MAX=10.0
```

> 🔄 **Changes apply automatically** - no service restart required!

---

## 🎮 Usage

### 🚀 Quick Examples

```bash
# Switch to WOPR profile (fast, chatty sounds)
sudo retro-sfxctl profile wopr

# Switch to Modem profile (dial-up sounds)
sudo retro-sfxctl profile modem

# Temporarily mute sounds
sudo retro-sfxctl off

# Re-enable sounds
sudo retro-sfxctl on

# Test a profile before switching
./retro-sfx-test.sh audio modem
```

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
sudo retro-sfxctl profile modem
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
sudo retro-sfxctl variations modem "0,1,2,3,4"      # First 5 variations
```

#### Configure Pattern Intervals
```bash
# Set interval between patterns (in minutes, 1-100)
# Example: WOPR to play every 1-5 minutes
sudo retro-sfxctl interval wopr 1.0 5.0

# Example: Mainframe to play every 10-30 minutes
sudo retro-sfxctl interval mainframe 10.0 30.0

# Example: Modem to play every 2-10 minutes
sudo retro-sfxctl interval modem 2.0 10.0
```

#### Configure Beep Count
```bash
# Set number of beeps per pattern (1-20)
# Example: WOPR to play 3-8 beeps per pattern
sudo retro-sfxctl beeps wopr 3 8

# Example: Mainframe to play 1-3 beeps per pattern
sudo retro-sfxctl beeps mainframe 1 3

# Example: Modem to play 2-5 beeps per pattern
sudo retro-sfxctl beeps modem 2 5
```

#### Audio Limiter
```bash
sudo retro-sfxctl limiter on
sudo retro-sfxctl limiter off
```

#### Sound File Playback
```bash
# Enable/disable playing random sound files from sounds directory
sudo retro-sfxctl sounds on
sudo retro-sfxctl sounds off

# Set sounds directory path
sudo retro-sfxctl sounds-dir /path/to/sounds

# Set playback duration (1-30 seconds)
sudo retro-sfxctl sounds-duration 5.0 30.0

# Set interval between sound file plays (1-100 minutes)
sudo retro-sfxctl sounds-interval 5.0 20.0
```

> 💡 **PC Speaker Support:** When using PC speaker output mode, sound files are automatically converted to beep sequences. The system analyzes each audio file and generates representative beep patterns (5-15 beeps) that play through the piezo speaker, creating a retro-computer interpretation of the sound.

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

Use the test script to verify audio output and test different profiles:

#### Basic Usage

```bash
# Test PC speaker
./retro-sfx-test.sh pcspkr wopr

# Test external audio
./retro-sfx-test.sh audio mainframe

# Test alien terminal
./retro-sfx-test.sh audio aliensterm

# Test modem sounds
./retro-sfx-test.sh audio modem
```

#### Advanced Options

```bash
# Test all profiles sequentially
./retro-sfx-test.sh audio all

# Repeat a test multiple times
./retro-sfx-test.sh audio wopr -r 3
./retro-sfx-test.sh audio modem --repeat 5

# Adjust audio volume/gain
./retro-sfx-test.sh audio modem -v 1.5
./retro-sfx-test.sh audio wopr --volume 2.0

# Combine options
./retro-sfx-test.sh audio mainframe -r 2 -v 1.8

# List all available profiles
./retro-sfx-test.sh list
```

#### Test Script Options

| Option | Description | Example |
|--------|-------------|---------|
| `-r, --repeat N` | Repeat test N times | `-r 3` |
| `-v, --volume GAIN` | Set audio gain (default: 1.2) | `-v 1.5` |
| `all` | Test all profiles sequentially | `audio all` |
| `list` | List available profiles | `list` |

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
- 💻 Works best on **physical hardware** (PC speaker support)
- 🎨 **4 profiles × 10 variations = 40 unique sound patterns**
- ⚡ **Zero-downtime configuration** - changes apply instantly
- 🎵 **Randomized timing** - each sound plays with variable frequency, duration, and pauses
- 🔧 **Fully configurable** - quiet hours, variation selection, output modes

## 🎯 Use Cases

- **Home Lab**: Add ambient computing atmosphere
- **Office/Desk**: Nostalgic background sounds
- **Demos**: Showcase retro computing aesthetics
- **NOC/Data Center**: Ambient monitoring sounds
- **Gaming Setup**: Retro computing ambiance
- **Server Room**: Authentic mainframe atmosphere

---

---

<div align="center">

**Made with ❤️ for retro computing enthusiasts**

*Bring the nostalgia of classic computing to your modern Linux system!*

[Report Issues](https://github.com/your-repo/issues) • [Contributing](https://github.com/your-repo) • [License](LICENSE)

</div>
