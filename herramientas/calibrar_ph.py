#!/usr/bin/env python3
# calibrar_ph.py — Calibración del sensor de pH RK500-12 (Modbus RTU)
#
# Uso en la RPi:
#   python3 calibrar_ph.py
#
# Proceso recomendado:
#   1. Enjuaga el sensor con agua destilada y sécalo
#   2. Sumerge en buffer pH 7 → calibra punto 7
#   3. Enjuaga → sumerge en buffer pH 4 → calibra punto 4
#   4. (Opcional) Enjuaga → sumerge en buffer pH 10 → calibra punto 10
#   5. Verifica leyendo el pH en cada buffer
#
# Requisitos:
#   sudo pip3 install pyserial

import struct
import sys
import time

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

SLAVE_PH      = 0x03
REG_CAL_PH    = 0x0055   # Registro de calibración RK500-12
QUERY_PH      = bytes.fromhex('030300000006C42A')

# Valores para cada punto de calibración
CAL_VALORES = {
    4:  0x0004,
    7:  0x0007,
    10: 0x000A,
}

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

def build_write_register(slave, reg, val):
    """Construye frame Modbus RTU función 0x06 (write single register)."""
    frame = bytes([
        slave,
        0x06,
        (reg >> 8) & 0xFF, reg & 0xFF,
        (val >> 8) & 0xFF, val & 0xFF,
    ])
    crc = modbus_crc(frame)
    return frame + bytes([crc & 0xFF, (crc >> 8) & 0xFF])

def leer_ph(ser, intentos=3):
    for i in range(intentos):
        ser.reset_input_buffer()
        ser.write(QUERY_PH)
        time.sleep(0.35)
        resp = ser.read(64)
        if len(resp) >= 15:
            if modbus_crc(resp[:-2]) == (resp[-2] | resp[-1] << 8):
                ph   = struct.unpack('>f', resp[3:7])[0]
                temp = struct.unpack('>f', resp[11:15])[0]
                return ph, temp
        if i < intentos - 1:
            print(f"  Sin respuesta, reintentando ({i+2}/{intentos})...")
            time.sleep(0.5)
    return None

def calibrar_punto(ser, ph_buffer):
    """Envía el comando de calibración para un buffer dado (4, 7 o 10)."""
    val = CAL_VALORES[ph_buffer]
    frame = build_write_register(SLAVE_PH, REG_CAL_PH, val)

    ser.reset_input_buffer()
    ser.write(frame)
    time.sleep(0.5)
    resp = ser.read(8)

    if len(resp) < 8:
        print("  [ERROR] Sin respuesta del sensor.")
        return False

    # El sensor confirma con eco del mismo frame
    if resp[:6] == frame[:6]:
        print(f"  ✓ Calibración pH {ph_buffer} confirmada por el sensor.")
        return True
    else:
        print(f"  [ADVERTENCIA] Respuesta inesperada: {resp.hex(' ')}")
        return False

# ═══════════════════════════════════════════════════════════════════════════════
#  Menú principal
# ═══════════════════════════════════════════════════════════════════════════════
def main():
    print("=" * 55)
    print("  Calibración pH — Sensor RK500-12")
    print("=" * 55)

    try:
        ser = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=0.5)
        print(f"  Puerto: {SERIAL_PORT} @ {SERIAL_BAUD} baud")
    except Exception as e:
        print(f"  [ERROR] No se pudo abrir {SERIAL_PORT}: {e}")
        sys.exit(1)

    # Verificar sensor
    print("  Verificando sensor...")
    r = leer_ph(ser)
    if not r:
        print("  [ERROR] Sin respuesta. Verifica conexión RS-485.")
        ser.close()
        sys.exit(1)
    print(f"  Sensor OK — pH={r[0]:.2f}  T={r[1]:.1f}°C\n")

    while True:
        print("  ¿Qué deseas hacer?")
        print("    [7] Calibrar punto pH 7  (empezar aquí)")
        print("    [4] Calibrar punto pH 4")
        print("    [10] Calibrar punto pH 10  (opcional)")
        print("    [l] Leer pH actual")
        print("    [q] Salir")

        opcion = input("\n  > ").strip().lower()

        if opcion == 'q':
            break

        elif opcion == 'l':
            r = leer_ph(ser)
            if r:
                print(f"  pH={r[0]:.3f}   Temp={r[1]:.1f}°C")
            else:
                print("  Sin respuesta del sensor.")

        elif opcion in ('4', '7', '10'):
            ph_buf = int(opcion)
            print(f"\n  Sumerge el sensor en buffer pH {ph_buf}.")
            print(f"  Espera a que la lectura se estabilice (≈1-2 min).")
            input("  Cuando esté estable, presiona Enter para calibrar...")

            # Leer antes de calibrar para confirmar estabilidad
            r = leer_ph(ser)
            if r:
                print(f"  Lectura actual: pH={r[0]:.3f}  T={r[1]:.1f}°C")
                diff = abs(r[0] - ph_buf)
                if diff > 1.5:
                    print(f"  [ADVERTENCIA] La lectura dista {diff:.2f} unidades del buffer.")
                    confirmar = input("  ¿Calibrar de todas formas? (s/N): ").strip().lower()
                    if confirmar != 's':
                        print("  Calibración cancelada.")
                        continue

            ok = calibrar_punto(ser, ph_buf)
            if ok:
                time.sleep(0.5)
                r = leer_ph(ser)
                if r:
                    print(f"  Verificación post-calibración: pH={r[0]:.3f}  T={r[1]:.1f}°C")
        else:
            print("  Opción no válida.")

    ser.close()
    print("\n  Salida limpia.")

if __name__ == '__main__':
    main()
