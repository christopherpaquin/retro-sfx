#!/usr/bin/env bash
#
# retro-sfx-test.sh
#
# Interactive test tool for Retro SFX
# Tests:
#   - Output: pcspkr | audio
#   - Profiles: wopr | mainframe | aliensterm | modem | all
#
# Usage:
#   $0 <output> <profile> [options]
#   $0 <output> all        # Test all profiles
#   $0 list                # List available profiles
#
# Options:
#   -r, --repeat N        Repeat test N times (default: 1)
#   -v, --volume GAIN     Set audio gain (default: 1.2)
#
# Requirements:
#   - beep (pcspkr)
#   - sox + aplay (audio output)
#
# Note: If beep doesn't have SUID bit set, you may need to run with sudo
#       or set it manually: sudo chmod u+s /usr/bin/beep
#

set -euo pipefail

# -------------------------
# Configurable defaults
# -------------------------
AUDIO_DEVICE="default"  # Will auto-detect if "default" doesn't work
AUDIO_GAIN="1.2"  # Increased for better audibility (was 0.6)

LIMITER_ENABLED=0  # Disabled for testing - was reducing volume too much
LIM_ATTACK="0.005"
LIM_DECAY="0.10"
LIM_SOFTKNEE="6"
LIM_TARGET_DB="-3"

# -------------------------
# Helpers
# -------------------------
REPEAT=1
VOLUME="$AUDIO_GAIN"

usage() {
  cat <<EOF
Usage:
  $0 <output> <profile> [options]
  $0 <output> all        # Test all profiles
  $0 list                # List available profiles

Output modes:
  pcspkr    - PC speaker/piezo buzzer
  audio     - External audio (speakers/headphones)

Profiles:
  wopr       - Fast, chatty WarGames-style sounds
  mainframe  - Slow, ambient mainframe sounds
  aliensterm - Sci-fi terminal sounds
  modem      - Dial-up modem connection sounds
  all        - Test all profiles sequentially

Options:
  -r, --repeat N    Repeat test N times (default: 1)
  -v, --volume GAIN Set audio gain (default: 1.2)

Examples:
  $0 pcspkr wopr
  $0 audio mainframe
  $0 audio modem
  $0 audio all
  $0 audio wopr -r 3
  $0 audio modem -v 1.5
  $0 list
EOF
  exit 1
}

list_profiles() {
  cat <<EOF
Available Profiles:
  wopr       - Fast, chatty WarGames-style console sounds
  mainframe  - Slow, low, ambient computer-room noises
  aliensterm - Higher-pitched, eerie sci-fi terminal tones
  modem      - Classic dial-up modem connection sounds

Each profile has 10 variations that play randomly.
EOF
  exit 0
}

# Parse arguments
if [[ $# -eq 0 ]]; then
  usage
fi

# Handle list command
if [[ "$1" == "list" ]]; then
  list_profiles
fi

# Parse arguments - simple approach: first two args are output and profile
# Then parse options
OUTPUT=""
PROFILE=""
ARGS=()

# Collect positional args and options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repeat)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --repeat requires a number" >&2
        usage
      fi
      REPEAT="$2"
      shift 2
      ;;
    -v|--volume)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --volume requires a number" >&2
        usage
      fi
      VOLUME="$2"
      AUDIO_GAIN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# Extract output and profile from positional args
if [[ ${#ARGS[@]} -lt 2 ]]; then
  echo "ERROR: Missing required arguments" >&2
  usage
fi

OUTPUT="${ARGS[0]}"
PROFILE="${ARGS[1]}"

case "$OUTPUT" in
  pcspkr|audio) ;;
  *) usage ;;
esac

case "$PROFILE" in
  wopr|mainframe|aliensterm|modem|all) ;;
  *) 
    echo "ERROR: Invalid profile '$PROFILE'" >&2
    echo "Valid profiles: wopr, mainframe, aliensterm, modem, all" >&2
    usage
    ;;
esac

# Validate repeat count
if ! [[ "$REPEAT" =~ ^[0-9]+$ ]] || [[ "$REPEAT" -lt 1 ]]; then
  echo "ERROR: Repeat count must be a positive integer" >&2
  exit 1
fi

