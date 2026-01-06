#!/usr/bin/env python3
"""
Retro SFX Daemon - Python version
Generates retro computer sounds using PC speaker or audio output
"""

import os
import sys
import time
import random
import subprocess
import signal
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional, Tuple

# Paths
RUNDIR = Path("/run/retro-sfx")
PROFILE_FILE = RUNDIR / "profile"
ENABLED_FILE = RUNDIR / "enabled"
CONF_FILE = Path("/etc/retro-sfx.conf")

# Ensure runtime directory exists
RUNDIR.mkdir(parents=True, exist_ok=True)
RUNDIR.chmod(0o755)

# Default configuration
DEFAULT_CONFIG = {
    "QUIET_ENABLED": "1",
    "QUIET_START": "22:00",
    "QUIET_END": "07:00",
    "OUTPUT_MODE": "random",
    "RANDOM_AUDIO_PERCENT": "70",
    "AUDIO_DEVICE": "default",
    "AUDIO_GAIN": "1.0",
    "LIMITER_ENABLED": "0",
    "LIM_ATTACK": "0.005",
    "LIM_DECAY": "0.10",
    "LIM_SOFTKNEE": "6",
    "LIM_TARGET_DB": "-3",
    # Sound pattern selection (comma-separated list of variation indices 0-9, or "all")
    "WOPR_ENABLED_VARIATIONS": "all",
    "MAINFRAME_ENABLED_VARIATIONS": "all",
    "ALIENSTERM_ENABLED_VARIATIONS": "all",
}


