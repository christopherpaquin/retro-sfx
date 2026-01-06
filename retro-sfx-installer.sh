#!/usr/bin/env bash
#
# retro-sfx-installer.sh
#
# Installs a "retro computer sounds" daemon with:
#  - Profiles: wopr | mainframe | aliensterm
#  - Quiet hours
#  - Switchable output: pcspkr | audio | random
#  - Audio soft limiter (SoX compand)
#  - Runtime control CLI (retro-sfxctl)
#  - systemd service (retro-sfx.service)
#
# Supported distros: RHEL/Rocky/Alma/Fedora (dnf) and Debian/Ubuntu (apt)
#
set -euo pipefail

# -------------------------
# Variables (edit if needed)
# -------------------------
SERVICE_NAME="retro-sfx"
DAEMON_PATH="/usr/local/bin/retro-sfxd.py"
CTL_PATH="/usr/local/bin/retro-sfxctl.py"
CONF_PATH="/etc/retro-sfx.conf"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
INSTALLER_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default config values
DEFAULT_PROFILE="mainframe"
DEFAULT_OUTPUT_MODE="random"         # pcspkr|audio|random
DEFAULT_RANDOM_AUDIO_PERCENT="70"    # 0-100
DEFAULT_AUDIO_DEVICE="default"
DEFAULT_AUDIO_GAIN="1.2"  # Increased for better audibility

DEFAULT_QUIET_ENABLED="1"
DEFAULT_QUIET_START="22:00"
DEFAULT_QUIET_END="07:00"

DEFAULT_LIMITER_ENABLED="0"  # Disabled by default - can be enabled if needed
DEFAULT_LIM_ATTACK="0.005"
DEFAULT_LIM_DECAY="0.10"
DEFAULT_LIM_SOFTKNEE="6"
DEFAULT_LIM_TARGET_DB="-3"

# -------------------------
# Helpers
# -------------------------
need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run as root (sudo)." >&2
    exit 1
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_pkg_mgr() {
  if have_cmd dnf; then
    echo "dnf"
  elif have_cmd apt-get; then
    echo "apt"
  else
    echo "ERROR: Unsupported system (need dnf or apt-get)." >&2
    exit 1
  fi
}

install_pkgs() {
  local mgr="$1"
  case "$mgr" in
    dnf)
      dnf install -y python3 beep alsa-utils sox || {
        echo "ERROR: Failed to install packages via dnf." >&2
        exit 1
      }
      ;;
    apt)
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y python3 beep alsa-utils sox || {
        echo "ERROR: Failed to install packages via apt-get." >&2
        exit 1
      }
      ;;
  esac
}

ensure_pcspkr_load() {
  # Load now
  modprobe pcspkr 2>/dev/null || true
  # Load at boot
  echo "pcspkr" > /etc/modules-load.d/pcspkr.conf
}

set_beep_suid() {
  if [[ -x /usr/bin/beep ]]; then
    chmod u+s /usr/bin/beep || true
  fi
}