# -------------------------
# Detection functions
# -------------------------
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
  # Priority: pipewire > pulse > laptop built-in audio > alsa cards > default
  if command -v aplay >/dev/null 2>&1; then
    # Check for pipewire (best for modern systems)
    if aplay -D pipewire -l >/dev/null 2>&1 || aplay -L 2>/dev/null | grep -q pipewire; then
      echo "pipewire"
      return 0
    fi
    # Check for pulse
    if aplay -D pulse -l >/dev/null 2>&1 || aplay -L 2>/dev/null | grep -q pulse; then
      echo "pulse"
      return 0
    fi
    # Check for laptop built-in audio (often card 3, device 0 for headphones)
    # Look for HDA Analog or similar laptop audio
    if aplay -l 2>/dev/null | grep -q "HDA Analog"; then
      local hda_card
      hda_card=$(aplay -l 2>/dev/null | grep "HDA Analog" | head -1 | sed 's/^card \([0-9]*\):.*/\1/' || echo "")
      if [[ -n "$hda_card" ]]; then
        if aplay -D "hw:${hda_card},0" -l >/dev/null 2>&1; then
          echo "hw:${hda_card},0"
          return 0
        fi
      fi
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

# -------------------------
# Output backends
# -------------------------
check_beep_permissions() {
  # Check if beep has SUID bit set or if user can access PC speaker
  local beep_path
  beep_path="$(command -v beep 2>/dev/null || echo "/usr/bin/beep")"
  
  if [[ -x "$beep_path" ]]; then
    # Check if beep has SUID bit
    if [[ -u "$beep_path" ]]; then
      return 0  # SUID set, should work
    fi
    # Check if running as root
    if [[ "${EUID}" -eq 0 ]]; then
      return 0  # Running as root, should work
    fi
    # Check if user is in audio group (some distros use this)
    if groups | grep -q '\baudio\b'; then
      return 0  # In audio group, might work
    fi
  fi
  return 1  # May need sudo
}

suggest_fix_permissions() {
  local beep_path
  beep_path="$(command -v beep 2>/dev/null || echo "/usr/bin/beep")"
  
  if [[ -x "$beep_path" ]] && [[ ! -u "$beep_path" ]] && [[ "${EUID}" -ne 0 ]]; then
    echo ""
    echo "To fix PC speaker permissions, run one of:"
    echo "  sudo chmod u+s $beep_path"
    echo "  OR run the installer: sudo ./retro-sfx-installer.sh"
    echo ""
    echo "Note: Modern beep refuses to run via sudo for security reasons."
    echo "      Setting SUID on beep is the recommended approach."
    echo ""
  fi
}

play_pcspkr() {
  # Modern beep refuses to run as root/sudo for security reasons
  # So we only try if we have proper permissions (SUID or device access)
  if ! check_beep_permissions; then
    # No permissions, fallback to audio immediately
    # Don't try sudo - beep will refuse it anyway
    play_audio "$1" "$2"
    return 0
  fi
  
  # Try to play via PC speaker, but fallback to audio if it fails
  # Suppress stderr to avoid error spam, but capture exit code
  if beep -f "$1" -l "$2" 2>/dev/null; then
    return 0
  else
    # PC speaker failed, fallback to audio
    play_audio "$1" "$2"
  fi
}

play_audio() {
  local freq="$1"
  local dur_ms="$2"
  # Ensure minimum duration for audibility (at least 20ms)
  if (( $(echo "$dur_ms < 20" | bc -l 2>/dev/null || echo 0) )); then
    dur_ms=20
  fi
  local dur_s
  dur_s=$(awk "BEGIN { printf \"%.3f\", $dur_ms/1000 }")

  # Check if audio hardware is available
  if ! has_audio; then
    # No audio hardware, silently skip
    echo "Warning: No audio hardware detected, skipping audio output" >&2
    return 0
  fi

  # Auto-detect audio device if not explicitly set or if default fails
  local device="$AUDIO_DEVICE"
  if [[ "$device" == "default" ]] || [[ "$device" == "none" ]] || ! aplay -D "$device" -l >/dev/null 2>&1; then
    device="$(detect_audio_device)"
    if [[ "$device" == "none" ]]; then
      # No audio device found, silently skip
      echo "Warning: No audio device found, skipping audio output" >&2
      return 0
    fi
  fi

  if command -v sox >/dev/null 2>&1; then
    # Use pipewire directly since we know it works
    # Always try pipewire first, then default
    # Simplified - no limiter for testing, just direct audio
    sox -n -r 44100 -c 2 -b 16 -t wav - \
      synth "$dur_s" sine "$freq" vol "$AUDIO_GAIN" \
      2>/dev/null | aplay -D pipewire -f cd 2>/dev/null || \
    sox -n -r 44100 -c 2 -b 16 -t wav - \
      synth "$dur_s" sine "$freq" vol "$AUDIO_GAIN" \
      2>/dev/null | aplay -D default -f cd 2>/dev/null || true
  else
    speaker-test -q -D "$device" -t sine -f "$freq" -l 1 >/dev/null 2>&1 &
    local pid=$!
    sleep "$dur_s"
    kill "$pid" >/dev/null 2>&1 || true
  fi
}

