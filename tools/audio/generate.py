"""Процедурная генерация звуков для «Дома, который помнит».

Запуск (numpy идёт в комплекте с Blender, отдельная установка не нужна):
    blender --background --python tools/audio/generate.py

Кладёт WAV в game/assets/audio/.

Почему синтез, а не библиотека сэмплов: звуки нужны конкретные и
согласованные между собой, а правятся они здесь как код — параметром,
а не поиском нового файла. Для гула, ударов и помех этого достаточно;
голос и музыку так не сделать, они придут отдельно.
"""

import math
import os
import struct
import wave

try:
    import numpy as np
except ImportError:  # pragma: no cover - запуск вне Blender
    np = None

RATE = 44100
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "game", "assets", "audio",
)


def save(name, samples):
    """Сохраняет моно-дорожку 16 бит."""
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)

    peak = float(np.max(np.abs(samples))) if len(samples) else 1.0
    if peak > 0:
        # Нормализуем с запасом: клиппинг на удара слышен сразу.
        samples = samples / peak * 0.89

    data = (samples * 32767).astype(np.int16)

    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())

    print("сохранено: %s (%.2f с)" % (path, len(samples) / RATE))


def noise(duration, seed=0):
    rng = np.random.default_rng(seed)
    return rng.uniform(-1.0, 1.0, int(RATE * duration))


def envelope(length, attack, decay, floor=0.0):
    """Огибающая: резкая атака, длинный спад. Именно спад делает удар
    ударом, а не щелчком."""
    env = np.ones(length)
    a = max(1, int(RATE * attack))
    d = max(1, int(RATE * decay))

    env[:a] = np.linspace(0.0, 1.0, a)
    tail = np.linspace(1.0, floor, min(d, length - a))
    env[a:a + len(tail)] = tail
    if a + len(tail) < length:
        env[a + len(tail):] = floor
    return env


def lowpass(signal, cutoff):
    """Однополюсный фильтр. Грубо, но для шумовой основы достаточно."""
    alpha = math.exp(-2.0 * math.pi * cutoff / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, value in enumerate(signal):
        acc = value * (1.0 - alpha) + acc * alpha
        out[i] = acc
    return out


def tone(freq, duration, wave_shape="sine"):
    t = np.linspace(0.0, duration, int(RATE * duration), endpoint=False)
    phase = 2.0 * math.pi * freq * t
    if wave_shape == "saw":
        return 2.0 * (t * freq - np.floor(0.5 + t * freq))
    return np.sin(phase)


# --- Звуки -------------------------------------------------------------

def make_scare_hit():
    """Удар скримера: низкий шум с резкой атакой. Классический
    «бум», на котором держится половина жанра."""
    body = lowpass(noise(1.6, seed=1), 180.0)
    sub = tone(48.0, 1.6) * 0.7
    hit = (body + sub) * envelope(len(body), 0.002, 1.4)
    save("scare_hit.wav", hit)


def make_wheel_roll():
    """Колесо по полу: широкополосный рокот с медленной пульсацией
    от оборота."""
    base = lowpass(noise(2.4, seed=7), 900.0)
    t = np.linspace(0.0, 2.4, len(base), endpoint=False)
    # Пульсация — это и есть «катится», а не «шумит».
    wobble = 0.55 + 0.45 * np.sin(2.0 * math.pi * 6.5 * t)
    fade = envelope(len(base), 0.06, 2.2, floor=0.0)
    save("wheel_roll.wav", base * wobble * fade)


def make_radio_static():
    """Помехи рации перед репликой пит-волла."""
    hiss = noise(0.9, seed=13) * 0.5
    crackle = noise(0.9, seed=21)
    crackle = np.where(np.abs(crackle) > 0.93, crackle * 3.0, 0.0)
    mix = lowpass(hiss + crackle, 4200.0)
    save("radio_static.wav", mix * envelope(len(mix), 0.01, 0.85))


def make_ambience():
    """Ровный гул дома: низкие частоты плюс еле слышное дыхание.
    Тишина в хорроре звучит хуже, чем гул, — в тишине слышно, что
    звука просто нет."""
    length = int(RATE * 8.0)
    base = lowpass(noise(8.0, seed=3), 90.0)
    t = np.linspace(0.0, 8.0, length, endpoint=False)
    breath = 0.75 + 0.25 * np.sin(2.0 * math.pi * 0.08 * t)
    save("ambience.wav", base * breath * 0.6)


def make_door_creak():
    """Скрип: пила по частоте, дрожащая от трения."""
    duration = 1.8
    t = np.linspace(0.0, duration, int(RATE * duration), endpoint=False)
    sweep = 220.0 + 140.0 * np.sin(2.0 * math.pi * 0.6 * t)
    phase = 2.0 * math.pi * np.cumsum(sweep) / RATE
    body = np.sin(phase) * 0.35
    grit = lowpass(noise(duration, seed=31), 2600.0) * 0.5
    save("door_creak.wav", (body + grit) * envelope(len(t), 0.15, 1.5))


def make_step():
    """Шаг по доскам: короткий стук с деревянным призвуком."""
    duration = 0.28
    thud = lowpass(noise(duration, seed=41), 320.0)
    wood = tone(180.0, duration) * 0.3
    save("step.wav", (thud + wood) * envelope(int(RATE * duration), 0.001, 0.24))


def main():
    if np is None:
        print("нужен numpy — запускай через blender --background --python")
        return

    make_scare_hit()
    make_wheel_roll()
    make_radio_static()
    make_ambience()
    make_door_creak()
    make_step()
    print("готово: звуки в %s" % OUT_DIR)


if __name__ == "__main__":
    main()