write_conf_if_missing() {
  if [[ -f "$CONF_PATH" ]]; then
    return
  fi

  cat > "$CONF_PATH" <<EOF
# /etc/retro-sfx.conf
#
# Quiet hours in 24h local time.
# Set QUIET_ENABLED=0 to disable quiet hours
QUIET_ENABLED=${DEFAULT_QUIET_ENABLED}
QUIET_START="${DEFAULT_QUIET_START}"
QUIET_END="${DEFAULT_QUIET_END}"

# Output backend: pcspkr | audio | random
OUTPUT_MODE=${DEFAULT_OUTPUT_MODE}

# If OUTPUT_MODE=random:
# Probability (0-100) of choosing external audio for each event; remainder uses pcspkr.
RANDOM_AUDIO_PERCENT=${DEFAULT_RANDOM_AUDIO_PERCENT}

# Audio backend (used when OUTPUT_MODE=audio or random->audio)
AUDIO_DEVICE=${DEFAULT_AUDIO_DEVICE}
AUDIO_GAIN=${DEFAULT_AUDIO_GAIN}

# Soft limiter settings (SoX compand)
LIMITER_ENABLED=${DEFAULT_LIMITER_ENABLED}
LIM_ATTACK=${DEFAULT_LIM_ATTACK}
LIM_DECAY=${DEFAULT_LIM_DECAY}
LIM_SOFTKNEE=${DEFAULT_LIM_SOFTKNEE}
LIM_TARGET_DB=${DEFAULT_LIM_TARGET_DB}

# Sound pattern selection
# Each profile has 10 variations (0-9). Specify which variations to use:
#   - "all" = use all variations (default)
#   - "0,1,2,3" = use only specified variations (comma-separated)
# Examples:
#   WOPR_ENABLED_VARIATIONS="0,1,2,3,4"  # Use only first 5 variations
#   MAINFRAME_ENABLED_VARIATIONS="all"    # Use all variations
WOPR_ENABLED_VARIATIONS=all
MAINFRAME_ENABLED_VARIATIONS=all
ALIENSTERM_ENABLED_VARIATIONS=all
MODEM_ENABLED_VARIATIONS=all

# Interval between patterns (in minutes, range 1-100 minutes)
# Format: PROFILE_INTERVAL_MIN and PROFILE_INTERVAL_MAX
# Defaults shown below (converted from original seconds)
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
# Note: If sounds directory exists in installer directory, it will be copied automatically
SOUNDS_DURATION_MIN=5.0
SOUNDS_DURATION_MAX=30.0
SOUNDS_INTERVAL_MIN=1.0
SOUNDS_INTERVAL_MAX=10.0
EOF

  chmod 0644 "$CONF_PATH"
}

write_daemon() {
  # Copy Python daemon script
  if [[ -f "${INSTALLER_DIR}/retro-sfxd.py" ]]; then
    cp "${INSTALLER_DIR}/retro-sfxd.py" "$DAEMON_PATH"
    chmod 0755 "$DAEMON_PATH"
  else
    echo "ERROR: retro-sfxd.py not found in installer directory" >&2
    exit 1
  fi
}

write_daemon_old() {
  cat > "$DAEMON_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

RUNDIR="/run/retro-sfx"
PROFILE_FILE="$RUNDIR/profile"
ENABLED_FILE="$RUNDIR/enabled"
CONF="/etc/retro-sfx.conf"

mkdir -p "$RUNDIR"
chmod 755 "$RUNDIR"

# Defaults if runtime state missing
[[ -f "$PROFILE_FILE" ]] || echo "mainframe" > "$PROFILE_FILE"
[[ -f "$ENABLED_FILE" ]] || echo "1" > "$ENABLED_FILE"

read_profile() {
  local p
  p="$(cat "$PROFILE_FILE" 2>/dev/null || echo "mainframe")"
  case "$p" in
    wopr|mainframe|aliensterm) echo "$p" ;;
    *) echo "mainframe" ;;
  esac
}

is_enabled() {
  [[ "$(cat "$ENABLED_FILE" 2>/dev/null || echo 1)" == "1" ]]
}

load_conf() {
  QUIET_ENABLED=0
  QUIET_START="22:00"
  QUIET_END="07:00"

  OUTPUT_MODE="pcspkr"          # pcspkr|audio|random
  RANDOM_AUDIO_PERCENT=50       # 0-100

  AUDIO_DEVICE="default"
  AUDIO_GAIN="1.2"

  LIMITER_ENABLED=0
  LIM_ATTACK="0.005"
  LIM_DECAY="0.10"
  LIM_SOFTKNEE="6"
  LIM_TARGET_DB="-3"

  [[ -f "$CONF" ]] && source "$CONF" || true

  [[ "${OUTPUT_MODE}" =~ ^(pcspkr|audio|random)$ ]] || OUTPUT_MODE="pcspkr"
  [[ "${RANDOM_AUDIO_PERCENT}" =~ ^[0-9]+$ ]] || RANDOM_AUDIO_PERCENT=50
  (( RANDOM_AUDIO_PERCENT < 0 )) && RANDOM_AUDIO_PERCENT=0
  (( RANDOM_AUDIO_PERCENT > 100 )) && RANDOM_AUDIO_PERCENT=100
  [[ "${LIMITER_ENABLED}" == "1" ]] || LIMITER_ENABLED=0
}