def load_config() -> dict:
    """Load configuration from file or use defaults"""
    config = DEFAULT_CONFIG.copy()
    if CONF_FILE.exists():
        with open(CONF_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    config[key.strip()] = value.strip().strip('"')
    return config


def read_profile() -> str:
    """Read current profile"""
    if PROFILE_FILE.exists():
        profile = PROFILE_FILE.read_text().strip()
        if profile in ["wopr", "mainframe", "aliensterm"]:
            return profile
    return "mainframe"


def is_enabled() -> bool:
    """Check if daemon is enabled"""
    if ENABLED_FILE.exists():
        return ENABLED_FILE.read_text().strip() == "1"
    return True


def to_minutes(time_str: str) -> int:
    """Convert HH:MM to minutes since midnight"""
    h, m = map(int, time_str.split(':'))
    return h * 60 + m


def in_quiet_hours(config: dict) -> bool:
    """Check if current time is within quiet hours"""
    if config.get("QUIET_ENABLED") != "1":
        return False
    
    now = datetime.now()
    now_min = now.hour * 60 + now.minute
    start_min = to_minutes(config.get("QUIET_START", "22:00"))
    end_min = to_minutes(config.get("QUIET_END", "07:00"))
    
    if start_min == end_min:
        return True
    
    if start_min < end_min:
        return start_min <= now_min < end_min
    else:
        return now_min >= start_min or now_min < end_min


def has_pcspkr() -> bool:
    """Detect if PC speaker/piezo is available"""
    # Check if pcspkr module is loaded
    try:
        result = subprocess.run(
            ["lsmod"], capture_output=True, text=True, check=True
        )
        if "pcspkr" not in result.stdout:
            return False
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False
    
    # Check if beep command exists
    if not shutil.which("beep"):
        return False
    
    # Check for hardware device
    pcspkr_paths = [
        Path("/dev/input/by-path/platform-pcspkr-event-spkr"),
        Path("/dev/input/by-path/platform-pcspkr"),
    ]
    for path in pcspkr_paths:
        if path.exists() or path.parent.exists():
            return True
    
    # If module is loaded, assume it might work
    return True


def has_audio() -> bool:
    """Detect if audio hardware is available"""
    # Check for ALSA sound cards
    cards_file = Path("/proc/asound/cards")
    if cards_file.exists():
        content = cards_file.read_text()
        # Count actual sound cards (lines starting with space and number)
        card_count = sum(1 for line in content.split('\n') 
                        if line.strip() and line[0] == ' ' and line[1].isdigit())
        if card_count > 0:
            return True
    
    # Check if aplay can list devices
    try:
        result = subprocess.run(
            ["aplay", "-l"], capture_output=True, text=True, check=True
        )
        if "card" in result.stdout:
            return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    # Check for USB audio devices
    sound_dir = Path("/sys/class/sound")
    if sound_dir.exists():
        if any(sound_dir.glob("card*")):
            return True
    
    return False


def detect_audio_device() -> Optional[str]:
    """Auto-detect best audio device"""
    if not has_audio():
        return None
    
    # Priority: pipewire > pulse > alsa cards > default
    devices_to_try = ["pipewire", "pulse"]
    
    # Check for ALSA cards
    try:
        result = subprocess.run(
            ["aplay", "-l"], capture_output=True, text=True, check=True
        )
        for line in result.stdout.split('\n'):
            if line.startswith('card ') and 'HDA Analog' in line:
                # Extract card number
                card_num = line.split()[1].rstrip(':')
                devices_to_try.append(f"hw:{card_num},0")
                break
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    devices_to_try.append("default")
    
    # Test each device
    for device in devices_to_try:
        try:
            result = subprocess.run(
                ["aplay", "-D", device, "-l"],
                capture_output=True,
                timeout=1,
                check=True
            )
            return device
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
            continue
    
    return "default"


def pick_output_mode(config: dict) -> str:
    """Pick output mode based on availability"""
    pcspkr_available = has_pcspkr()
    audio_available = has_audio()
    output_mode = config.get("OUTPUT_MODE", "random")
    
    if output_mode == "pcspkr":
        if pcspkr_available:
            return "pcspkr"
        elif audio_available:
            return "audio"
        else:
            return "none"
    elif output_mode == "audio":
        if audio_available:
            return "audio"
        elif pcspkr_available:
            return "pcspkr"
        else:
            return "none"
    elif output_mode == "random":
        if pcspkr_available and audio_available:
            percent = int(config.get("RANDOM_AUDIO_PERCENT", "70"))
            if random.randint(0, 99) < percent:
                return "audio"
            else:
                return "pcspkr"
        elif audio_available:
            return "audio"
        elif pcspkr_available:
            return "pcspkr"
        else:
            return "none"
    
    return "none"


def play_pcspkr(freq: int, dur_ms: int) -> bool:
    """Play sound via PC speaker/piezo"""
    try:
        subprocess.run(
            ["beep", "-f", str(freq), "-l", str(dur_ms)],
            capture_output=True,
            timeout=1,
            check=True
        )
        return True
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        # Fallback to audio
        return play_audio(freq, dur_ms)


def play_audio(freq: int, dur_ms: int, config: dict) -> bool:
    """Play sound via audio output"""
    # Ensure minimum duration for audibility
    if dur_ms < 30:
        dur_ms = 30
    
    if not has_audio():
        return False
    
    dur_s = dur_ms / 1000.0
    audio_gain = float(config.get("AUDIO_GAIN", "1.0"))
    device = config.get("AUDIO_DEVICE", "default")
    
    # Auto-detect device if needed
    if device == "default" or device == "none":
        device = detect_audio_device() or "default"
    
    # Try pipewire first, then fallback
    devices_to_try = ["pipewire", device, "default"]
    
    limiter_enabled = config.get("LIMITER_ENABLED") == "1"
    
    for dev in devices_to_try:
        try:
            sox_cmd = [
                "sox", "-n", "-r", "44100", "-c", "2", "-b", "16", "-t", "wav", "-",
                "synth", str(dur_s), "sine", str(freq), "vol", str(audio_gain)
            ]
            
            if limiter_enabled:
                sox_cmd.extend([
                    "compand",
                    f"{config.get('LIM_ATTACK', '0.005')},{config.get('LIM_DECAY', '0.10')}",
                    f"{config.get('LIM_SOFTKNEE', '6')}:-inf,0,-inf",
                    config.get("LIM_TARGET_DB", "-3"),
                    "gain", "-n"
                ])
            
            aplay_cmd = ["aplay", "-D", dev, "-f", "cd"]
            
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
            
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
            continue
    
    return False


def play_sound(freq: int, dur_ms: int, config: dict) -> None:
    """Play a sound using the appropriate output"""
    mode = pick_output_mode(config)
    
    if mode == "pcspkr":
        play_pcspkr(freq, dur_ms)
    elif mode == "audio":
        play_audio(freq, dur_ms, config)
    # mode == "none" means no output available, silently skip


# Sound patterns
def get_enabled_variations(config: dict, profile: str) -> list:
    """Get list of enabled variation indices for a profile"""
    key = f"{profile.upper()}_ENABLED_VARIATIONS"
    value = config.get(key, "all").strip()
    
    if value.lower() == "all":
        return list(range(10))  # All variations 0-9
    
    # Parse comma-separated list
    try:
        variations = [int(x.strip()) for x in value.split(",") if x.strip()]
        # Filter to valid range (0-9)
        variations = [v for v in variations if 0 <= v <= 9]
        return variations if variations else list(range(10))  # Default to all if empty
    except (ValueError, AttributeError):
        return list(range(10))  # Default to all on parse error


def pattern_wopr(config: dict) -> None:
    """WOPR profile - fast, chatty sounds with high randomness"""
    # Base patterns - we'll randomly select and vary them
    base_patterns = [
        [(1200, 40), (900, 35), (1600, 50)],
        [(700, 70), (1100, 40), (700, 40)],
        [(300, 200)],
        [(1500, 30), (1700, 30), (1900, 40)],
        [(800, 60), (600, 80)],
        [(1000, 35), (1000, 35), (600, 120)],
        [(400, 140), (900, 50)],
        [(500, 25), (1200, 45), (800, 60)],
        [(600, 100)],
        [(1300, 20), (900, 50), (700, 80), (1100, 40)],
    ]
    
    # Get enabled variations and filter patterns
    enabled = get_enabled_variations(config, "wopr")
    available_patterns = [base_patterns[i] for i in enabled if i < len(base_patterns)]
    
    if not available_patterns:
        available_patterns = base_patterns  # Fallback to all if none enabled
    
    # Randomly select a base pattern from enabled ones
    pattern = random.choice(available_patterns)
    
    # Randomly decide how many beeps to play (1-6 beeps)
    num_beeps = random.randint(1, 6)
    
    # Create beeps to play - repeat pattern if needed, then randomly sample
    beeps_to_play = []
    if len(pattern) == 1:
        # Single beep pattern - repeat it
        beeps_to_play = pattern * num_beeps
    else:
        # Multiple beep pattern - repeat and randomly sample
        extended = pattern * 3  # Repeat pattern 3 times
        beeps_to_play = random.sample(extended, min(num_beeps, len(extended)))
    
    # Play each beep with random variations
    for freq, dur_ms in beeps_to_play[:num_beeps]:
        # Add large random variation to frequency (-200 to +200 Hz)
        freq_var = freq + random.randint(-200, 200)
        freq_var = max(100, min(3000, freq_var))  # Clamp to reasonable range
        
        # Much wider duration variation - from 20% to 500% of base
        dur_mult = random.uniform(0.2, 5.0)
        dur_var = int(dur_ms * dur_mult)
        dur_var = max(10, min(800, dur_var))  # Clamp to reasonable range
        
        play_sound(freq_var, dur_var, config)
        
        # Variable pause between beeps (0.05 to 0.4 seconds)
        time.sleep(random.uniform(0.05, 0.4))
    
    # Variable pause after pattern (0.2 to 1.5 seconds)
    time.sleep(random.uniform(0.2, 1.5))


def pattern_mainframe(config: dict) -> None:
    """Mainframe profile - slow, ambient sounds"""
    # Get enabled variations
    enabled = get_enabled_variations(config, "mainframe")
    if not enabled:
        enabled = list(range(10))
    
    # Select from enabled variations only
    r = random.choice(enabled)
    
    patterns = [
        lambda: [play_sound(300, 80, config)],
        lambda: [play_sound(300, 80, config)],
        lambda: [play_sound(300, 80, config)],
        lambda: [play_sound(260, 120, config)],
        lambda: [play_sound(260, 120, config)],
        lambda: [play_sound(420, 60, config), play_sound(320, 60, config)],
        lambda: [play_sound(220, 180, config)],
        lambda: [play_sound(500, 30, config), play_sound(500, 30, config)],
        lambda: [play_sound(500, 30, config), play_sound(500, 30, config)],
        lambda: [play_sound(180, 260, config)],
    ]
    if 0 <= r < len(patterns):
        patterns[r]()
    time.sleep(random.randint(4, 11))


def pattern_aliensterm(config: dict) -> None:
    """Alien terminal profile - sci-fi sounds"""
    # Get enabled variations
    enabled = get_enabled_variations(config, "aliensterm")
    if not enabled:
        enabled = list(range(10))
    
    # Select from enabled variations only
    r = random.choice(enabled)
    
    patterns = [
        lambda: [play_sound(1400, 35, config), play_sound(1200, 35, config), play_sound(1000, 45, config)],
        lambda: [play_sound(1400, 35, config), play_sound(1200, 35, config), play_sound(1000, 45, config)],
        lambda: [play_sound(1800, 25, config), play_sound(700, 90, config)],
        lambda: [play_sound(1600, 40, config), play_sound(2000, 20, config), play_sound(1600, 40, config)],
        lambda: [play_sound(1600, 40, config), play_sound(2000, 20, config), play_sound(1600, 40, config)],
        lambda: [play_sound(900, 60, config), play_sound(1300, 60, config), play_sound(900, 60, config)],
        lambda: [play_sound(2100, 18, config), play_sound(1900, 18, config), play_sound(1700, 18, config), play_sound(1500, 18, config)],
        lambda: [play_sound(600, 160, config), play_sound(1400, 40, config)],
        lambda: [play_sound(1000, 30, config), play_sound(1500, 30, config), play_sound(2000, 30, config), play_sound(1200, 60, config)],
        lambda: [play_sound(2400, 15, config), play_sound(800, 120, config)],
    ]
    if 0 <= r < len(patterns):
        patterns[r]()
    time.sleep(random.uniform(0.2, 0.9))


def main():
    """Main daemon loop"""
    # Handle signals gracefully
    def signal_handler(sig, frame):
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Initialize defaults
    if not PROFILE_FILE.exists():
        PROFILE_FILE.write_text("mainframe")
    if not ENABLED_FILE.exists():
        ENABLED_FILE.write_text("1")
    
    # Auto-detect and log available hardware
    pcspkr_avail = has_pcspkr()
    audio_avail = has_audio()
    
    print(f"PC Speaker/Piezo: {'Available' if pcspkr_avail else 'Not available'}", file=sys.stderr)
    print(f"Audio Hardware: {'Available' if audio_avail else 'Not available'}", file=sys.stderr)
    if audio_avail:
        device = detect_audio_device()
        print(f"Audio Device: {device}", file=sys.stderr)
    
    # Main loop
    while True:
        config = load_config()
        
        if not is_enabled() or in_quiet_hours(config):
            time.sleep(2)
            continue
        
        profile = read_profile()
        
        if profile == "wopr":
            pattern_wopr(config)
        elif profile == "mainframe":
            pattern_mainframe(config)
        elif profile == "aliensterm":
            pattern_aliensterm(config)


if __name__ == "__main__":
    main()
