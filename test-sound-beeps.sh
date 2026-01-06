#!/usr/bin/env bash
#
# test-sound-beeps.sh
#
# Test what a sound file would sound like as PC speaker beeps
# Plays the beep pattern through regular audio output (speakers)
#

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <sound-file> [duration-seconds]"
  echo ""
  echo "Example:"
  echo "  $0 sounds/computer-beeps-232200.mp3"
  echo "  $0 sounds/dial-up-modem-handshake-sound-effect-380364.mp3 10"
  exit 1
fi

SOUND_FILE="$1"
DURATION="${2:-30.0}"

if [[ ! -f "$SOUND_FILE" ]]; then
  echo "ERROR: File not found: $SOUND_FILE" >&2
  exit 1
fi

# Check if beep command exists
if ! command -v beep >/dev/null 2>&1; then
  echo "ERROR: 'beep' command not found. Install with: sudo dnf install beep" >&2
  exit 1
fi

echo "Converting sound file to PC speaker beep pattern..."
echo "File: $SOUND_FILE"
echo "Duration: ${DURATION}s"
echo ""

# Generate hash from filename (same logic as Python script)
FILE_HASH=$(echo -n "$SOUND_FILE" | md5sum | cut -d' ' -f1)

# Calculate number of beeps (5-15 based on duration)
NUM_BEEPS=$((5 + $(echo "$DURATION * 2" | bc | cut -d. -f1)))
NUM_BEEPS=$((NUM_BEEPS < 5 ? 5 : (NUM_BEEPS > 15 ? 15 : NUM_BEEPS)))
SEGMENT_DURATION=$(echo "$DURATION * 1000 / $NUM_BEEPS" | bc | cut -d. -f1)

echo "Playing $NUM_BEEPS beeps through audio output..."
echo ""

# Generate and play beeps
for i in $(seq 0 $((NUM_BEEPS - 1))); do
  # Extract 2 hex chars from hash for this beep
  OFFSET=$((i * 2))
  HASH_VAL=$(echo "$FILE_HASH" | cut -c$((OFFSET + 1))-$((OFFSET + 2)))
  HASH_DEC=$((0x${HASH_VAL:-50}))
  
  # Frequency: 200-2000 Hz
  FREQ=$((200 + (HASH_DEC * 1800 / 255)))
  
  # Duration: 50-200ms
  DUR=$((SEGMENT_DURATION + (HASH_DEC % 150)))
  DUR=$((DUR < 50 ? 50 : (DUR > 200 ? 200 : DUR)))
  
  echo "[$((i + 1))/$NUM_BEEPS] Beep: ${FREQ}Hz for ${DUR}ms"
  
  # Play beep through audio (using beep command, which will use audio if PC speaker not available)
  beep -f "$FREQ" -l "$DUR" 2>/dev/null || {
    # Fallback: use sox to generate tone
    if command -v sox >/dev/null 2>&1 && command -v aplay >/dev/null 2>&1; then
      DUR_S=$(echo "scale=3; $DUR / 1000" | bc)
      sox -n -r 44100 -c 2 -b 16 -t wav - \
        synth "$DUR_S" sine "$FREQ" vol 1.0 \
        2>/dev/null | aplay -D pipewire -f cd 2>/dev/null || \
      sox -n -r 44100 -c 2 -b 16 -t wav - \
        synth "$DUR_S" sine "$FREQ" vol 1.0 \
        2>/dev/null | aplay -D default -f cd 2>/dev/null || true
    else
      echo "  (Skipping - no audio tools available)"
    fi
  }
  
  # Small pause between beeps
  sleep 0.05
done

echo ""
echo "Beep pattern complete!"