to_minutes() {
  local t="$1"
  local hh="${t%%:*}"
  local mm="${t##*:}"
  echo $((10#$hh * 60 + 10#$mm))
}

in_quiet_hours() {
  load_conf
  [[ "$QUIET_ENABLED" == "1" ]] || return 1

  local now_hm now_min start_min end_min
  now_hm="$(date +%H:%M)"
  now_min="$(to_minutes "$now_hm")"
  start_min="$(to_minutes "$QUIET_START")"
  end_min="$(to_minutes "$QUIET_END")"

  if (( start_min == end_min )); then
    return 0
  fi

  if (( start_min < end_min )); then
    (( now_min >= start_min && now_min < end_min ))
    return
  else
    (( now_min >= start_min || now_min < end_min ))
    return
  fi
}

has_pcspkr() {
  # Check if pcspkr module is loaded
  if ! lsmod | grep -q "^pcspkr"; then
    return 1
  fi
  # Check if beep command exists and is executable
  if ! command -v beep >/dev/null 2>&1; then
    return 1
  fi
  # Check if /dev/input/by-path/platform-pcspkr-* exists (indicates hardware)
  # or if beep can access the speaker (check permissions)
  if [[ -d /dev/input/by-path ]] && ls /dev/input/by-path/*pcspkr* >/dev/null 2>&1; then
    return 0
  fi
  # If we can't verify hardware, assume it might work if module is loaded
  # This is a conservative check - actual beep might still fail, but we try
  return 0
}

has_audio() {
  # Check if any audio hardware exists
  # Check for ALSA sound cards
  if [[ -f /proc/asound/cards ]]; then
    # If file exists but is empty or only has "---", no sound cards
    local card_count
    card_count=$(grep -c "^ [0-9]" /proc/asound/cards 2>/dev/null || echo "0")
    if (( card_count > 0 )); then
      return 0
    fi
  fi
  
  # Check if aplay can list any devices
  if command -v aplay >/dev/null 2>&1; then
    if aplay -l 2>/dev/null | grep -q "^card"; then
      return 0
    fi
  fi
  
  # Check for USB audio devices
  if ls /sys/class/sound/card* >/dev/null 2>&1; then
    return 0
  fi
  
  return 1
}

detect_audio_device() {
  # First check if any audio hardware exists
  if ! has_audio; then
    echo "none"
    return 1
  fi
  
  # Try to detect the best available audio device
  # Priority: pipewire > pulse > alsa cards > default
  if command -v aplay >/dev/null 2>&1; then
    # Check for pipewire
    if aplay -D pipewire -l >/dev/null 2>&1 || aplay -L 2>/dev/null | grep -q pipewire; then
      echo "pipewire"
      return 0
    fi
    # Check for pulse
    if aplay -D pulse -l >/dev/null 2>&1 || aplay -L 2>/dev/null | grep -q pulse; then
      echo "pulse"
      return 0
    fi
    # Check for ALSA cards (common on servers with USB audio)
    if aplay -l 2>/dev/null | grep -q "^card"; then
      # Try to find a working card
      local cards
      cards=$(aplay -l 2>/dev/null | grep "^card" | head -1 | sed 's/^card \([0-9]*\):.*/\1/' || echo "")
      if [[ -n "$cards" ]]; then
        # Try hw:card,0 format
        if aplay -D "hw:${cards},0" -l >/dev/null 2>&1; then
          echo "hw:${cards},0"
          return 0
        fi
      fi
    fi
  fi
  
  # Fallback to default (may not work on servers, but we try)
  echo "default"
  return 0
}

pick_output_mode() {
  load_conf
  local pcspkr_available audio_available
  pcspkr_available=false
  audio_available=false
  
  has_pcspkr && pcspkr_available=true
  has_audio && audio_available=true

  case "$OUTPUT_MODE" in
    pcspkr)
      if $pcspkr_available; then
        echo "pcspkr"
      elif $audio_available; then
        # Fallback to audio if PC speaker not available
        echo "audio"
      else
        # No audio hardware available
        echo "none"
      fi
      ;;
    audio)
      if $audio_available; then
        echo "audio"
      else
        # No audio hardware, try PC speaker as fallback
        if $pcspkr_available; then
          echo "pcspkr"
        else
          echo "none"
        fi
      fi
      ;;
    random)
      if $pcspkr_available && $audio_available; then
        # Both available, use random selection
        local roll=$((RANDOM % 100))
        if (( roll < RANDOM_AUDIO_PERCENT )); then
          echo "audio"
        else
          echo "pcspkr"
        fi
      elif $audio_available; then
        # Only audio available
        echo "audio"
      elif $pcspkr_available; then
        # Only PC speaker available
        echo "pcspkr"
      else
        # No audio hardware available
        echo "none"
      fi
      ;;
  esac
}

