#!/usr/bin/env python3
import math
import wave
from pathlib import Path
import numpy as np

SR = 44100
BPM = 124.0
BEAT = 60.0 / BPM
TOTAL_BEATS = 96.0
DURATION = TOTAL_BEATS * BEAT + 1.5
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)

rng = np.random.default_rng(20260927)

def write_wav(path: Path, data: np.ndarray, sr: int = SR):
    data = np.clip(data, -0.98, 0.98)
    pcm = (data * 32767.0).astype(np.int16)
    if pcm.ndim == 1:
        pcm = np.column_stack([pcm, pcm])
    with wave.open(str(path), 'wb') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(pcm.astype('<i2').tobytes())


def add_tone(buf, start, dur, freq, amp=0.2, decay=5.0, harmonics=(1.0,), pan=0.0, vibrato=0.0):
    i0 = max(0, int(start * SR))
    n = max(1, int(dur * SR))
    i1 = min(len(buf), i0 + n)
    n = i1 - i0
    if n <= 0:
        return
    t = np.arange(n, dtype=np.float64) / SR
    env = np.exp(-decay * t)
    if dur > 0.03:
        attack = np.minimum(1.0, t / 0.008)
        release = np.minimum(1.0, (dur - t) / 0.04)
        env *= np.clip(attack * release, 0, 1)
    phase = 2.0 * np.pi * (freq * t + (vibrato / (2*np.pi)) * np.sin(2*np.pi*5.0*t))
    sig = np.zeros(n, dtype=np.float64)
    for k, h in enumerate(harmonics, start=1):
        sig += (h / k) * np.sin(k * phase)
    sig *= amp * env
    left = math.sqrt((1.0 - pan) * 0.5)
    right = math.sqrt((1.0 + pan) * 0.5)
    buf[i0:i1, 0] += sig * left
    buf[i0:i1, 1] += sig * right


def add_kick(buf, beat, amp=0.6):
    start = beat * BEAT
    dur = 0.18
    i0 = int(start * SR); n = int(dur * SR)
    t = np.arange(n) / SR
    freq = 82.0 * np.exp(-8.0*t) + 38.0
    phase = 2*np.pi*np.cumsum(freq)/SR
    env = np.exp(-18*t)
    sig = np.sin(phase) * env * amp
    i1=min(len(buf),i0+n); sig=sig[:i1-i0]
    buf[i0:i1,:] += sig[:,None]*0.72


def add_snare(buf, beat, amp=0.35):
    start=beat*BEAT; dur=0.14
    i0=int(start*SR); n=int(dur*SR); i1=min(len(buf),i0+n); n=i1-i0
    t=np.arange(n)/SR
    noise=rng.normal(0,1,n)
    # differentiate for a crude high-pass character
    noise=np.concatenate(([noise[0]], np.diff(noise)))
    env=np.exp(-22*t)
    sig=noise*env*amp*0.32 + np.sin(2*np.pi*180*t)*np.exp(-16*t)*amp*0.25
    buf[i0:i1,0]+=sig*0.9; buf[i0:i1,1]+=sig*0.9


def add_hat(buf, beat, amp=0.10):
    start=beat*BEAT; dur=0.055
    i0=int(start*SR); n=int(dur*SR); i1=min(len(buf),i0+n); n=i1-i0
    t=np.arange(n)/SR
    noise=rng.normal(0,1,n)
    noise=np.concatenate(([noise[0]], np.diff(noise)))
    sig=noise*np.exp(-55*t)*amp*0.22
    pan=-0.25 if int(beat*2)%2==0 else 0.25
    l=math.sqrt((1-pan)*0.5); r=math.sqrt((1+pan)*0.5)
    buf[i0:i1,0]+=sig*l; buf[i0:i1,1]+=sig*r


def add_bell(buf, beat, note, amp=0.20, dur=0.35, pan=0.0):
    freq=440.0*(2**((note-69)/12))
    add_tone(buf, beat*BEAT, dur, freq, amp=amp, decay=6.0, harmonics=(1.0,0.9,0.45), pan=pan)


def add_bass(buf, beat, note, dur_beats=0.9, amp=0.18):
    freq=440.0*(2**((note-69)/12))
    add_tone(buf, beat*BEAT, dur_beats*BEAT, freq, amp=amp, decay=1.8, harmonics=(1.0,0.25), pan=-0.1)


def add_chord(buf, beat, notes, dur_beats=3.6, amp=0.07):
    pans=(-0.35,0.0,0.35)
    for note,pan in zip(notes,pans):
        freq=440.0*(2**((note-69)/12))
        add_tone(buf, beat*BEAT, dur_beats*BEAT, freq, amp=amp, decay=0.75, harmonics=(1.0,0.35), pan=pan, vibrato=0.25)


def add_chirp(buf, beat, amp=0.22):
    start=beat*BEAT; dur=0.34
    i0=int(start*SR); n=int(dur*SR); i1=min(len(buf),i0+n); n=i1-i0
    t=np.arange(n)/SR
    f0,f1=1200.0,2100.0
    k=(f1-f0)/dur
    phase=2*np.pi*(f0*t+0.5*k*t*t)
    env=np.sin(np.pi*np.clip(t/dur,0,1))**2
    sig=(np.sin(phase)+0.35*np.sin(2.01*phase))*env*amp
    buf[i0:i1,0]+=sig*0.85; buf[i0:i1,1]+=sig*0.65


