#!/usr/bin/env python3
"""
Simulador de puerto serial para el biorreactor HMI.

Genera telemetría sintética con variación sinusoidal + ruido en los tres
formatos que reconoce parsearTrama():

  T:24.5,P:7.2,L:60.0,C:400.1   <- trama general  (temperatura, pH, luz, CO2)
  PH:T:24.5,P:7.1                <- sensor pH  RS-485
  DO:T:24.8,D:8.5                <- sensor DO  RS-485

Requisitos:
  pip install pyserial

Configuración del par de puertos virtuales en Windows:
  1. Descargar e instalar com0com: https://sourceforge.net/projects/com0com/
  2. Abrir "Setup command prompt" de com0com y ejecutar:
         install PortName=COM10 PortName=COM11
  3. Apuntar la app a COM11 y este script a COM10.

Uso:
  python simular_serial.py COM10
  python simular_serial.py COM10 --intervalo 0.5
  python simular_serial.py /dev/ttyUSB0           (Linux con socat)
"""

import argparse
import math
import random
import sys
import time

try:
    import serial
except ImportError:
    print("[ERROR] Instala pyserial:  pip install pyserial")
    sys.exit(1)


# ── Generador de datos ────────────────────────────────────────────────────────

def _noise(amp: float) -> float:
    return amp * (random.random() * 2.0 - 1.0)


def generar_sensores(t: float) -> dict:
    """Valores de sensores con oscilación sinusoidal y ruido gaussiano."""
    return {
        "temp":  24.5  + 1.5  * math.sin(t * 0.05) + _noise(0.10),
        "ph":     7.2  + 0.3  * math.cos(t * 0.03) + _noise(0.02),
        "nivel": 85.0  + 5.0  * math.sin(t * 0.02) + _noise(0.50),
        "luz":   60.0  + 8.0  * math.cos(t * 0.04) + _noise(0.30),
        "co2":  400.0  + 30.0 * math.sin(t * 0.06) + _noise(2.00),
        "do":    8.2   + 0.5  * math.cos(t * 0.07) + _noise(0.05),
    }


def construir_trama(ciclo: int, s: dict) -> str:
    """
    Alterna entre los tres formatos reconocidos por parsearTrama().
    Ciclo 0 → trama general, 1 → PH, 2 → DO.
    """
    if ciclo % 3 == 0:
        return f"T:{s['temp']:.2f},P:{s['ph']:.2f},L:{s['luz']:.1f},C:{s['co2']:.1f}"
    elif ciclo % 3 == 1:
        return f"PH:T:{s['temp']:.2f},P:{s['ph']:.2f}"
    else:
        return f"DO:T:{s['temp']:.2f},D:{s['do']:.2f}"


# ── Entrada principal ─────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Simulador serial — biorreactor HMI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "puerto",
        help="Puerto serial (ej: COM10  o  /dev/pts/1)",
    )
    parser.add_argument(
        "--intervalo",
        type=float,
        default=1.0,
        metavar="SEG",
        help="Segundos entre tramas (default: 1.0)",
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=115200,
        help="Velocidad en baudios (default: 115200)",
    )
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.puerto, args.baud, timeout=1)
    except serial.SerialException as exc:
        print(f"[ERROR] No se pudo abrir {args.puerto}: {exc}")
        return 1

    print(f"[SIM] {args.puerto} @ {args.baud} baud  |  intervalo {args.intervalo} s")
    print("[SIM] Ctrl+C para detener\n")

    t = 0.0
    ciclo = 0
    try:
        while True:
            sensores = generar_sensores(t)
            trama = construir_trama(ciclo, sensores)
            ser.write((trama + "\n").encode())
            print(f"[TX] {trama}")

            t += args.intervalo
            ciclo += 1
            time.sleep(args.intervalo)
    except KeyboardInterrupt:
        print("\n[SIM] Detenido")
    finally:
        ser.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
