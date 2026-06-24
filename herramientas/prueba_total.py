#!/usr/bin/env python3
# prueba_total.py — Herramienta de prueba completa del biorreactor
# GPIO vía lgpio (compatible Debian 13 / Pi 4B)
# Lógica PWM idéntica a RPWM2: PCA9685 a 50 Hz, valor 0-4095, OE reset en ZC
#
# Requisitos en la RPi:
#   sudo apt install python3-lgpio
#   sudo pip3 install smbus2 pyserial
#
# Comandos interactivos:
#   pH              → Lee sensor de pH (RK500-12, slave 0x03)
#   OD              → Lee sensor de OD (RK500-04, slave 0x0A)
#   Nivel           → Lee sensor de nivel XM125
#   PCA 0..15       → Controla canal PCA9685 con porcentaje (dimmer AC)
#   EXIT            → Salir

import os, fcntl, struct, time, threading, sys

try:
    import lgpio
except ImportError:
    print("Falta lgpio. Instala con:  sudo apt install python3-lgpio")
    sys.exit(1)

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

SERIAL_PORT  = '/dev/ttyAMA0'
SERIAL_BAUD  = 9600

PCA_ADDR     = 0x40
XM125_ADDR   = 0x52
DIST_VACIO   = 1150.0    # mm (reactor vacío  — 1.15 m)
DIST_LLENO   =   65.0    # mm (reactor lleno  — 6.5 cm)
DIST_SOPORTE =  225.0    # mm (reflexión fija del soporte — ignorar)
MARGEN_SOPORTE = 20.0    # mm (±margen alrededor del soporte)

# Queries Modbus RTU precalculadas (del gestorbiorreactor.cpp)
QUERY_PH = bytes.fromhex('030300000006C42A')
QUERY_DO = bytes.fromhex('0A0300000006C4B3')

# ═══════════════════════════════════════════════════════════════════════════════
#  PCA9685 — I2C directo (inicialización completa, lógica RPWM2)
# ═══════════════════════════════════════════════════════════════════════════════
fd_pca = os.open('/dev/i2c-1', os.O_RDWR)
fcntl.ioctl(fd_pca, 0x0703, PCA_ADDR)
os.write(fd_pca, bytes([0x00, 0x10])); time.sleep(0.001)   # SLEEP
os.write(fd_pca, bytes([0xFE, 0x79])); time.sleep(0.001)   # PRESCALE → 50 Hz
os.write(fd_pca, bytes([0x00, 0x20])); time.sleep(0.001)   # Wake + AUTO-INCREMENT
time.sleep(0.001)                                           # Espera oscilador (>500 µs)
os.write(fd_pca, bytes([0x00, 0xA0])); time.sleep(0.001)   # RESTART + AUTO-INCREMENT

def pca_pwm(canal, valor):
    """Escribe valor PWM (0–4095) en un canal del PCA9685 — lógica RPWM2.
    LED_ON=0, LED_OFF=valor → el PCA genera pulso de disparo a 50 Hz."""
    reg = 0x06 + canal * 4
    valor = max(0, min(4095, valor))
    os.write(fd_pca, bytes([reg, 0x00, 0x00, valor & 0xFF, valor >> 8]))

def pca_apagar(canal):
    reg = 0x06 + canal * 4
    os.write(fd_pca, bytes([reg, 0x00, 0x00, 0x00, 0x10]))  # FULL OFF

print("[PCA9685] Inicializado en 0x40 (50 Hz)")

# ═══════════════════════════════════════════════════════════════════════════════
#  lgpio — OE y ZC  (lógica idéntica a RPWM2)
# ═══════════════════════════════════════════════════════════════════════════════
h = lgpio.gpiochip_open(0)
if h < 0:
    print("Error: no se pudo abrir gpiochip0")
    sys.exit(1)

lgpio.gpio_claim_output(h, GPIO_OE, 0, 0)          # OE=0 → PCA activo al inicio
lgpio.gpio_claim_input(h, GPIO_ZC, lgpio.SET_PULL_UP)

# ─── Hilo de cruce por cero (lógica RPWM2) ────────────────────────────────────
canales_activos = {}   # {canal: valor 0-4095}
fase_viva = [True]

def _worker():
    prev = 0
    while fase_viva[0]:
        curr = lgpio.gpio_read(h, GPIO_ZC)
        if curr == 1 and prev == 0:   # flanco de subida (0→1)
            lgpio.gpio_write(h, GPIO_OE, 1)
            time.sleep(50e-6)         # 50 µs blanking — reset del ciclo PWM
            lgpio.gpio_write(h, GPIO_OE, 0)
        prev = curr
        time.sleep(10e-6)

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
        xm125_write(0x0041, 1300)   # RANGE_END   = 1300 mm
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

        # Leer todos los picos (ordenados por fuerza de señal, no por distancia)
        picos = [xm125_read(0x0011 + j) for j in range(num_dist)]
        for i, d in enumerate(picos):
            print(f"  Objeto {i+1}: {d} mm")

        # Solo considerar picos dentro del rango físico del reactor,
        # excluyendo la reflexión fija del soporte (~225 mm)
        candidatos = [d for d in picos
                      if DIST_LLENO <= d <= DIST_VACIO
                      and abs(d - DIST_SOPORTE) > MARGEN_SOPORTE]
        if not candidatos:
            print("  Ningún objeto dentro del rango válido del reactor")
            return
        dist_liquido = min(candidatos)

        nivel = (DIST_VACIO - dist_liquido) / (DIST_VACIO - DIST_LLENO) * 100.0
        nivel = max(0.0, min(100.0, nivel))
        print(f"  Nivel = {nivel:.1f}%   Distancia = {dist_liquido} mm")
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
            print(f"  Canal {canal}: APAGADO")
        else:
            valor = int(pct * 4095 / 100)   # % → 0-4095 (lógica RPWM2)
            pca_pwm(canal, valor)
            canales_activos[canal] = valor
            print(f"  Canal {canal}: {pct}%  (valor PWM = {valor})")

    else:
        print("  Comandos: pH  OD  Nivel  PCA 0..15  EXIT")

# ─── Limpieza ─────────────────────────────────────────────────────────────────
fase_viva[0] = False
try:
    lgpio.gpio_write(h, GPIO_OE, 1)   # deshabilitar salidas
except Exception:
    pass
try:
    for c in range(16):
        pca_apagar(c)
except Exception:
    pass
try:
    os.close(fd_pca)
except Exception:
    pass
try:
    bus.close()
except Exception:
    pass
if ser:
    try:
        ser.close()
    except Exception:
        pass
try:
    lgpio.gpiochip_close(h)
except Exception:
    pass
print("\nSalida limpia.")
