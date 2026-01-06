#!/usr/bin/env python3
"""
Retro SFX Control CLI - Python version
Runtime control for retro-sfx daemon
"""

import sys
import argparse
import re
from pathlib import Path

RUNDIR = Path("/run/retro-sfx")
PROFILE_FILE = RUNDIR / "profile"
ENABLED_FILE = RUNDIR / "enabled"
CONF_FILE = Path("/etc/retro-sfx.conf")


def status():
    """Show current daemon status"""
    profile = "mainframe"
    if PROFILE_FILE.exists():
        profile = PROFILE_FILE.read_text().strip()
    
    enabled = "1"
    if ENABLED_FILE.exists():
        enabled = ENABLED_FILE.read_text().strip()
    
    output = "pcspkr"
    random_percent = "50"
    limiter = "0"
    quiet_enabled = "1"
    quiet_start = "22:00"
    quiet_end = "07:00"
    wopr_vars = "all"
    mainframe_vars = "all"
    aliensterm_vars = "all"
    
    if CONF_FILE.exists():
        with open(CONF_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith("OUTPUT_MODE="):
                    output = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("RANDOM_AUDIO_PERCENT="):
                    random_percent = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("LIMITER_ENABLED="):
                    limiter = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("QUIET_ENABLED="):
                    quiet_enabled = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("QUIET_START="):
                    quiet_start = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("QUIET_END="):
                    quiet_end = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("WOPR_ENABLED_VARIATIONS="):
                    wopr_vars = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("MAINFRAME_ENABLED_VARIATIONS="):
                    mainframe_vars = line.split("=", 1)[1].strip().strip('"')
                elif line.startswith("ALIENSTERM_ENABLED_VARIATIONS="):
                    aliensterm_vars = line.split("=", 1)[1].strip().strip('"')
    
    print(f"enabled={enabled} profile={profile} output={output} "
          f"random_audio_percent={random_percent} limiter={limiter}")
    print(f"quiet_enabled={quiet_enabled} quiet_start={quiet_start} quiet_end={quiet_end}")
    print(f"wopr_variations={wopr_vars} mainframe_variations={mainframe_vars} "
          f"aliensterm_variations={aliensterm_vars}")


def set_enabled(value: str):
    """Enable or disable daemon"""
    RUNDIR.mkdir(parents=True, exist_ok=True)
    ENABLED_FILE.write_text(value)


def set_profile(profile: str):
    """Set sound profile"""
    if profile not in ["wopr", "mainframe", "aliensterm"]:
        print(f"ERROR: Invalid profile '{profile}'", file=sys.stderr)
        print("Valid profiles: wopr, mainframe, aliensterm", file=sys.stderr)
        sys.exit(2)
    
    RUNDIR.mkdir(parents=True, exist_ok=True)
    PROFILE_FILE.write_text(profile)


def set_output(mode: str):
    """Set output mode"""
    if mode not in ["pcspkr", "audio", "random"]:
        print(f"ERROR: Invalid output mode '{mode}'", file=sys.stderr)
        print("Valid modes: pcspkr, audio, random", file=sys.stderr)
        sys.exit(2)
    
    # Update config file
    if not CONF_FILE.exists():
        CONF_FILE.write_text(f"OUTPUT_MODE={mode}\n")
    else:
        lines = []
        updated = False
        with open(CONF_FILE, 'r') as f:
            for line in f:
                if line.startswith("OUTPUT_MODE="):
                    lines.append(f"OUTPUT_MODE={mode}\n")
                    updated = True
                else:
                    lines.append(line)
        
        if not updated:
            lines.append(f"OUTPUT_MODE={mode}\n")
        
        CONF_FILE.write_text("".join(lines))


def set_random_audio(percent: int):
    """Set random audio percentage"""
    if not 0 <= percent <= 100:
        print(f"ERROR: Percentage must be 0-100, got {percent}", file=sys.stderr)
        sys.exit(2)
    
    # Update config file
    if not CONF_FILE.exists():
        CONF_FILE.write_text(f"RANDOM_AUDIO_PERCENT={percent}\n")
    else:
        lines = []
        updated = False
        with open(CONF_FILE, 'r') as f:
            for line in f:
                if line.startswith("RANDOM_AUDIO_PERCENT="):
                    lines.append(f"RANDOM_AUDIO_PERCENT={percent}\n")
                    updated = True
                else:
                    lines.append(line)
        
        if not updated:
            lines.append(f"RANDOM_AUDIO_PERCENT={percent}\n")
        
        CONF_FILE.write_text("".join(lines))


def set_limiter(enabled: bool):
    """Enable or disable audio limiter"""
    value = "1" if enabled else "0"
    
    # Update config file
    if not CONF_FILE.exists():
        CONF_FILE.write_text(f"LIMITER_ENABLED={value}\n")
    else:
        lines = []
        updated = False
        with open(CONF_FILE, 'r') as f:
            for line in f:
                if line.startswith("LIMITER_ENABLED="):
                    lines.append(f"LIMITER_ENABLED={value}\n")
                    updated = True
                else:
                    lines.append(line)
        
        if not updated:
            lines.append(f"LIMITER_ENABLED={value}\n")
        
        CONF_FILE.write_text("".join(lines))


def update_config(key: str, value: str):
    """Update a config key-value pair"""
    if not CONF_FILE.exists():
        CONF_FILE.write_text(f"{key}={value}\n")
    else:
        lines = []
        updated = False
        with open(CONF_FILE, 'r') as f:
            for line in f:
                if line.startswith(f"{key}="):
                    lines.append(f"{key}={value}\n")
                    updated = True
                else:
                    lines.append(line)
        
        if not updated:
            lines.append(f"{key}={value}\n")
        
        CONF_FILE.write_text("".join(lines))


def set_quiet_time(start: str, end: str):
    """Set quiet hours"""
    # Validate time format (HH:MM)
    if not re.match(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$', start):
        print(f"ERROR: Invalid time format '{start}'. Use HH:MM (24-hour)", file=sys.stderr)
        sys.exit(2)
    if not re.match(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$', end):
        print(f"ERROR: Invalid time format '{end}'. Use HH:MM (24-hour)", file=sys.stderr)
        sys.exit(2)
    
    update_config("QUIET_START", f'"{start}"')
    update_config("QUIET_END", f'"{end}"')


def set_quiet_enabled(enabled: bool):
    """Enable or disable quiet hours"""
    value = "1" if enabled else "0"
    update_config("QUIET_ENABLED", value)


def set_variations(profile: str, variations: str):
    """Set enabled variations for a profile"""
    if profile not in ["wopr", "mainframe", "aliensterm"]:
        print(f"ERROR: Invalid profile '{profile}'", file=sys.stderr)
        print("Valid profiles: wopr, mainframe, aliensterm", file=sys.stderr)
        sys.exit(2)
    
    # Validate variations format
    if variations.lower() != "all":
        # Must be comma-separated numbers 0-9
        try:
            nums = [int(x.strip()) for x in variations.split(",")]
            if not all(0 <= n <= 9 for n in nums):
                print(f"ERROR: Variation numbers must be 0-9", file=sys.stderr)
                sys.exit(2)
        except ValueError:
            print(f"ERROR: Invalid variations format '{variations}'", file=sys.stderr)
            print("Use 'all' or comma-separated numbers like '0,1,2,3'", file=sys.stderr)
            sys.exit(2)
    
    key = f"{profile.upper()}_ENABLED_VARIATIONS"
    update_config(key, variations)


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(description="Retro SFX Control")
    subparsers = parser.add_subparsers(dest='command', help='Command')
    
    # Status command
    subparsers.add_parser('status', help='Show daemon status')
    
    # On/Off commands
    subparsers.add_parser('on', help='Enable sounds')
    subparsers.add_parser('off', help='Disable sounds')
    
    # Profile command
    profile_parser = subparsers.add_parser('profile', help='Set sound profile')
    profile_parser.add_argument('name', choices=['wopr', 'mainframe', 'aliensterm'],
                               help='Profile name')
    
    # Output command
    output_parser = subparsers.add_parser('output', help='Set output mode')
    output_parser.add_argument('mode', choices=['pcspkr', 'audio', 'random'],
                             help='Output mode')
    
    # Random audio command
    random_parser = subparsers.add_parser('random-audio', help='Set random audio percentage')
    random_parser.add_argument('percent', type=int, help='Percentage (0-100)')
    
    # Limiter command
    limiter_parser = subparsers.add_parser('limiter', help='Enable/disable audio limiter')
    limiter_parser.add_argument('state', choices=['on', 'off'], help='Limiter state')
    
    # Quiet time commands
    quiet_parser = subparsers.add_parser('quiet-time', help='Set quiet hours (HH:MM format)')
    quiet_parser.add_argument('start', help='Start time (e.g., 22:00)')
    quiet_parser.add_argument('end', help='End time (e.g., 07:00)')
    
    quiet_enable_parser = subparsers.add_parser('quiet', help='Enable/disable quiet hours')
    quiet_enable_parser.add_argument('state', choices=['on', 'off'], help='Quiet hours state')
    
    # Variations command
    variations_parser = subparsers.add_parser('variations', help='Set enabled sound variations for a profile')
    variations_parser.add_argument('profile', choices=['wopr', 'mainframe', 'aliensterm'], help='Profile name')
    variations_parser.add_argument('variations', help='Variations: "all" or comma-separated like "0,1,2,3"')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(2)
    
    try:
        if args.command == 'status':
            status()
        elif args.command == 'on':
            set_enabled("1")
        elif args.command == 'off':
            set_enabled("0")
        elif args.command == 'profile':
            set_profile(args.name)
        elif args.command == 'output':
            set_output(args.mode)
        elif args.command == 'random-audio':
            set_random_audio(args.percent)
        elif args.command == 'limiter':
            set_limiter(args.state == 'on')
        elif args.command == 'quiet-time':
            set_quiet_time(args.start, args.end)
        elif args.command == 'quiet':
            set_quiet_enabled(args.state == 'on')
        elif args.command == 'variations':
            set_variations(args.profile, args.variations)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
