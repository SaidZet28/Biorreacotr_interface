#!/usr/bin/env python3
"""
escalon_temperatura.py — Protocolo completo de experimento biorreactor.

CICLO:
  1. LLENADO   → Bomba solución salina (canal 3) ON → ENTER para detener.
  2. BURBUJEO  → Burbujeador (canal 2) ON. Inicia medición continua de sensores.
  3. MANTA     → Escribir 'manta'   + ENTER → Calentadores (canales 0 y 1) al 80 %.
  4. VINAGRE   → Escribir 'vinagre' + ENTER → Marca evento en CSV.
  5. exit / Ctrl+C → Apaga todo y guarda CSV.

Sensores (Modbus RTU RS-485):
  pH  (slave 0x03) → pH y temperatura
  OD  (slave 0x0A) → DO (mg/L) y temperatura

CSV: tiempo_s | ph | temp_ph_C | od_mgL | temp_od_C | temp_prom_C | evento

Requisitos en RPi:
    sudo pip3 install smbus2 pyserial pigpio
    sudo pigpiod
    sudo python3 escalon_temperatura.py
"""

import os, fcntl, struct, time, threading, sys, signal, csv
from datetime import datetime

try:
    import pigpio
except ImportError:
    print("Falta pigpio.  Instala: sudo pip3 install pigpio"); sys.exit(1)
try:
    import serial
except ImportError:
    print("Falta pyserial. Instala: sudo pip3 install pyserial"); sys.exit(1)

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuración
# ═══════════════════════════════════════════════════════════════════════════════
ESCALON_PCT   = 80        # % de potencia para la manta térmica
CANAL_CALENT  = [0, 1]   # PCA9685 → calentadores
CANAL_BURBUJA = 2         # PCA9685 → burbujeador
CANAL_BOMBA   = 3         # PCA9685 → bomba solución salina
CANAL_VINAGRE = 4         # PCA9685 → bomba vinagre
INTERVALO_S   = 2.0       # Segundos entre lecturas de sensores

PCA_ADDR   = 0x40
GPIO_OE    = 17           # Output Enable del PCA9685 (activo-LOW)
GPIO_ZC    = 27           # Detección cruce en cero
RET_MIN_US = 1000         # Retardo mínimo → 100 % potencia
RET_MAX_US = 7500         # Retardo máximo → potencia mínima

SERIAL_PORT = '/dev/ttyAMA0'
SERIAL_BAUD = 9600
QUERY_PH = bytes.fromhex('030300000006C42A')   # pH  slave 0x03
QUERY_DO = bytes.fromhex('0A0300000006C4B3')   # OD  slave 0x0A

# ═══════════════════════════════════════════════════════════════════════════════
#  PCA9685 — I2C directo
# ═══════════════════════════════════════════════════════════════════════════════
fd_pca = os.open('/dev/i2c-1', os.O_RDWR)
fcntl.ioctl(fd_pca, 0x0703, PCA_ADDR)
os.write(fd_pca, bytes([0x00, 0x10])); time.sleep(0.001)   # SLEEP
os.write(fd_pca, bytes([0x00, 0x20])); time.sleep(0.001)   # AUTO-INCREMENT
print("[PCA9685] Inicializado en 0x40")

def pca_full_on(canal):
    reg = 0x06 + canal * 4
    os.write(fd_pca, bytes([reg, 0x00, 0x10, 0x00, 0x00]))

def pca_apagar(canal):
    reg = 0x06 + canal * 4
    os.write(fd_pca, bytes([reg, 0x00, 0x00, 0x00, 0x10]))

def apagar_todo():
    for c in range(16):
        pca_apagar(c)

# ═══════════════════════════════════════════════════════════════════════════════
#  pigpio — control de fase con cruce en cero
# ═══════════════════════════════════════════════════════════════════════════════
pi = pigpio.pi()
if not pi.connected:
    print("Error: pigpiod no corre.  Ejecuta: sudo pigpiod"); sys.exit(1)

pi.set_mode(GPIO_OE, pigpio.OUTPUT)
pi.write(GPIO_OE, 1)                           # salidas bloqueadas al inicio
pi.set_pull_up_down(GPIO_ZC, pigpio.PUD_UP)