play_pcspkr() {
  # Try to play via PC speaker, but fallback to audio if it fails
  if ! beep -f "$1" -l "$2" 2>/dev/null; then
    # PC speaker failed, fallback to audio
    load_conf
    play_audio "$1" "$2"
  fi
}

play_audio() {
  local freq="$1"
  local dur_ms="$2"
  # Ensure minimum duration for audibility (at least 30ms)
  if (( $(echo "$dur_ms < 30" | bc -l 2>/dev/null || echo 0) )); then
    dur_ms=30
  fi
  local dur_s
  dur_s=$(awk "BEGIN { printf \"%.3f\", $dur_ms/1000 }")

  # Check if audio hardware is available
  if ! has_audio; then
    # No audio hardware, silently skip
    return 0
  fi

  # Auto-detect audio device if not explicitly set or if default fails
  local device="$AUDIO_DEVICE"
  if [[ "$device" == "default" ]] || [[ "$device" == "none" ]] || ! aplay -D "$device" -l >/dev/null 2>&1; then
    device="$(detect_audio_device)"
    if [[ "$device" == "none" ]]; then
      # No audio device found, silently skip
      return 0
    fi
  fi

  if command -v sox >/dev/null 2>&1; then
    # Use pipewire first (we know it works), then fallback to other devices
    # Use stereo (c 2) and explicit format flag for aplay
    if [[ "$LIMITER_ENABLED" == "1" ]]; then
      sox -n -r 44100 -c 2 -b 16 -t wav - \
        synth "$dur_s" sine "$freq" vol "$AUDIO_GAIN" \
        compand "$LIM_ATTACK","$LIM_DECAY" "$LIM_SOFTKNEE":-inf,0,-inf "$LIM_TARGET_DB" \
        gain -n \
        2>/dev/null | aplay -D pipewire -f cd 2>/dev/null || \
      sox -n -r 44100 -c 2 -b 16 -t wav - \
        synth "$dur_s" sine "$freq" vol "$AUDIO_GAIN" \
        compand "$LIM_ATTACK","$LIM_DECAY" "$LIM_SOFTKNEE":-inf,0,-inf "$LIM_TARGET_DB" \
        gain -n \
        2>/dev/null | aplay -D default -f cd 2>/dev/null || true
    else
      sox -n -r 44100 -c 2 -b 16 -t wav - \
        synth "$dur_s" sine "$freq" vol "$AUDIO_GAIN" \
        2>/dev/null | aplay -D pipewire -f cd 2>/dev/null || \
      sox -n -r 44100 -c 2 -b 16 -t wav - \
        synth "$dur_s" sine "$freq" vol "$AUDIO_GAIN" \
        2>/dev/null | aplay -D default -f cd 2>/dev/null || true
    fi
  else
    speaker-test -q -D "$device" -t sine -f "$freq" -l 1 >/dev/null 2>&1 &
    local pid=$!
    sleep "$dur_s"
    kill "$pid" >/dev/null 2>&1 || true
  fi
}

# Sound primitive used by all patterns
b() {
  local mode
  mode="$(pick_output_mode)"
  case "$mode" in
    pcspkr) play_pcspkr "$1" "$2" ;;
    audio)  play_audio  "$1" "$2" ;;
    none)   ;;  # No audio hardware available, silently skip
    *)      ;;  # Unknown mode, silently skip
  esac
}

# -------------------------
# Profiles
# -------------------------
pattern_wopr() {
  local r=$((RANDOM % 10))
  case "$r" in
    0|1) b 1200 40; b 900 35; b 1600 50 ;;
    2|3) b 700 70; b 1100 40; b 700 40 ;;
    4)   b 300 200 ;;
    5)   b 1500 30; b 1700 30; b 1900 40 ;;
    6|7) b 800 60; b 600 80 ;;
    8)   b 1000 35; b 1000 35; b 600 120 ;;
    9)   b 400 140; b 900 50 ;;
  esac
  sleep 0.$((RANDOM % 6 + 2))
}

