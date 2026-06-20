#!/usr/bin/env python3
# prueba_total.py — Herramienta de prueba completa del biorreactor
#
# Requisitos en la RPi:
#   sudo pip3 install smbus2 pyserial
#   sudo pigpiod   (antes de correr)
#
# Comandos interactivos:
#   pH              → Lee sensor de pH (RK500-12, slave 0x03)
#   OD              → Lee sensor de OD (RK500-04, slave 0x0A)
#   Nivel           → Lee sensor de nivel XM125
#   PCA 0..15       → Controla canal PCA9685 con porcentaje (dimmer AC)
#   EXIT            → Salir

import os, fcntl, struct, time, threading, sys
import pigpio

try:
    import serial
except ImportError:
    print("Falta pyserial. Instala con:  sudo pip3 install pyserial")
    sys.exit(1)

try:
    from smbus2 import SMBus, i2c_msg
except ImportError:
    print("Falta smbus2. Instala con:  sudo pip3 install smbus2")
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuración de hardware
# ═══════════════════════════════════════════════════════════════════════════════
GPIO_OE      = 17
GPIO_ZC      = 27
RET_MIN_US   = 1000      # µs → 100% potencia
RET_MAX_US   = 7500      # µs → mínima potencia

SERIAL_PORT  = '/dev/ttyAMA0'
SERIAL_BAUD  = 9600

PCA_ADDR     = 0x40
XM125_ADDR   = 0x52
DIST_VACIO   = 400.0     # mm (reactor vacío)
DIST_LLENO   =  50.0     # mm (reactor lleno)

# Queries Modbus RTU precalculadas (del gestorbiorreactor.cpp)
QUERY_PH = bytes.fromhex('030300000006C42A')
QUERY_DO = bytes.fromhex('0A0300000006C4B3')

# ═══════════════════════════════════════════════════════════════════════════════
#  PCA9685 — I2C directo
# ═══════════════════════════════════════════════════════════════════════════════
fd_pca = os.open('/dev/i2c-1', os.O_RDWR)
fcntl.ioctl(fd_pca, 0x0703, PCA_ADDR)
os.write(fd_pca, bytes([0x00, 0x10])); time.sleep(0.001)   # SLEEP
os.write(fd_pca, bytes([0xFE, 0x79])); time.sleep(0.001)   # PRESCALE → 50 Hz
os.write(fd_pca, bytes([0x00, 0x20])); time.sleep(0.001)   # Wake + AUTO-INCREMENT
time.sleep(0.001)                                           # Espera oscilador (>500 µs)
os.write(fd_pca, bytes([0x00, 0xA0])); time.sleep(0.001)   # RESTART + AUTO-INCREMENT

def pca_full_on(canal):
    reg = 0x06 + canal * 4
    os.write(fd_pca, bytes([reg, 0x00, 0x10, 0x00, 0x00]))

def pca_apagar(canal):
    reg = 0x06 + canal * 4
    os.write(fd_pca, bytes([reg, 0x00, 0x00, 0x00, 0x10]))  # FULL OFF

print("[PCA9685] Inicializado en 0x40")

# ═══════════════════════════════════════════════════════════════════════════════
#  pigpio — OE y ZC
# ═══════════════════════════════════════════════════════════════════════════════
pi = pigpio.pi()
if not pi.connected:
    print("Error: pigpiod no corre. Ejecuta:  sudo pigpiod")
    sys.exit(1)

pi.set_mode(GPIO_OE, pigpio.OUTPUT)
pi.write(GPIO_OE, 1)          # salidas bloqueadas al inicio
pi.set_pull_up_down(GPIO_ZC, pigpio.PUD_UP)

# ─── Hilo de control de fase ───────────────────────────────────────────────────
canales_activos = {}   # {canal: porcentaje}
fase_viva = [True]
zc_event  = threading.Event()

def _zc_cb(gpio, level, tick):
    zc_event.set()

def _worker():
    while fase_viva[0]:
        if not zc_event.wait(timeout=0.15):
            continue
        zc_event.clear()
        if not canales_activos:
            continue
        # Todos los canales comparten OE → se disparan al mismo tiempo.
        # Se usa el porcentaje del canal activo (para prueba de un canal a la vez).
        pct = next(iter(canales_activos.values()))
        if pct <= 0:
            continue
        ret_us = RET_MAX_US - (RET_MAX_US - RET_MIN_US) * pct // 100
        time.sleep(ret_us / 1e6)
        pi.write(GPIO_OE, 0)
        time.sleep(500e-6)
        pi.write(GPIO_OE, 1)

_cb  = pi.callback(GPIO_ZC, pigpio.RISING_EDGE, _zc_cb)
threading.Thread(target=_worker, daemon=True).start()

# ═══════════════════════════════════════════════════════════════════════════════
#  XM125 — I2C con repeated start (smbus2)
# ═══════════════════════════════════════════════════════════════════════════════
bus = SMBus(1)
xm125_ok = False

def xm125_write(reg, val):
    msg = i2c_msg.write(XM125_ADDR, [
        (reg >> 8) & 0xFF,  reg & 0xFF,
        (val >> 24) & 0xFF, (val >> 16) & 0xFF,
        (val >>  8) & 0xFF,  val & 0xFF
    ])
    bus.i2c_rdwr(msg)

def xm125_read(reg):
    w = i2c_msg.write(XM125_ADDR, [(reg >> 8) & 0xFF, reg & 0xFF])
    r = i2c_msg.read(XM125_ADDR, 4)
    bus.i2c_rdwr(w, r)
    d = list(r)
    return (d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3]