canales_activos = {}   # {canal: pct}  — todos comparten OE
fase_viva       = [True]
zc_event        = threading.Event()

def _zc_cb(gpio, level, tick):
    zc_event.set()

def _worker_zc():
    """Hilo de control de fase: dispara OE en el ángulo correcto tras cada ZC."""
    while fase_viva[0]:
        if not zc_event.wait(timeout=0.15):
            continue
        zc_event.clear()
        if not canales_activos:
            continue
        # Usa la potencia máxima entre los canales activos
        pct = max(canales_activos.values())
        if pct <= 0:
            continue
        ret_us = RET_MAX_US - (RET_MAX_US - RET_MIN_US) * pct // 100
        time.sleep(ret_us / 1e6)
        pi.write(GPIO_OE, 0)
        time.sleep(500e-6)
        pi.write(GPIO_OE, 1)

_cb = pi.callback(GPIO_ZC, pigpio.RISING_EDGE, _zc_cb)
threading.Thread(target=_worker_zc, daemon=True).start()

# ═══════════════════════════════════════════════════════════════════════════════
#  RS-485 — Modbus RTU
# ═══════════════════════════════════════════════════════════════════════════════
try:
    ser = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=0.5)
    print(f"[Serial]  {SERIAL_PORT} OK")
except Exception as e:
    print(f"[Serial]  Error: {e}"); sys.exit(1)

ser_lock = threading.Lock()

def _crc(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
    return crc

def leer_sensor(query, nombre):
    """Retorna (valor_primario, temperatura_C) o (None, None) si falla."""
    with ser_lock:
        ser.reset_input_buffer()
        ser.write(query)
        time.sleep(0.35)
        resp = ser.read(64)
    if len(resp) < 15:
        return None, None
    if _crc(resp[:-2]) != (resp[-2] | resp[-1] << 8):
        return None, None
    val  = struct.unpack('>f', resp[3:7])[0]
    temp = struct.unpack('>f', resp[11:15])[0]
    return val, temp

# ═══════════════════════════════════════════════════════════════════════════════
#  Estado compartido entre hilos
# ═══════════════════════════════════════════════════════════════════════════════
datos        = []
datos_lock   = threading.Lock()
evento_sig   = [None]    # string del próximo evento a estampar en la muestra
medir_activo = [False]
t_inicio_med = [None]

def sensor_worker():
    """Hilo que lee sensores cada INTERVALO_S y guarda en datos[]."""
    siguiente = time.time() + INTERVALO_S
    while medir_activo[0]:
        espera = siguiente - time.time()
        if espera > 0:
            time.sleep(espera)
        siguiente += INTERVALO_S

        elapsed         = time.time() - t_inicio_med[0]
        ph_val, t_ph    = leer_sensor(QUERY_PH, "pH")
        od_val, t_od    = leer_sensor(QUERY_DO, "OD")
        temps           = [v for v in [t_ph, t_od] if v is not None]
        t_prom          = sum(temps) / len(temps) if temps else None

        ev = evento_sig[0]; evento_sig[0] = None   # consumir evento

        fila = {
            'tiempo_s':    round(elapsed, 1),
            'ph':          ph_val,
            'temp_ph_C':   t_ph,
            'od_mgL':      od_val,
            'temp_od_C':   t_od,
            'temp_prom_C': t_prom,
            'evento':      ev or '',
        }
        with datos_lock:
            datos.append(fila)

        # ── Imprimir línea de datos ──
        ph_s  = f"{ph_val:.3f}"  if ph_val  is not None else "  ---"
        tph_s = f"{t_ph:.2f}"   if t_ph    is not None else "  ---"
        od_s  = f"{od_val:.3f}" if od_val  is not None else "  ---"
        tod_s = f"{t_od:.2f}"   if t_od    is not None else "  ---"
        p_s   = f"{t_prom:.2f}" if t_prom  is not None else "  ---"
        ev_s  = f"  ◄◄ {ev} ►►" if ev else ""
        print(f"{elapsed:>7.1f}s | pH {ph_s} {tph_s}°C | OD {od_s}mg/L {tod_s}°C | T {p_s}°C{ev_s}")

# ═══════════════════════════════════════════════════════════════════════════════
#  Guardado CSV
# ═══════════════════════════════════════════════════════════════════════════════
def guardar_csv():
    if not datos:
        print("Sin datos que guardar."); return
    ts   = datetime.now().strftime("%Y%m%d_%H%M%S")
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"protocolo_{ts}.csv")
    with open(path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'tiempo_s', 'ph', 'temp_ph_C', 'od_mgL', 'temp_od_C', 'temp_prom_C', 'evento'
        ])
        writer.writeheader()
        with datos_lock:
            writer.writerows(datos)
    print(f"\n[CSV] Guardado en: {path}")