pattern_mainframe() {
  local r=$((RANDOM % 10))
  case "$r" in
    0|1|2) b 300 80 ;;
    3|4)   b 260 120 ;;
    5)     b 420 60; b 320 60 ;;
    6)     b 220 180 ;;
    7|8)   b 500 30; b 500 30 ;;
    9)     b 180 260 ;;
  esac
  sleep $((RANDOM % 8 + 4))
}

pattern_aliensterm() {
  local r=$((RANDOM % 10))
  case "$r" in
    0|1) b 1400 35; b 1200 35; b 1000 45 ;;
    2)   b 1800 25; b 700 90 ;;
    3|4) b 1600 40; b 2000 20; b 1600 40 ;;
    5)   b 900 60; b 1300 60; b 900 60 ;;
    6)   b 2100 18; b 1900 18; b 1700 18; b 1500 18 ;;
    7)   b 600 160; b 1400 40 ;;
    8)   b 1000 30; b 1500 30; b 2000 30; b 1200 60 ;;
    9)   b 2400 15; b 800 120 ;;
  esac
  sleep 0.$((RANDOM % 8 + 2))
}

# Main loop
while true; do
  if ! is_enabled || in_quiet_hours; then
    sleep 2
    continue
  fi

  prof="$(read_profile)"
  case "$prof" in
    wopr)       pattern_wopr ;;
    mainframe)  pattern_mainframe ;;
    aliensterm) pattern_aliensterm ;;
  esac
done
EOF

  chmod 0755 "$DAEMON_PATH"
}

write_ctl() {
  # Copy Python control script
  if [[ -f "${INSTALLER_DIR}/retro-sfxctl.py" ]]; then
    cp "${INSTALLER_DIR}/retro-sfxctl.py" "$CTL_PATH"
    chmod 0755 "$CTL_PATH"
  else
    echo "ERROR: retro-sfxctl.py not found in installer directory" >&2
    exit 1
  fi
  
  # Create wrapper script at /usr/local/bin/retro-sfxctl (without .py)
  # This allows users to call "retro-sfxctl" instead of "retro-sfxctl.py"
  cat > "/usr/local/bin/retro-sfxctl" <<EOF
#!/usr/bin/env bash
exec /usr/bin/python3 "$CTL_PATH" "\$@"
EOF
  chmod 0755 "/usr/local/bin/retro-sfxctl"
}

