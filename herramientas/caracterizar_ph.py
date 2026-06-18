#!/usr/bin/env python3
# caracterizar_ph.py — Registro manual de pH vs volumen para sintonización difusa
#
# Uso en la RPi:
#   python3 caracterizar_ph.py
#
# Flujo:
#   1. Lee pH actual del sensor RK500-12 vía Modbus RTU
#   2. Te pregunta qué evento ocurrió y cuánto volumen
#   3. Guarda todo en un CSV listo para graficar
#
# Requisitos:
#   sudo pip3 install pyserial

import struct
import sys
import time
import csv
import os
from datetime import datetime

try:
    import serial
except ImportError:
    print("Falta pyserial. Instala con:  sudo pip3 install pyserial")
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuración
# ═══════════════════════════════════════════════════════════════════════════════
SERIAL_PORT = '/dev/ttyAMA0'
SERIAL_BAUD = 9600
QUERY_PH    = bytes.fromhex('030300000006C42A')

# Archivo de salida con timestamp para no sobreescribir pruebas anteriores
timestamp_archivo = datetime.now().strftime("%Y%m%d_%H%M%S")
ARCHIVO_CSV = os.path.join(os.path.dirname(__file__), f"prueba_ph_{timestamp_archivo}.csv")

# ═══════════════════════════════════════════════════════════════════════════════
#  Modbus RTU
# ═══════════════════════════════════════════════════════════════════════════════
def modbus_crc(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
    return crc

def leer_ph(ser):
    """Intenta leer pH y temperatura. Retorna (ph, temp) o None si falla."""
    ser.reset_input_buffer()
    ser.write(QUERY_PH)
    time.sleep(0.35)
    resp = ser.read(64)
    if len(resp) < 15:
        return None
    if modbus_crc(resp[:-2]) != (resp[-2] | resp[-1] << 8):
        return None
    ph   = struct.unpack('>f', resp[3:7])[0]
    temp = struct.unpack('>f', resp[11:15])[0]
    return ph, temp

def leer_ph_con_reintentos(ser, intentos=3):
    for i in range(intentos):
        r = leer_ph(ser)
        if r:
            return r
        if i < intentos - 1:
            print(f"  Sin respuesta, reintentando ({i+2}/{intentos})...")
            time.sleep(0.5)
    return None

# ═══════════════════════════════════════════════════════════════════════════════
#  Helpers de entrada
# ═══════════════════════════════════════════════════════════════════════════════
EVENTOS = {
    'v': 'vinagre',
    's': 'salina',
    'r': 'retiro',
    'i': 'inicio',
    'n': 'ninguno',
}

def pedir_evento():
    print("\n  ¿Qué evento ocurrió?")
    print("    [i] inicio de prueba")
    print("    [v] agregué vinagre")
    print("    [s] agregué solución salina")
    print("    [r] retiré mezcla")
    print("    [n] ninguno (solo lectura)")
    print("    [q] terminar prueba")
    while True:
        c = input("  > ").strip().lower()
        if c == 'q':
            return None, None
        if c in EVENTOS:
            break
        print("  Opción no válida. Usa i/v/s/r/n/q")

    evento = EVENTOS[c]
    volumen = 0.0

    if c in ('v', 's', 'r'):
        while True:
            try:
                vol_str = input(f"  Volumen de {evento} (ml): ").strip()
                volumen = float(vol_str)
                if volumen <= 0:
                    print("  Debe ser mayor a 0")
                    continue
                break
            except ValueError:
                print("  Número inválido")

    return evento, volumen

# ═══════════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════════
def main():
    print("=" * 55)
    print("  Caracterización pH — Biorreactor")
    print("=" * 55)

    try:
        ser = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=0.5)
        print(f"  Sensor conectado en {SERIAL_PORT}")
    except Exception as e:
        print(f"  [ERROR] No se pudo abrir {SERIAL_PORT}: {e}")
        sys.exit(1)

    # Verificar que el sensor responde
    print("  Verificando sensor...")
    r = leer_ph_con_reintentos(ser)
    if not r:
        print("  [ERROR] Sin respuesta del sensor. Verifica conexión y calibración.")
        ser.close()
        sys.exit(1)
    print(f"  Sensor OK — pH={r[0]:.2f}  T={r[1]:.1f}°C")

    # Preparar CSV
    with open(ARCHIVO_CSV, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['#', 'timestamp', 'evento', 'volumen_ml',
                         'vol_acumulado_ml', 'pH', 'temperatura_C', 'notas'])

    print(f"\n  Guardando en: {ARCHIVO_CSV}")
    print("  Presiona Enter después de mezclar y esperar estabilización.\n")

    muestra_num   = 0
    vol_acumulado = 0.0  # volumen neto agregado (adiciones - retiros)

    try:
        while True:
            evento, volumen = pedir_evento()
            if evento is None:
                break

            # Actualizar volumen acumulado
            if evento in ('vinagre', 'salina'):
                vol_acumulado += volumen
            elif evento == 'retiro':
                vol_acumulado -= volumen

            input("  [Mezcla y espera estabilización, luego Enter para leer pH] ")

            r = leer_ph_con_reintentos(ser)
            if not r:
                print("  [ADVERTENCIA] Sin respuesta del sensor. Punto no guardado.")
                continue

            ph, temp = r
            muestra_num += 1
            ts = datetime.now().strftime("%H:%M:%S")

            notas = input(f"  Notas opcionales (Enter para omitir): ").strip()

            with open(ARCHIVO_CSV, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([muestra_num, ts, evento, volumen,
                                 round(vol_acumulado, 1), round(ph, 3),
                                 round(temp, 2), notas])

            print(f"  ✓ #{muestra_num}  pH={ph:.3f}  T={temp:.1f}°C"
                  f"  Vol.acum={vol_acumulado:.1f}ml  [{evento} {volumen}ml]")

    except KeyboardInterrupt:
        print("\n  Interrumpido con Ctrl+C")

    finally:
        ser.close()

    print(f"\n  Prueba terminada. {muestra_num} muestras guardadas en:")
    print(f"  {ARCHIVO_CSV}")

if __name__ == '__main__':
    main()
