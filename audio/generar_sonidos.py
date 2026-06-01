"""
Genera los 4 archivos WAV de la aplicación biorreactor HMI.
Los tonos son idénticos a los que generaba GestorAudio con QAudioSink.

Uso:
    python generar_sonidos.py

Requiere solo la librería estándar de Python (módulos wave y struct).
Los archivos se generan en el mismo directorio que este script.
"""

import wave
import struct
import math
import os

SAMPLE_RATE = 22050
AMPLITUDE   = 0.55


def gen_tone(freq_hz: float, duration_ms: int) -> list[int]:
    samples = int(SAMPLE_RATE * duration_ms / 1000)
    attack  = min(SAMPLE_RATE * 10 // 1000, samples // 4)
    decay   = min(SAMPLE_RATE * 10 // 1000, samples // 4)
    out = []
    for i in range(samples):
        if i < attack:
            env = i / attack
        elif i > samples - decay:
            env = (samples - i) / decay
        else:
            env = 1.0
        out.append(int(AMPLITUDE * env * math.sin(2 * math.pi * freq_hz * i / SAMPLE_RATE) * 32767))
    return out


def gen_silence(duration_ms: int) -> list[int]:
    return [0] * int(SAMPLE_RATE * duration_ms / 1000)


def write_wav(filename: str, sequence: list[tuple[float, int]]) -> None:
    """sequence: lista de (frecuencia_hz, duracion_ms); frecuencia 0 = silencio."""
    samples: list[int] = []
    for freq, dur in sequence:
        samples += gen_silence(dur) if freq == 0 else gen_tone(freq, dur)

    out_path = os.path.join(os.path.dirname(__file__), filename)
    with wave.open(out_path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    print(f"  Generado: {filename}  ({len(samples)} muestras, {len(samples)/SAMPLE_RATE*1000:.0f} ms)")


if __name__ == "__main__":
    print("Generando archivos WAV...")

    # Tres pulsos agudos de 880 Hz — alarma crítica
    write_wav("alerta.wav", [
        (880, 180), (0, 80),
        (880, 180), (0, 80),
        (880, 180),
    ])

    # Dos pitidos de tono medio — advertencia
    write_wav("advertencia.wav", [
        (660, 200), (0, 120),
        (660, 200),
    ])

    # Acorde ascendente Do-Mi-Sol — éxito
    write_wav("exito.wav", [
        (523, 150), (0, 40),
        (659, 150), (0, 40),
        (784, 300),
    ])

    # Pitido único de 440 Hz — inicio de proceso
    write_wav("inicio.wav", [
        (440, 250),
    ])

    print("Listo. Coloca los 4 archivos WAV en Prototipo/audio/ antes de compilar.")
