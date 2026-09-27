#!/usr/bin/env python3
from pathlib import Path
import re
import wave

ROOT = Path(__file__).resolve().parents[1]
required = [
    'project.godot', 'export_presets.cfg', 'scenes/main.tscn', 'scripts/main.gd',
    'assets/characters/sora_pip.png', 'assets/characters/pip.png',
    'assets/backgrounds/sky_golf.png', 'assets/audio/sky_golf_theme.wav',
    'assets/audio/cue_normal.wav', 'assets/audio/cue_special.wav',
    'assets/audio/success.wav', 'assets/audio/whiff.wav', 'assets/audio/splash.wav',
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    raise SystemExit('Missing files: ' + ', '.join(missing))

src = (ROOT / 'scripts/main.gd').read_text(encoding='utf-8')
# Extract target beats from the event table.
triples = re.findall(r'\[(\d+\.\d+),\s*"(normal|special)",\s*(\d+\.\d+)\]', src)
if len(triples) != 17:
    raise SystemExit(f'Expected 17 rhythm events, found {len(triples)}')
beats = [float(t[0]) for t in triples]
if beats != sorted(beats) or beats[-1] >= 96.0:
    raise SystemExit('Rhythm event ordering/range is invalid')

with wave.open(str(ROOT / 'assets/audio/sky_golf_theme.wav'), 'rb') as wf:
    duration = wf.getnframes() / wf.getframerate()
expected = 96.0 * (60.0 / 124.0)
if duration < expected:
    raise SystemExit(f'Music is too short: {duration:.3f}s < {expected:.3f}s')

# Ensure legacy generated voice cues are absent.
for bad in ('hey.wav', 'go.wav', 'yeah.wav'):
    if (ROOT / 'assets/audio' / bad).exists():
        raise SystemExit(f'Legacy voice cue present: {bad}')

print(f'OK: {len(triples)} events, music {duration:.2f}s, all required assets present')
