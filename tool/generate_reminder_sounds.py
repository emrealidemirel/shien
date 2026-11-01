"""Generate distinct original PCM tones. No external audio or samples are used."""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
TONES = {
    'reminder_soft': [(0, 392, .55), (.48, 493.88, .65)],
    'reminder_chime': [(0, 783.99, 1.8)],
    'reminder_bright': [(0, 880, .22), (.25, 1174.66, .22), (.50, 880, .22), (.75, 1318.51, .4)],
}


def tone(name, local, frequency, duration):
    # Soft uses a rounded attack and low pure notes; chime is one struck bell
    # with inharmonic overtones; bright has short, separated high pulses.
    if name == 'reminder_chime':
        attack = min(local / .004, 1)
        value = sum(weight * math.sin(2 * math.pi * frequency * ratio * local)
                    * math.exp(-decay * local / duration)
                    for ratio, weight, decay in [(1, 1, 4), (2.76, .35, 7), (5.4, .12, 12)])
        return attack * value * .30
    attack = .06 if name == 'reminder_soft' else .008
    envelope = min(local / attack, 1) * math.exp(-4 * local / duration)
    harmonic = .03 if name == 'reminder_soft' else .25
    amplitude = .24 if name == 'reminder_soft' else .32
    return envelope * amplitude * (math.sin(2 * math.pi * frequency * local)
        + harmonic * math.sin(4 * math.pi * frequency * local))


for name, notes in TONES.items():
    length = max(start + duration for start, _, duration in notes) + .15
    samples = []
    for frame in range(int(length * RATE)):
        time = frame / RATE
        value = 0.0
        for start, frequency, duration in notes:
            local = time - start
            if 0 <= local < duration:
                value += tone(name, local, frequency, duration) * min((duration - local) / .06, 1)
        samples.append(struct.pack('<h', round(max(-1, min(1, value)) * 32767)))
    for directory in ['assets/sounds', 'android/app/src/main/res/raw', 'ios']:
        target = ROOT / directory / f'{name}.wav'
        target.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(target), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(b''.join(samples))
    print(f'{name}: {length:.2f}s')