write_ctl_old() {
  cat > "$CTL_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

RUNDIR="/run/retro-sfx"
PROFILE_FILE="$RUNDIR/profile"
ENABLED_FILE="$RUNDIR/enabled"
CONF="/etc/retro-sfx.conf"

usage() {
  cat <<'USAGE'
Usage:
  retro-sfxctl status
  retro-sfxctl on
  retro-sfxctl off
  retro-sfxctl profile <wopr|mainframe|aliensterm>
  retro-sfxctl output <pcspkr|audio|random>
  retro-sfxctl random-audio <0-100>
  retro-sfxctl limiter <on|off>
USAGE
}

cmd="${1:-}"
mkdir -p "$RUNDIR"

case "$cmd" in
  status)
    prof="$(cat "$PROFILE_FILE" 2>/dev/null || echo "mainframe")"
    en="$(cat "$ENABLED_FILE" 2>/dev/null || echo "1")"
    out="$(grep -E '^OUTPUT_MODE=' "$CONF" 2>/dev/null | head -n1 | cut -d= -f2 || echo "pcspkr")"
    pcent="$(grep -E '^RANDOM_AUDIO_PERCENT=' "$CONF" 2>/dev/null | head -n1 | cut -d= -f2 || echo "50")"
    lim="$(grep -E '^LIMITER_ENABLED=' "$CONF" 2>/dev/null | head -n1 | cut -d= -f2 || echo "0")"
    echo "enabled=$en profile=$prof output=$out random_audio_percent=$pcent limiter=$lim"
    ;;

  on)  echo "1" > "$ENABLED_FILE" ;;
  off) echo "0" > "$ENABLED_FILE" ;;

  profile)
    p="${2:-}"
    case "$p" in
      wopr|mainframe|aliensterm) echo "$p" > "$PROFILE_FILE" ;;
      *) usage; exit 2 ;;
    esac
    ;;

  output)
    m="${2:-}"
    case "$m" in
      pcspkr|audio|random)
        if [[ -f "$CONF" ]]; then
          sed -i "s/^OUTPUT_MODE=.*/OUTPUT_MODE=$m/" "$CONF" || true
        else
          echo "OUTPUT_MODE=$m" > "$CONF"
        fi
        ;;
      *) usage; exit 2 ;;
    esac
    ;;

  random-audio)
    p="${2:-}"
    [[ "$p" =~ ^[0-9]+$ ]] || { usage; exit 2; }
    (( p < 0 )) && p=0
    (( p > 100 )) && p=100
    if [[ -f "$CONF" ]]; then
      sed -i "s/^RANDOM_AUDIO_PERCENT=.*/RANDOM_AUDIO_PERCENT=$p/" "$CONF" || true
    else
      echo "RANDOM_AUDIO_PERCENT=$p" > "$CONF"
    fi
    ;;

  limiter)
    v="${2:-}"
    case "$v" in
      on)  sed -i "s/^LIMITER_ENABLED=.*/LIMITER_ENABLED=1/" "$CONF" || true ;;
      off) sed -i "s/^LIMITER_ENABLED=.*/LIMITER_ENABLED=0/" "$CONF" || true ;;
      *) usage; exit 2 ;;
    esac
    ;;

  *)
    usage
    exit 2
    ;;
esac
EOF

  chmod 0755 "$CTL_PATH"
}

write_unit() {
  # Detect the primary user (first non-root user with a home directory)
  local service_user=""
  if [[ -n "${SUDO_USER:-}" ]]; then
    service_user="${SUDO_USER}"
  else
    # Try to find the first regular user
    service_user=$(getent passwd | awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}')
  fi
  
  # If we found a user, run as that user; otherwise run as root (for servers)
  if [[ -n "$service_user" ]]; then
    local user_id
    user_id=$(id -u "$service_user" 2>/dev/null || echo "")
    cat > "$UNIT_PATH" <<EOF
[Unit]
Description=Retro PC Speaker / Audio SFX Daemon (Python)
After=multi-user.target sound.target

[Service]
Type=simple
User=${service_user}
ExecStart=/usr/bin/python3 ${DAEMON_PATH}
Restart=always
RestartSec=2
RuntimeDirectory=retro-sfx
RuntimeDirectoryMode=0755
# Allow access to user's audio session
Environment="XDG_RUNTIME_DIR=/run/user/${user_id}"
Environment="PULSE_RUNTIME_PATH=/run/user/${user_id}/pulse"

[Install]
WantedBy=multi-user.target
EOF
  else
    # Fallback: run as root (for headless servers)
    cat > "$UNIT_PATH" <<EOF
[Unit]
Description=Retro PC Speaker / Audio SFX Daemon (Python)
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${DAEMON_PATH}
Restart=always
RestartSec=2
RuntimeDirectory=retro-sfx
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
  fi
}

enable_service() {
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.service"
}

# -------------------------
# Main
# -------------------------
need_root

mgr="$(detect_pkg_mgr)"
install_pkgs "$mgr"
ensure_pcspkr_load
set_beep_suid

write_conf_if_missing
write_daemon
write_ctl
write_unit

enable_service

cat <<EOF

Installed:
  - Daemon:   ${DAEMON_PATH}
  - Control:  ${CTL_PATH}
  - Config:   ${CONF_PATH}
  - Service:  ${UNIT_PATH}

Common commands:
  sudo retro-sfxctl status
  sudo retro-sfxctl profile wopr
  sudo retro-sfxctl output random
  sudo retro-sfxctl random-audio 70
  sudo retro-sfxctl limiter on
  sudo retro-sfxctl off   # mute without stopping service
  sudo retro-sfxctl on

Service control:
  sudo systemctl status ${SERVICE_NAME}.service
  sudo systemctl stop ${SERVICE_NAME}.service

EOF