def xm125_init():
    global xm125_ok
    try:
        xm125_write(0x0040, 100)    # RANGE_START = 100 mm
        xm125_write(0x0041, 2000)   # RANGE_END   = 2000 mm
        xm125_write(0x0100, 1)      # APPLY_CONFIG_AND_CALIBRATE
        for _ in range(50):
            time.sleep(0.1)
            st = xm125_read(0x0003)
            if not (st & 0x80000000):
                print(f"[XM125] Calibrado OK  (STATUS={hex(st)})")
                xm125_ok = True
                return
        print("[XM125] Timeout en calibración")
    except Exception as e:
        print(f"[XM125] Error init: {e}")

def cmd_nivel():
    if not xm125_ok:
        print("  XM125 no disponible")
        return
    try:
        xm125_write(0x0100, 2)      # CMD_MEASURE_DISTANCE
        for _ in range(20):
            time.sleep(0.05)
            if not (xm125_read(0x0003) & 0x80000000):
                break
        result   = xm125_read(0x0010)
        num_dist = result & 0x0F
        if num_dist == 0:
            print("  Sin objeto en rango")
            return
        min_d = min(xm125_read(0x0011 + j) for j in range(num_dist))
        nivel = (DIST_VACIO - min_d) / (DIST_VACIO - DIST_LLENO) * 100.0
        nivel = max(0.0, min(100.0, nivel))
        print(f"  Nivel = {nivel:.1f}%   Distancia = {min_d} mm")
    except Exception as e:
        print(f"  Error XM125: {e}")

# ═══════════════════════════════════════════════════════════════════════════════
#  RS-485 — Modbus RTU
# ═══════════════════════════════════════════════════════════════════════════════
try:
    ser = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=0.5)
    print(f"[Serial] Conectado a {SERIAL_PORT}")
except Exception as e:
    ser = None
    print(f"[Serial] No disponible: {e}")

def _modbus_crc(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
    return crc

def leer_rs485(query):
    if ser is None:
        return None
    ser.reset_input_buffer()
    ser.write(query)
    time.sleep(0.35)
    resp = ser.read(64)
    if len(resp) < 9:
        return None
    crc_ok = _modbus_crc(resp[:-2]) == (resp[-2] | resp[-1] << 8)
    if not crc_ok:
        print("  CRC error")
        return None
    if len(resp) < 15:
        return None
    val  = struct.unpack('>f', resp[3:7])[0]
    temp = struct.unpack('>f', resp[11:15])[0]
    return val, temp

# ═══════════════════════════════════════════════════════════════════════════════
#  Main — loop de comandos
# ═══════════════════════════════════════════════════════════════════════════════
xm125_init()

print("\n" + "=" * 52)
print("  Biorreactor — Herramienta de prueba completa")
print("=" * 52)
print("  pH        → Leer sensor pH")
print("  OD        → Leer sensor OD")
print("  Nivel     → Leer sensor de nivel (XM125)")
print("  PCA 0     → Dimmer canal 0  (pide porcentaje)")
print("  PCA 1..15 → Dimmer canal N")
print("  EXIT      → Salir")
print("=" * 52 + "\n")

while True:
    try:
        raw = input("> ")
    except (EOFError, KeyboardInterrupt):
        break

    cmd = raw.strip().upper()
    if not cmd:
        continue

    if cmd == "EXIT":
        break

    elif cmd == "PH":
        print("  Consultando pH...")
        r = leer_rs485(QUERY_PH)
        if r:
            print(f"  pH = {r[0]:.2f}   Temp = {r[1]:.1f} °C")
        else:
            print("  Sin respuesta del sensor pH")

    elif cmd == "OD":
        print("  Consultando OD...")
        r = leer_rs485(QUERY_DO)
        if r:
            print(f"  DO = {r[0]:.2f} mg/L   Temp = {r[1]:.1f} °C")
        else:
            print("  Sin respuesta del sensor OD")

    elif cmd == "NIVEL":
        cmd_nivel()

    elif cmd.startswith("PCA"):
        partes = cmd.split()
        if len(partes) != 2 or not partes[1].isdigit():
            print("  Uso: PCA 0  (número de canal 0-15)")
            continue
        canal = int(partes[1])
        if canal < 0 or canal > 15:
            print("  Canal debe ser 0-15")
            continue
        try:
            pct_str = input(f"  % para canal {canal} (0 = apagar): ").strip()
            pct = int(pct_str)
        except (ValueError, EOFError):
            print("  Valor inválido")
            continue
        if not 0 <= pct <= 100:
            print("  Porcentaje debe ser 0-100")
            continue
        if pct == 0:
            pca_apagar(canal)
            canales_activos.pop(canal, None)
            if not canales_activos:
                pi.write(GPIO_OE, 1)
            print(f"  Canal {canal}: APAGADO")
        else:
            pca_full_on(canal)
            canales_activos[canal] = pct
            print(f"  Canal {canal}: {pct}%")

    else:
        print("  Comandos: pH  OD  Nivel  PCA 0..15  EXIT")

# ─── Limpieza ─────────────────────────────────────────────────────────────────
fase_viva[0] = False
_cb.cancel()
pi.write(GPIO_OE, 1)
for c in range(16):
    pca_apagar(c)
os.close(fd_pca)
bus.close()
if ser:
    ser.close()
pi.stop()
print("\nSalida limpia.")
