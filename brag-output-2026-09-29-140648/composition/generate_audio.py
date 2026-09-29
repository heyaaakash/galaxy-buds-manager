"""Generate an original, restrained 23-second synth bed for the launch film."""
import wave
import numpy as np

SR = 48000
DURATION = 23
t = np.arange(SR * DURATION, dtype=np.float64) / SR
sound = np.zeros_like(t)

def add_tone(start, length, freq, amp, attack=0.04, release=0.45, shimmer=0):
    global sound
    a = int(start * SR)
    b = min(len(sound), a + int(length * SR))
    x = np.arange(b-a) / SR
    env = np.minimum(1, x / attack) * np.minimum(1, (length-x) / release)
    env = np.maximum(0, env)
    tone = np.sin(2*np.pi*freq*x) + 0.28*np.sin(2*np.pi*freq*2*x)
    if shimmer:
        tone += shimmer*np.sin(2*np.pi*freq*4*x)*np.exp(-4*x)
    sound[a:b] += amp * env * tone

# A slow, minor-key harmonic floor and small melodic glints.
for start, notes in [(0,[55,82.41,130.81]), (5.5,[55,87.31,130.81]),
                     (11.5,[65.41,98,146.83]), (16.5,[55,82.41,164.81]),
                     (20,[55,82.41,130.81])]:
    for i, note in enumerate(notes):
        add_tone(start, 5.8 if start < 20 else 3, note, 0.045/(i+1), .8, 1.8)

for beat in np.arange(0, DURATION, .5):
    # Rounded 120 BPM pulse, gently weighted on every fourth beat.
    a = int(beat * SR)
    x = np.arange(min(int(.22*SR), len(sound)-a))/SR
    strength = .095 if round(beat*2) % 4 == 0 else .045
    kick = np.sin(2*np.pi*(74-28*(x/.22))*x) * np.exp(-24*x)
    sound[a:a+len(x)] += kick*strength

for hit in [1.05,3.52,6.95,7.5,8.02,11.5,12.1,12.75,16.5,17.2,18.0,20.0]:
    add_tone(hit, .42, 800 if hit < 11 else 1050, .016, .002, .38, .4)

# Slow level contour with a clean tail.
contour = np.minimum(1,t/.7)*np.minimum(1,(DURATION-t)/1.5)
sound *= np.maximum(0,contour)
sound = np.tanh(sound*1.2)
stereo = np.column_stack((sound, np.roll(sound, int(.003*SR))*.97))
pcm = (np.clip(stereo,-1,1)*32767).astype('<i2')
with wave.open('assets/music.wav','wb') as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(SR)
    out.writeframes(pcm.tobytes())