b() {
  local actual_output="$OUTPUT"
  
  # If pcspkr was requested but not available, fallback to audio
  if [[ "$OUTPUT" == "pcspkr" ]] && ! has_pcspkr; then
    if has_audio; then
      actual_output="audio"
    else
      echo "Warning: Neither PC speaker nor audio hardware available, skipping sound" >&2
      return 0
    fi
  fi
  
  # If audio was requested but not available, try PC speaker
  if [[ "$OUTPUT" == "audio" ]] && ! has_audio; then
    if has_pcspkr; then
      actual_output="pcspkr"
    else
      echo "Warning: No audio hardware available, skipping sound" >&2
      return 0
    fi
  fi
  
  case "$actual_output" in
    pcspkr) play_pcspkr "$1" "$2" ;;
    audio)  play_audio  "$1" "$2" ;;
    *)      ;;  # Unknown mode, silently skip
  esac
}

# -------------------------
# Test patterns
# -------------------------
test_wopr() {
  echo "Testing WOPR profile..."
  b 1200 40; b 900 35; b 1600 50
  sleep 0.4
  b 700 70; b 1100 40; b 700 40
  sleep 0.4
  b 1500 30; b 1700 30; b 1900 40
  sleep 0.6
  b 300 200
}

test_mainframe() {
  echo "Testing MAINFRAME profile..."
  b 300 80
  sleep 0.8
  b 260 120
  sleep 1.2
  b 420 60; b 320 60
  sleep 1.0
  b 180 260
}

test_aliensterm() {
  echo "Testing ALIEN TERMINAL profile..."
  b 1400 35; b 1200 35; b 1000 45
  sleep 0.3
  b 1600 40; b 2000 20; b 1600 40
  sleep 0.4
  b 2100 18; b 1900 18; b 1700 18; b 1500 18
  sleep 0.5
  b 2400 15; b 800 120
}

test_modem() {
  echo "Testing MODEM profile..."
  # Dial tone
  b 350 100; b 440 100
  sleep 0.2
  # DTMF dialing
  b 697 60; b 770 60; b 852 60; b 941 60
  sleep 0.3
  # Handshake sequence
  b 600 60; b 900 50; b 1200 40; b 1500 30
  sleep 0.4
  # Connection established
  b 1000 30; b 1200 30; b 1400 30; b 1600 30
}

# -------------------------
# Run test
# -------------------------
echo "--------------------------------"
echo "Retro SFX Test"
echo "Output : $OUTPUT"
echo "Profile: $PROFILE"
if [[ "$REPEAT" -gt 1 ]]; then
  echo "Repeat : $REPEAT times"
fi
if [[ "$OUTPUT" == "audio" ]] && [[ "$VOLUME" != "1.2" ]]; then
  echo "Volume : $VOLUME"
fi

# Check PC speaker availability and permissions
if [[ "$OUTPUT" == "pcspkr" ]]; then
  if has_pcspkr; then
    echo "PC Speaker: Available"
    if check_beep_permissions; then
      echo "PC Speaker Permissions: OK"
    else
      echo "PC Speaker Permissions: May need sudo (or run installer to set SUID)"
      suggest_fix_permissions "$@"
      if [[ "${EUID}" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
        echo "Warning: sudo not available, PC speaker may not work"
      fi
    fi
  else
    echo "PC Speaker: Not available (will use audio fallback)"
  fi
fi

# Show detected audio device and availability
if [[ "$OUTPUT" == "audio" ]] || [[ "$OUTPUT" == "pcspkr" ]]; then
  if has_audio; then
    detected_device="$(detect_audio_device)"
    echo "Audio Hardware: Available"
    echo "Audio Device: $detected_device"
  else
    echo "Audio Hardware: Not available"
  fi
fi

echo "--------------------------------"
echo ""

# Test function with repeat
run_test() {
  local profile="$1"
  local count="$2"
  local i=1
  
  while [[ $i -le $count ]]; do
    if [[ $count -gt 1 ]]; then
      echo "[$i/$count] "
    fi
    
    case "$profile" in
      wopr)       test_wopr ;;
      mainframe)  test_mainframe ;;
      aliensterm) test_aliensterm ;;
      modem)      test_modem ;;
    esac
    
    if [[ $i -lt $count ]]; then
      echo ""
      sleep 0.5
    fi
    i=$((i + 1))
  done
}

# Run tests
if [[ "$PROFILE" == "all" ]]; then
  echo "Testing all profiles..."
  echo ""
  for profile in wopr mainframe aliensterm modem; do
    echo ">>> Testing $profile profile"
    run_test "$profile" 1
    echo ""
    sleep 1
  done
  echo "All profiles tested."
else
  run_test "$PROFILE" "$REPEAT"
fi

echo ""
echo "--------------------------------"
echo "Test complete."

