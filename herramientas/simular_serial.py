#!/usr/bin/env python3
"""
Simulador Modbus RTU para el biorreactor HMI.

Responde a las consultas del RK500-12 (pH, slave 0x03) y RK500-04 (DO, slave 0x0A)
con datos sintéticos en formato Modbus RTU binario (3 floats IEEE 754 big-endian).

Configuración del par de puertos virtuales en Windows:
  1. Descargar e instalar com0com: https://sourceforge.net/projects/com0com/
  2. Abrir "Setup command prompt" y ejecutar:
         install PortName=COM10 PortName=COM11
  3. Apuntar la app a COM11 y este script a COM10.

Uso:
  python simular_serial.py COM10
  python simular_serial.py /dev/pts/1           (Linux con socat)
"""

import argparse
import math
import random
import struct
import sys
import time

try:
    import serial
except ImportError:
    print("[ERROR] Instala pyserial:  pip install pyserial")
    sys.exit(1)


# ── CRC-16/Modbus ─────────────────────────────────────────────────────────────

def modbus_crc(data: bytes) -> int:
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc


def append_crc(data: bytes) -> bytes:
    crc = modbus_crc(data)
    return data + bytes([crc & 0xFF, (crc >> 8) & 0xFF])


# ── Generador de datos sintéticos ─────────────────────────────────────────────

def _noise(amp: float) -> float:
    return amp * (random.random() * 2.0 - 1.0)


def generar_sensores(t: float) -> dict:
    return {
        "ph":    7.2  + 0.3  * math.cos(t * 0.03) + _noise(0.02),
        "do":    8.2  + 0.5  * math.cos(t * 0.07) + _noise(0.05),
        "temp": 24.5  + 1.5  * math.sin(t * 0.05) + _noise(0.10),
        "sat":  95.0  + 3.0  * math.sin(t * 0.04) + _noise(0.50),
    }


# ── Construcción de respuestas Modbus RTU ─────────────────────────────────────

def build_read_response(slave: int, floats: tuple) -> bytes:
    """
    Respuesta a función 0x03 (read holding registers).
    Devuelve: slave(1) + 0x03(1) + byteCount(1) + 3*float32_be(12) + CRC(2)
    """
    payload = bytes([slave, 0x03, 12])
    for f in floats:
        payload += struct.pack(">f", f)
    return append_crc(payload)


# ── Procesamiento de frames recibidos ─────────────────────────────────────────

SLAVE_PH = 0x03
SLAVE_DO = 0x0A

# Registros de calibración reconocidos (dirección)
CAL_REGS = {
    (SLAVE_PH, 0x0055): "pH (4/7/10)",
    (SLAVE_DO, 0x001A): "DO aire",
    (SLAVE_DO, 0x001C): "DO cero",
}

rx_buf = b""


def process_rx(ser, t: float) -> None:
    global rx_buf
    if ser.in_waiting:
        rx_buf += ser.read(ser.in_waiting)

    while len(rx_buf) >= 8:
        slave    = rx_buf[0]
        func     = rx_buf[1]

        if func == 0x03:
            # Solicitud de lectura — 8 bytes: slave func addr_h addr_l qty_h qty_l crc_l crc_h
            if len(rx_buf) < 8:
                break
            frame = rx_buf[:8]
            # Verificar CRC
            calc = modbus_crc(frame[:6])
            recv = frame[6] | (frame[7] << 8)
            rx_buf = rx_buf[8:]
            if calc != recv:
                print(f"[RX] CRC error en solicitud: {frame.hex(' ')}")
                continue
            sensors = generar_sensores(t)
            if slave == SLAVE_PH:
                resp = build_read_response(slave, (sensors["ph"], -4.3, sensors["temp"]))
                print(f"[RX] Solicitud pH  → respondiendo pH={sensors['ph']:.2f} T={sensors['temp']:.2f}°C")
            elif slave == SLAVE_DO:
                resp = build_read_response(slave, (sensors["do"], sensors["sat"], sensors["temp"]))
                print(f"[RX] Solicitud DO  → respondiendo DO={sensors['do']:.2f} T={sensors['temp']:.2f}°C")
            else:
                print(f"[RX] Slave desconocido 0x{slave:02X}, ignorando")
                continue
            ser.write(resp)

        elif func == 0x06:
            # Comando de escritura (calibración) — 8 bytes
            if len(rx_buf) < 8:
                break
            frame = rx_buf[:8]
            calc = modbus_crc(frame[:6])
            recv = frame[6] | (frame[7] << 8)
            rx_buf = rx_buf[8:]
            if calc != recv:
                print(f"[RX] CRC error en calibración: {frame.hex(' ')}")
                continue
            reg = (frame[2] << 8) | frame[3]
            val = (frame[4] << 8) | frame[5]
            key = (slave, reg)
            nombre = CAL_REGS.get(key, f"reg 0x{reg:04X}")
            print(f"[RX] Calibración  slave=0x{slave:02X}  {nombre}  valor=0x{val:04X}  → eco")
            ser.write(frame)  # eco = confirmación de éxito

        else:
            print(f"[RX] Byte inesperado 0x{slave:02X}, descartando para re-sincronizar")
            rx_buf = rx_buf[1:]


# ── Entrada principal ─────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Simulador Modbus RTU — biorreactor HMI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("puerto", help="Puerto serial (ej: COM10  o  /dev/pts/1)")
    parser.add_argument("--baud", type=int, default=9600,
                        help="Baudios (default: 9600 — igual que sensores reales)")
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.puerto, args.baud, timeout=0.1)
    except serial.SerialException as exc:
        print(f"[ERROR] No se pudo abrir {args.puerto}: {exc}")
        return 1

    print(f"[SIM] {args.puerto} @ {args.baud} baud — Modbus RTU")
    print(f"[SIM] Slaves: pH=0x{SLAVE_PH:02X} (RK500-12)  DO=0x{SLAVE_DO:02X} (RK500-04)")
    print("[SIM] Ctrl+C para detener\n")

    t = 0.0
    try:
        while True:
            process_rx(ser, t)
            t += 0.1
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n[SIM] Detenido")
    finally:
        ser.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