# ═══════════════════════════════════════════════════════════════════════════════
#  Salida limpia
# ═══════════════════════════════════════════════════════════════════════════════
def salida_limpia(*_):
    print("\n[FIN] Apagando actuadores...")
    medir_activo[0] = False
    fase_viva[0]    = False
    _cb.cancel()
    pi.write(GPIO_OE, 1)
    apagar_todo()
    os.close(fd_pca)
    ser.close()
    pi.stop()
    guardar_csv()
    sys.exit(0)

signal.signal(signal.SIGINT,  salida_limpia)
signal.signal(signal.SIGTERM, salida_limpia)

# ═══════════════════════════════════════════════════════════════════════════════
#  PROTOCOLO
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "═"*62)
print("  BIORREACTOR — Protocolo de experimento")
print("═"*62)

# ── FASE 1: LLENADO ───────────────────────────────────────────────────────────
print("\n▶ FASE 1 — LLENADO")
print("  Bomba solución salina (canal 3) encendida.")
print("  Presiona ENTER cuando el nivel sea el deseado...")
pca_full_on(CANAL_BOMBA)
canales_activos[CANAL_BOMBA] = 100
input()
pca_apagar(CANAL_BOMBA)
canales_activos.pop(CANAL_BOMBA, None)
print("  ✓ Bomba apagada. Llenado completo.")

# ── FASE 2: BURBUJEO + INICIO DE MEDICIÓN ─────────────────────────────────────
print("\n▶ FASE 2 — BURBUJEO")
pca_full_on(CANAL_BURBUJA)
canales_activos[CANAL_BURBUJA] = 100
print("  Burbujeador (canal 2) encendido.")
time.sleep(1.0)

print("\n▶ MEDICIÓN — Iniciando lectura de sensores cada", INTERVALO_S, "s")
t_inicio_med[0] = time.time()
medir_activo[0] = True
threading.Thread(target=sensor_worker, daemon=True).start()

print(f"\n  {'t(s)':>7} | {'pH':>7} {'T_pH°C':>8} | {'OD mg/L':>8} {'T_OD°C':>7} | {'Tprom°C':>8}")
print("  " + "─"*63)
print("\n  Comandos:")
print("    manta   → Activa manta térmica al 80 %")
print("    vinagre → Marca evento de adición de vinagre")
print("    exit    → Terminar y guardar CSV\n")

# ── FASE 3+: LOOP DE COMANDOS (manta / vinagre / exit) ────────────────────────
manta_activa = False

while True:
    try:
        cmd = input("  > ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        break

    if cmd == 'manta':
        if manta_activa:
            print("  (La manta ya está activa)")
            continue
        for c in CANAL_CALENT:
            pca_full_on(c)
            canales_activos[c] = ESCALON_PCT
        evento_sig[0] = 'MANTA_ON'
        manta_activa  = True
        print(f"  ✓ Manta térmica ON — {ESCALON_PCT}% en canales {CANAL_CALENT}")

    elif cmd == 'vinagre':
        pca_full_on(CANAL_VINAGRE)
        canales_activos[CANAL_VINAGRE] = 100
        evento_sig[0] = 'VINAGRE'
        print("  ✓ Bomba vinagre (canal 4) ON — presiona ENTER para detenerla")
        input()
        pca_apagar(CANAL_VINAGRE)
        canales_activos.pop(CANAL_VINAGRE, None)
        evento_sig[0] = 'VINAGRE_STOP'
        print("  ✓ Bomba vinagre apagada")

    elif cmd == 'exit':
        break

    else:
        print("  Comandos: manta | vinagre | exit")

salida_limpia()
