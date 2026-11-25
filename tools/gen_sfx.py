"""Звуки «Клёвого места» — синтез из шума и синусов (numpy). Пишет art/sfx/*.wav (22050 Гц, моно).
Запуск: python tools/gen_sfx.py
"""
import os
import wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "sfx")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.01, r=0.2, shape=2.0):
    x = np.ones(n)
    na = max(1, int(SR * a))
    x[:na] = np.linspace(0, 1, na)
    tail = np.linspace(1, 0, n - na) ** shape if n > na else []
    x[na:] = tail
    return x


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lp(x, f, order=2):
    b, a = butter(order, min(f / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = butter(order, min(f / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return lfilter(b, a, x)


def sweep(f0, f1, d):
    tt = t(d)
    f = np.linspace(f0, f1, len(tt))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def pad(x, d):
    return np.concatenate([np.zeros(int(SR * d)), x])


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * gain
    x = (x * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(x.tobytes())


def loopable(x, fade=0.3):
    """Сшивает конец с началом для бесшовного цикла."""
    n = int(SR * fade)
    head = x[:n] * np.linspace(0, 1, n)
    tail = x[-n:] * np.linspace(1, 0, n)
    y = x[n:].copy()
    y[-n:] = tail + head
    return y


# ---------------------------------------------------------------- вода
def splash(d=0.5, f=1800, big=False):
    n = noise(d)
    x = bp(n, 300, f) * env(len(n), 0.005, d, 3)
    bub = np.zeros(len(n))
    for k in range(6 if big else 3):
        s = int(rng.uniform(0.05, d * 0.7) * SR)
        b = sweep(rng.uniform(500, 900), rng.uniform(1200, 1800), 0.06) * env(int(SR * 0.06), 0.002, 0.06)
        bub[s:s + len(b)] += b[: len(bub) - s] * 0.4
    if big:
        x = mix(x * 1.4, lp(noise(0.25), 400) * env(int(SR * 0.25), 0.002, 0.25) * 1.5)
    return mix(x, bub)


save("splash", splash(0.45))
save("splash_big", splash(0.9, 2500, True))
save("nibble", bp(noise(0.12), 600, 1500) * env(int(SR * 0.12), 0.003, 0.12) * 0.5)
save("bite", mix(splash(0.3, 1400), pad(sweep(900, 400, 0.12) * env(int(SR * 0.12), 0.002, 0.12) * 0.5, 0.02)))
save("cast", bp(noise(0.45), 1500, 6000) * np.sin(np.linspace(0, np.pi, int(SR * 0.45))) ** 2 * 0.8)
save("hook", mix(bp(noise(0.12), 2000, 6000) * env(int(SR * 0.12), 0.002, 0.1), lp(noise(0.1), 300) * env(int(SR * 0.1), 0.002, 0.1)))
# катушка: щелчки трещотки
clicks = np.zeros(int(SR * 0.5))
for k in range(18):
    s = int(k * SR * 0.5 / 18)
    c = hp(noise(0.006), 2500) * env(int(SR * 0.006), 0.0005, 0.006)
    clicks[s:s + len(c)] += c
save("reel", clicks * 0.7)
save("line_snap", mix(hp(noise(0.08), 3000) * env(int(SR * 0.08), 0.001, 0.08) * 1.5,
                      sweep(1200, 200, 0.25) * env(int(SR * 0.25), 0.001, 0.25) * 0.4))
save("rod_break", mix(lp(noise(0.3), 1500) * env(int(SR * 0.3), 0.001, 0.3, 4) * 1.5,
                      pad(bp(noise(0.15), 800, 3000) * env(int(SR * 0.15), 0.001, 0.15), 0.05)))
# поймал — весёлое арпеджио
notes = [523, 659, 784, 1046]
arp = np.concatenate([np.sin(2 * np.pi * f * t(0.11)) * env(int(SR * 0.11), 0.005, 0.11) for f in notes])
save("catch", arp * 0.6)

# ---------------------------------------------------------------- шаги
# Шаг = мягкий удар пятки (низкий «тук») + шорох подошвы. Всё приглушено фильтром.
def thump(f, d, amt):
    tt = t(d)
    tone = np.sin(2 * np.pi * f * tt * (1 - 0.3 * tt / d)) * np.exp(-tt * 55)
    return tone * amt


def step_grass(i):
    d = 0.16
    rust = lp(bp(noise(d), 500 + i * 120, 2600), 2200) * env(int(SR * d), 0.012, d, 2.2) * 0.55
    return mix(thump(70 + i * 8, d, 0.5), rust)


def step_hard(i):
    d = 0.11
    heel = thump(95 + i * 10, d, 0.9)
    scuff = lp(bp(noise(d), 250, 1800), 1500) * env(int(SR * d), 0.002, d, 4) * 0.35
    return mix(heel, scuff)


def step_wood(i):
    d = 0.15
    knock = thump(150 + i * 14, d, 0.8) + thump(310 + i * 20, d, 0.25)
    creak = lp(bp(noise(d), 300, 1200), 1000) * env(int(SR * d), 0.003, d, 3) * 0.25
    return mix(knock, creak)


for i in range(3):
    save(f"step_grass{i}", step_grass(i), 0.5)
    save(f"step_hard{i}", step_hard(i), 0.5)
    save(f"step_wood{i}", step_wood(i), 0.55)

# ---------------------------------------------------------------- выпивка, еда, туалет
gulps = np.zeros(int(SR * 1.2))
for k in range(4):
    s = int((0.08 + k * 0.27) * SR)
    g = lp(noise(0.12), 500) * env(int(SR * 0.12), 0.01, 0.12) + sweep(250, 120, 0.12) * env(int(SR * 0.12), 0.01, 0.12) * 0.7
    gulps[s:s + len(g)] += g
save("drink", gulps)
save("ah", mix(lp(noise(0.6), 900) * env(int(SR * 0.6), 0.05, 0.6) * 0.5, sweep(320, 180, 0.6) * env(int(SR * 0.6), 0.05, 0.6) * 0.4))
save("bottle_open", mix(sweep(600, 1800, 0.05) * env(int(SR * 0.05), 0.001, 0.05), pad(hp(noise(0.25), 3000) * env(int(SR * 0.25), 0.005, 0.25) * 0.4, 0.04)))
crunch = np.zeros(int(SR * 0.9))
for k in range(5):
    s = int((0.05 + k * 0.17) * SR)
    c = bp(noise(0.08), 1500, 7000) * env(int(SR * 0.08), 0.002, 0.08, 3)
    crunch[s:s + len(c)] += c
save("eat", crunch)
save("pee", loopable(bp(noise(3.2), 1500, 5000) * (0.8 + 0.2 * np.sin(2 * np.pi * 7 * t(3.2)))))
save("poop", mix(lp(noise(0.7), 180) * env(int(SR * 0.7), 0.05, 0.7) * 2, sweep(90, 60, 0.7) * env(int(SR * 0.7), 0.05, 0.7)))
save("hic", mix(bp(noise(0.09), 400, 2000) * env(int(SR * 0.09), 0.003, 0.09), sweep(500, 900, 0.09) * env(int(SR * 0.09), 0.003, 0.09) * 0.6))
save("lighter", mix(hp(noise(0.03), 3000) * env(int(SR * 0.03), 0.001, 0.03) * 1.5, pad(bp(noise(0.5), 300, 2500) * env(int(SR * 0.5), 0.05, 0.5) * 0.4, 0.05)))
save("cough", np.concatenate([bp(noise(0.16), 200, 1800) * env(int(SR * 0.16), 0.005, 0.16), np.zeros(int(SR * 0.08)),
                              bp(noise(0.14), 200, 1600) * env(int(SR * 0.14), 0.005, 0.14) * 0.8]))

# ---------------------------------------------------------------- удары, бутылки, коробки
save("punch", mix(lp(noise(0.15), 600) * env(int(SR * 0.15), 0.001, 0.15, 3) * 1.4, bp(noise(0.05), 1000, 4000) * env(int(SR * 0.05), 0.001, 0.05) * 0.5))
save("bat_hit", mix(lp(noise(0.2), 900) * env(int(SR * 0.2), 0.001, 0.2, 3), np.sin(2 * np.pi * 180 * t(0.2)) * env(int(SR * 0.2), 0.001, 0.2, 4) * 0.8))
save("whoosh", bp(noise(0.25), 400, 2500) * np.sin(np.linspace(0, np.pi, int(SR * 0.25))) ** 3)
save("glass_break", mix(hp(noise(0.5), 2500) * env(int(SR * 0.5), 0.001, 0.5, 3),
                        *[pad(np.sin(2 * np.pi * rng.uniform(2500, 6000) * t(0.2)) * env(int(SR * 0.2), 0.001, 0.2, 4) * 0.3, rng.uniform(0, 0.2)) for _ in range(8)]))
save("bottle_clink", mix(*[np.sin(2 * np.pi * f * t(0.4)) * env(int(SR * 0.4), 0.001, 0.4, 3) for f in (2400, 3900)]) * 0.6)
save("box_pick", mix(lp(noise(0.12), 700) * env(int(SR * 0.12), 0.002, 0.12, 3), bp(noise(0.2), 800, 3000) * env(int(SR * 0.2), 0.02, 0.2) * 0.3))
save("box_break", mix(lp(noise(0.3), 500) * env(int(SR * 0.3), 0.001, 0.3, 3) * 1.6, pad(glass_n := hp(noise(0.4), 2500) * env(int(SR * 0.4), 0.001, 0.4, 3) * 0.6, 0.03)))
save("ko", mix(lp(noise(0.35), 300) * env(int(SR * 0.35), 0.001, 0.35, 3) * 1.5, pad(np.concatenate([np.sin(2 * np.pi * f * t(0.12)) * env(int(SR * 0.12), 0.003, 0.12) for f in (1568, 1318, 1046)]) * 0.35, 0.15)))

# ---------------------------------------------------------------- деньги, двери, казино
save("coin", mix(np.sin(2 * np.pi * 2093 * t(0.25)) * env(int(SR * 0.25), 0.001, 0.25, 3),
                 pad(np.sin(2 * np.pi * 2637 * t(0.3)) * env(int(SR * 0.3), 0.001, 0.3, 3), 0.07)) * 0.6)
save("cash", mix(bp(noise(0.25), 1500, 6000) * env(int(SR * 0.25), 0.002, 0.25) * 0.5,
                 pad(mix(*[np.sin(2 * np.pi * f * t(0.6)) * env(int(SR * 0.6), 0.002, 0.6, 2) for f in (1760, 2217, 2637)]) * 0.5, 0.15)))
save("door_open", mix(sweep(300, 700, 0.5) * 0.15 * (1 + 0.5 * np.sin(2 * np.pi * 30 * t(0.5))) * env(int(SR * 0.5), 0.05, 0.5),
                      lp(noise(0.5), 600) * env(int(SR * 0.5), 0.05, 0.5) * 0.3))
save("door_close", mix(lp(noise(0.2), 400) * env(int(SR * 0.2), 0.001, 0.2, 3) * 1.2, bp(noise(0.05), 800, 3000) * env(int(SR * 0.05), 0.001, 0.05) * 0.4))
save("auto_door", bp(noise(0.7), 200, 1500) * np.sin(np.linspace(0, np.pi, int(SR * 0.7))) * 0.6)
spin = np.zeros(int(SR * 1.6))
for k in range(40):
    s = int(k * SR * 1.6 / 40 * (1 + k / 80))
    if s >= len(spin):
        break
    c = bp(noise(0.01), 1500, 5000) * env(int(SR * 0.01), 0.0005, 0.01)
    spin[s:s + len(c)] += c
save("slot_spin", spin)
save("slot_win", np.concatenate([np.sin(2 * np.pi * f * t(0.09)) * env(int(SR * 0.09), 0.003, 0.09) * (np.sign(np.sin(2 * np.pi * f * t(0.09))) * 0.3 + 0.7)
                                 for f in (523, 659, 784, 659, 784, 1046, 1318, 1568)]) * 0.5)
save("lose", np.concatenate([np.sin(2 * np.pi * f * t(0.18)) * env(int(SR * 0.18), 0.003, 0.18) for f in (392, 349, 330, 262)]) * 0.5)
ball = np.zeros(int(SR * 2.2))
pos = 0.0
gap = 0.03
while pos < 2.1:
    s = int(pos * SR)
    c = bp(noise(0.008), 2500, 7000) * env(int(SR * 0.008), 0.0005, 0.008) * (1.0 - pos / 2.4)
    ball[s:s + len(c)] += c
    pos += gap
    gap *= 1.045
save("roulette", ball)
cups = np.zeros(int(SR * 1.3))
for k in range(10):
    s = int(k * 0.12 * SR)
    c = lp(noise(0.05), 1500) * env(int(SR * 0.05), 0.002, 0.05)
    cups[s:s + len(c)] += c
save("cups", cups)
save("click", bp(noise(0.02), 1500, 5000) * env(int(SR * 0.02), 0.001, 0.02) * 0.6)
save("notify", np.sin(2 * np.pi * 880 * t(0.12)) * env(int(SR * 0.12), 0.003, 0.12) * 0.4)
save("fandomat", mix(*[pad(mix(*[np.sin(2 * np.pi * f * t(0.25)) * env(int(SR * 0.25), 0.001, 0.25, 3) for f in (2600, 4100)]) * 0.5, k * 0.18) for k in range(3)],
                     pad(np.sin(2 * np.pi * 1200 * t(0.3)) * env(int(SR * 0.3), 0.01, 0.3) * 0.3, 0.6)))

# ---------------------------------------------------------------- фон (петли)
d = 8.0
wind = lp(noise(d), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.15 * t(d)))
birds = np.zeros(int(SR * d))
for k in range(9):
    s = int(rng.uniform(0, d - 0.6) * SR)
    f = rng.uniform(2500, 4200)
    chirp = np.concatenate([sweep(f, f * rng.uniform(1.1, 1.4), 0.07) * env(int(SR * 0.07), 0.005, 0.07) for _ in range(rng.integers(2, 5))])
    birds[s:s + len(chirp)] += chirp[: len(birds) - s] * 0.35
save("amb_day", loopable(mix(wind * 0.25, birds), 0.5), 0.6)
cr = np.zeros(int(SR * d))
for k in range(int(d * 3)):
    s = int(rng.uniform(0, d - 0.3) * SR)
    c = np.sin(2 * np.pi * 4300 * t(0.2)) * (np.sin(2 * np.pi * 45 * t(0.2)) > 0) * env(int(SR * 0.2), 0.01, 0.2, 1)
    cr[s:s + len(c)] += c * 0.25
save("amb_night", loopable(mix(wind * 0.15, cr), 0.5), 0.5)
lap = bp(noise(d), 150, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.35 * t(d)) ** 2)
save("amb_water", loopable(lap, 0.5), 0.6)
# музыка казино: простая лаунж-петля
bpm = 100
beat = 60 / bpm
music = np.zeros(int(SR * beat * 16))
chords = [(220, 262, 330), (196, 247, 294), (175, 220, 262), (196, 247, 294)]
for bar, ch in enumerate(chords):
    for b in range(4):
        s = int((bar * 4 + b) * beat * SR)
        tone = mix(*[np.sin(2 * np.pi * f * t(beat * 0.9)) for f in ch]) * env(int(SR * beat * 0.9), 0.02, beat * 0.9, 1.5) * 0.25
        bass = np.sin(2 * np.pi * ch[0] / 2 * t(beat * 0.5)) * env(int(SR * beat * 0.5), 0.005, beat * 0.5) * 0.5
        hat = hp(noise(0.03), 6000) * env(int(SR * 0.03), 0.001, 0.03) * 0.15
        for part, off in ((tone, 0), (bass, 0), (hat, beat / 2)):
            o = s + int(off * SR)
            music[o:o + len(part)] += part[: max(0, len(music) - o)]
save("casino_music", music, 0.55)
# ---------------------------------------------------------------- v0.6: погода и транспорт
d = 6.0
rain = mix(bp(noise(d), 1200, 7000) * 0.5, lp(noise(d), 700) * 0.35)
drops = np.zeros(int(SR * d))
for k in range(220):
    st = int(rng.uniform(0, d - 0.05) * SR)
    c = hp(noise(0.015), 2500) * env(int(SR * 0.015), 0.001, 0.015) * rng.uniform(0.2, 0.7)
    drops[st:st + len(c)] += c
save("rain", loopable(mix(rain, drops), 0.4), 0.6)
th = mix(lp(noise(3.0), 120) * env(int(SR * 3.0), 0.05, 3.0, 1.6) * 2.0,
         lp(noise(3.0), 400) * env(int(SR * 3.0), 0.01, 1.2, 3) * 1.2,
         hp(noise(0.25), 1500) * env(int(SR * 0.25), 0.002, 0.25, 3) * 0.6)
save("thunder", th, 0.95)
tt = t(2.0)
eng = np.sign(np.sin(2 * np.pi * 42 * tt)) * 0.4 + np.sin(2 * np.pi * 84 * tt) * 0.5 + np.sin(2 * np.pi * 126 * tt) * 0.2
eng = lp(eng * (0.85 + 0.15 * np.sin(2 * np.pi * 7 * tt)), 900) + lp(noise(2.0), 300) * 0.3
save("engine", loopable(eng, 0.3), 0.6)
oars = np.zeros(int(SR * 2.0))
for k in range(3):
    st = int(k * 0.66 * SR)
    sp = bp(noise(0.35), 300, 1600) * np.sin(np.linspace(0, np.pi, int(SR * 0.35))) ** 2
    oars[st:st + len(sp)] += sp
save("oars", loopable(oars, 0.2), 0.6)
chain = np.zeros(int(SR * 1.0))
for k in range(16):
    st = int(k * SR / 16)
    c = bp(noise(0.012), 2000, 6000) * env(int(SR * 0.012), 0.001, 0.012) * 0.6
    chain[st:st + len(c)] += c
save("bike", loopable(mix(chain, lp(noise(1.0), 400) * 0.25), 0.1), 0.5)
bub = np.zeros(int(SR * 3.0))
for k in range(30):
    st = int(rng.uniform(0, 2.9) * SR)
    b = sweep(rng.uniform(250, 450), rng.uniform(600, 900), 0.05) * env(int(SR * 0.05), 0.003, 0.05)
    bub[st:st + len(b)] += b * 0.5
save("bubbling", loopable(mix(bub, lp(noise(3.0), 300) * 0.15), 0.3), 0.6)
save("bell", mix(*[np.sin(2 * np.pi * f * t(0.9)) * env(int(SR * 0.9), 0.001, 0.9, 2.5) for f in (2100, 2650, 4200)]) * 0.5)
horn = mix(np.sign(np.sin(2 * np.pi * 330 * t(0.7))) * 0.4, np.sign(np.sin(2 * np.pi * 415 * t(0.7))) * 0.4)
save("horn", lp(horn, 2500) * env(int(SR * 0.7), 0.02, 0.7, 0.6), 0.7)
save("crash", mix(lp(noise(0.5), 700) * env(int(SR * 0.5), 0.001, 0.5, 3) * 1.5,
                  hp(noise(0.6), 2500) * env(int(SR * 0.6), 0.001, 0.6, 3) * 0.7), 0.9)
wh = np.sin(2 * np.pi * (2800 + 200 * np.sign(np.sin(2 * np.pi * 30 * t(0.8)))) * t(0.8)) * env(int(SR * 0.8), 0.01, 0.8, 0.5)
save("whistle", mix(wh * 0.6, bp(noise(0.8), 2500, 3500) * 0.2), 0.6)
# телевизор: «бубнёж» диктора + шипение
d = 4.0
syl = np.zeros(int(SR * d))
pos = 0.0
while pos < d - 0.3:
    ln = rng.uniform(0.08, 0.2)
    f = rng.uniform(140, 220)
    v = (np.sin(2 * np.pi * f * t(ln)) + 0.5 * np.sin(2 * np.pi * f * 2 * t(ln))) * env(int(SR * ln), 0.02, ln, 1.5)
    st = int(pos * SR)
    syl[st:st + len(v)] += bp(v + noise(ln) * 0.2, 200, 3000)
    pos += ln + rng.uniform(0.02, 0.25)
save("tv", loopable(mix(syl, hp(noise(d), 4000) * 0.08), 0.3), 0.5)
# ---------------------------------------------------------------- v0.8: голоса NPC («симлиш»), свадьба, ферма
VOWELS = [(730, 1090), (530, 1840), (270, 2290), (570, 840), (300, 870), (660, 1700)]


def formant(x, f, bw=90):
    return bp(x, max(60, f - bw), f + bw, 2)


def babble(f0, n_syl, rough=0.0, trem=0.0):
    out = []
    for k in range(n_syl):
        ln = rng.uniform(0.09, 0.17)
        tt = t(ln)
        pitch = f0 * rng.uniform(0.85, 1.25) * (1 + 0.04 * np.sin(2 * np.pi * 6 * tt))
        if trem:
            pitch *= 1 + trem * np.sin(2 * np.pi * 9 * tt)
        ph = 2 * np.pi * np.cumsum(pitch) / SR
        src = sum(np.sin(ph * h) / h for h in range(1, 14)) + noise(ln) * (0.15 + rough)
        f1, f2 = VOWELS[rng.integers(len(VOWELS))]
        v = formant(src, f1, 110) * 1.2 + formant(src, f2, 160) * 0.7 + formant(src, 2600, 300) * 0.25
        v *= env(len(tt), 0.015, ln, 1.2)
        cons = rng.choice(["p", "s", "n", "none"])
        if cons == "p":
            c = lp(noise(0.02), 2500) * env(int(SR * 0.02), 0.001, 0.02) * 0.8
        elif cons == "s":
            c = hp(noise(0.05), 4000) * env(int(SR * 0.05), 0.01, 0.05) * 0.35
        elif cons == "n":
            c = lp(np.sin(2 * np.pi * f0 * t(0.04)), 400) * env(int(SR * 0.04), 0.01, 0.04) * 0.5
        else:
            c = np.zeros(1)
        out += [c, v, np.zeros(int(SR * rng.uniform(0.0, 0.05)))]
    return np.concatenate(out)


for vname, f0, rough, trem in (("m", 125, 0.05, 0.0), ("m_low", 92, 0.15, 0.0), ("f", 225, 0.02, 0.0), ("old", 250, 0.1, 0.05)):
    for k in range(3):
        save("babble_%s%d" % (vname, k), babble(f0, int(rng.integers(5, 9)), rough, trem), 0.55)

# гармошка: весёлая (свадьба) и протяжная (поминки)
def reed(f, d):
    tt = t(d)
    x = sum(np.sign(np.sin(2 * np.pi * f * h * tt)) * (0.5 / h) for h in (1, 2)) + np.sin(2 * np.pi * f * 1.004 * tt) * 0.4
    return lp(x, 3000)


def tune(notes, beat, slow=False):
    parts = []
    for n, b in notes:
        d = beat * b
        f = 220 * 2 ** (n / 12)
        chord = reed(f, d) + reed(f * 1.5, d) * 0.5 + reed(f / 2, d) * 0.4
        parts.append(chord * env(int(SR * d), 0.03 if not slow else 0.15, d, 0.6 if not slow else 1.5))
    return np.concatenate(parts)


happy = tune([(0, 1), (4, 1), (7, 1), (4, 1), (5, 1), (9, 1), (12, 2), (7, 1), (5, 1), (4, 1), (2, 1), (0, 2), (7, 2)], 0.22)
save("wedding_music", loopable(happy, 0.2), 0.45)
sad = tune([(0, 3), (3, 2), (2, 1), (-2, 3), (0, 3), (3, 2), (7, 2), (5, 4)], 0.42, True)
save("funeral_music", loopable(sad, 0.4), 0.4)
tt = t(1.3)
moo_f = 110 + 25 * np.sin(np.linspace(0, np.pi, len(tt)))
moo = np.sin(2 * np.pi * np.cumsum(moo_f) / SR)
moo = formant(sum(np.sin(2 * np.pi * np.cumsum(moo_f * h) / SR) / h for h in range(1, 9)), 500, 200) * 1.5 + moo * 0.3
save("moo", moo * env(len(tt), 0.15, 1.3, 0.8), 0.8)
save("hammer", mix(lp(noise(0.12), 2500) * env(int(SR * 0.12), 0.001, 0.12, 4), np.sin(2 * np.pi * 900 * t(0.15)) * env(int(SR * 0.15), 0.001, 0.15, 5) * 0.5), 0.8)
save("sack", lp(noise(0.25), 500) * env(int(SR * 0.25), 0.005, 0.25, 3), 0.8)
gulp = np.zeros(int(SR * 1.2))
for k in range(5):
    st = int(k * 0.22 * SR)
    g = sweep(rng.uniform(180, 240), 90, 0.12) * env(int(SR * 0.12), 0.01, 0.12) * 0.7
    gulp[st:st + len(g)] += lp(g + noise(0.12) * 0.1, 900)
save("gulp", gulp, 0.7)
save("cheer", mix(*[bp(noise(1.2), 300 + 200 * k, 2500) * env(int(SR * 1.2), 0.1, 1.2, 1.2) * 0.25 for k in range(4)]), 0.7)
print("ok:", len(os.listdir(OUT)), "файлов")
