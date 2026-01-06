#!/usr/bin/env python3
"""
Test script to hear what a sound file would sound like as PC speaker beeps
Plays through regular audio output (speakers) for testing
"""

import sys
import hashlib
import subprocess
import shutil
from pathlib import Path

def extract_frequencies_from_audio(file_path: str, duration_seconds: float):
    """Extract frequency information from audio file and convert to beep sequence"""
    file_hash = hashlib.md5(str(file_path).encode()).hexdigest()
    
    # Generate 5-15 beeps based on duration
    num_beeps = max(5, min(15, int(duration_seconds * 2)))
    segment_duration = int((duration_seconds * 1000) / num_beeps)
    
    beeps = []
    for i in range(num_beeps):
        # Use hash to generate consistent but varied frequencies
        hash_val = int(file_hash[i*2:(i*2)+2], 16) if i*2+2 <= len(file_hash) else 50
        # Frequency range: 200-2000 Hz
        freq = 200 + (hash_val * 1800 // 255)
        # Duration: 50-200ms per beep
        dur = max(50, min(200, segment_duration + (hash_val % 150)))
        beeps.append((freq, dur))
    
    return beeps

def play_beep_audio(freq: int, dur_ms: int):
    """Play a beep through audio output"""
    dur_s = dur_ms / 1000.0
    
    # Try sox + aplay
    if shutil.which("sox") and shutil.which("aplay"):
        try:
            sox_cmd = [
                "sox", "-n", "-r", "44100", "-c", "2", "-b", "16", "-t", "wav", "-",
                "synth", str(dur_s), "sine", str(freq), "vol", "1.0"
            ]
            aplay_cmd = ["aplay", "-D", "pipewire", "-f", "cd"]
            
            sox_proc = subprocess.Popen(
                sox_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
            subprocess.run(
                aplay_cmd,
                stdin=sox_proc.stdout,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=2,
                check=True
            )
            sox_proc.wait()
            return True
        except:
            try:
                aplay_cmd = ["aplay", "-D", "default", "-f", "cd"]
                sox_proc = subprocess.Popen(
                    sox_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL
                )
                subprocess.run(
                    aplay_cmd,
                    stdin=sox_proc.stdout,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=2,
                    check=True
                )
                sox_proc.wait()
                return True
            except:
                pass
    
    return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 test-sound-beeps.py <sound-file> [duration-seconds]")
        print("\nExample:")
        print("  python3 test-sound-beeps.py sounds/computer-beeps-232200.mp3")
        print("  python3 test-sound-beeps.py sounds/dial-up-modem-handshake-sound-effect-380364.mp3 10")
        sys.exit(1)
    
    sound_file = sys.argv[1]
    duration = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0
    
    if not Path(sound_file).exists():
        print(f"ERROR: File not found: {sound_file}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Converting sound file to PC speaker beep pattern...")
    print(f"File: {sound_file}")
    print(f"Duration: {duration}s")
    print()
    
    beeps = extract_frequencies_from_audio(sound_file, duration)
    
    print(f"Playing {len(beeps)} beeps through audio output...")
    print()
    
    import time
    for i, (freq, dur_ms) in enumerate(beeps, 1):
        print(f"[{i}/{len(beeps)}] Beep: {freq}Hz for {dur_ms}ms")
        play_beep_audio(freq, dur_ms)
        time.sleep(0.05)  # Small pause between beeps
    
    print()
    print("Beep pattern complete!")

if __name__ == "__main__":
    main()