def make_theme():
    n=int(DURATION*SR)
    buf=np.zeros((n,2),dtype=np.float64)
    # Drum groove.
    for b in np.arange(0,TOTAL_BEATS,0.5):
        add_hat(buf,float(b),0.085 if int(b*2)%2 else 0.11)
    for b in range(int(TOTAL_BEATS)):
        if b % 4 in (0,2): add_kick(buf,b,0.48 if b%4==0 else 0.38)
        if b % 4 in (1,3): add_snare(buf,b,0.32)
    # Chord progression: C - Am - F - G, with a brighter final section.
    prog=[(48,[60,64,67]),(45,[57,60,64]),(41,[53,57,60]),(43,[55,59,62])]
    for bar in range(24):
        root,ch=prog[bar%4]
        if bar>=20:
            ch=[n+12 if i==2 else n for i,n in enumerate(ch)]
        add_chord(buf,bar*4,ch,3.75,0.055 if bar<16 else 0.07)
        for step in (0,2):
            add_bass(buf,bar*4+step,root,0.85,0.17)
    # A light melodic hook every 8 beats.
    motif=[72,74,76,79,76,74]
    for block in range(0,96,8):
        if block<4: continue
        for j,note in enumerate(motif):
            beat=block+0.5*j
            if beat<block+4:
                add_bell(buf,beat,note,0.075,0.16,pan=0.2)
    # Hit cues: two-note standard cue, four-note special cue.
    events=[(8,'n'),(12,'n'),(16,'n'),(22,'s'),(28,'n'),(32,'n'),(38,'n'),(44,'s'),(50,'n'),(54,'n'),(60,'n'),(66,'s'),(72,'n'),(76,'n'),(82,'n'),(88,'s'),(92,'n')]
    for target,kind in events:
        if kind=='n':
            add_bell(buf,target-2,84,0.24,0.28,-0.2)
            add_bell(buf,target-1,88,0.27,0.28,0.2)
        else:
            for k,note in enumerate((76,79,83,88)):
                add_bell(buf,target-4+k,note,0.22+0.02*k,0.3,-0.3+0.2*k)
    # Fake bird cues. These intentionally do not have a target hit.
    add_chirp(buf,35.0,0.23)
    add_chirp(buf,57.0,0.23)
    # Transition fills.
    for start in (15,31,47,63,79):
        for j in range(4):
            add_snare(buf,start+0.25*j,0.22+0.04*j)
    # Finale sparkle.
    for j,note in enumerate((72,76,79,84,88,91)):
        add_bell(buf,93.0+0.4*j,note,0.16,0.55,-0.4+0.15*j)
    # Gentle mastering.
    peak=np.max(np.abs(buf))
    if peak>0: buf*=0.88/peak
    write_wav(OUT/'sky_golf_theme.wav',buf)


def make_sfx():
    # Normal cue: two notes one beat apart, target occurs after the second beat.
    dur=2.0*BEAT+0.15
    buf=np.zeros((int(dur*SR),2),float)
    add_bell(buf,0,84,0.34,0.28,-0.2); add_bell(buf,1,88,0.38,0.28,0.2)
    write_wav(OUT/'cue_normal.wav',buf)
    # Special cue: four ascending notes.
    dur=4.0*BEAT+0.15
    buf=np.zeros((int(dur*SR),2),float)
    for k,note in enumerate((76,79,83,88)):
        add_bell(buf,k,note,0.30+0.02*k,0.3,-0.3+0.2*k)
    write_wav(OUT/'cue_special.wav',buf)
    # Success impact.
    dur=0.7; buf=np.zeros((int(dur*SR),2),float)
    add_tone(buf,0.0,0.35,660,0.24,5,(1,0.5,0.25),-0.2)
    add_tone(buf,0.08,0.45,990,0.20,5,(1,0.35),0.25)
    add_tone(buf,0.16,0.5,1320,0.17,5,(1,0.25),0.0)
    write_wav(OUT/'success.wav',buf)
    # Whiff.
    dur=0.5; buf=np.zeros((int(dur*SR),2),float)
    t=np.arange(len(buf))/SR
    noise=rng.normal(0,1,len(buf)); env=np.exp(-10*t)
    sweep=np.sin(2*np.pi*(800*t-350*t*t))*env*0.12
    buf[:,0]+=sweep; buf[:,1]+=sweep
    write_wav(OUT/'whiff.wav',buf)
    # Splash.
    dur=0.8; buf=np.zeros((int(dur*SR),2),float)
    t=np.arange(len(buf))/SR
    noise=rng.normal(0,1,len(buf))*np.exp(-7*t)*0.10
    low=np.sin(2*np.pi*95*t)*np.exp(-5*t)*0.13
    buf[:,0]+=noise+low; buf[:,1]+=noise+low
    write_wav(OUT/'splash.wav',buf)
    # Bird chirp.
    dur=0.45; buf=np.zeros((int(dur*SR),2),float); add_chirp(buf,0,0.34); write_wav(OUT/'bird.wav',buf)
    # Finish jingle.
    dur=2.0; buf=np.zeros((int(dur*SR),2),float)
    for i,n in enumerate((72,76,79,84,88)):
        add_tone(buf,i*0.18,0.7,440*(2**((n-69)/12)),0.18,4,(1,0.5,0.2),-0.4+i*0.2)
    write_wav(OUT/'finish.wav',buf)

if __name__=='__main__':
    make_theme(); make_sfx()
    for p in sorted(OUT.glob('*.wav')):
        print(p.name, p.stat().st_size)
