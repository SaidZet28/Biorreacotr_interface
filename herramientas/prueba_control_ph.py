#!/usr/bin/env python3
# prueba_control_ph.py — Validación del controlador difuso SISO de pH
#
# Ejecuta el lazo completo en la Raspberry Pi:
#   Sensor RK500-12 → Fuzzy Mamdani → Bomba Neutralizador (Canal 1, 100%)
#
# Parámetros de diseño:
#   Ts      = 30 s   (tiempo de muestreo — θm/4.3, θm=130 s)
#   T_max   = 7 s    (pulso máximo — 0.5% de 55 L a 39 mL/s)
#   e ∈ [0, 3.5]     (universo de discurso de entrada)
#   Pre-filtro: error ≤ 0 → sin acción (hongo acidifica naturalmente)
#
# Hardware (idéntico a prueba_total.py / RPWM3):
#   PCA9685  0x40  I2C-1   50 Hz   Canal 1 → Bomba Neutralizador
#   RK500-12 0x03  RS-485  9600 8N1  /dev/ttyAMA0
#   OE  → GPIO17   ZC  → GPIO27
#
# Requisitos:
#   sudo apt install python3-lgpio
#   sudo pip3 install smbus2 pyserial
#
# Uso:
#   python3 prueba_control_ph.py [setpoint_pH]
#   Ejemplo: python3 prueba_control_ph.py 6.5
#
# Comandos interactivos (escribe mientras corre):
#   sp 6.5    → cambiar setpoint a 6.5
#   pulso 3   → disparar pulso manual de 3 s (prueba actuador)
#   pausa     → suspender lazo (mantiene lecturas)
#   reanudar  → reactivar lazo
#   ph        → leer pH ahora (fuera del ciclo)
#   log       → mostrar últimas 5 entradas del CSV
#   exit      → salir

import os
import fcntl
import struct
import time
import threading
import sys
import csv
import signal
from datetime import datetime

# ─── Dependencias opcionales ──────────────────────────────────────────────────
try:
    import lgpio
    _LGPIO = True
except ImportError:
    print("[AVISO] lgpio no disponible — hardware GPIO deshabilitado (modo sin OE/ZC)")
    _LGPIO = False

try:
    import serial
    _SERIAL = True
except ImportError:
    print("[ERROR] Falta pyserial:  sudo pip3 install pyserial")
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════════════════════
#  Constantes de hardware (igual que raspberrypi_config.h)
# ═══════════════════════════════════════════════════════════════════════════════
GPIO_OE       = 17
GPIO_ZC       = 27

SERIAL_PORT   = '/dev/ttyAMA0'
SERIAL_BAUD   = 9600

PCA_ADDR      = 0x40
CH_NEUTRALIZ  = 1          # Canal PCA9685 de la bomba neutralizadora

QUERY_PH      = bytes.fromhex('030300000006C42A')

# Parámetros de control
TS_S          = 30         # Tiempo de muestreo [s]
T_PULSO_MAX   = 7          # Pulso máximo [s]
E_MAX         = 3.5        # Universo de discurso de entrada
PH_SP_DEFAULT = 6.5        # Setpoint por defecto
PH_MIN        = 4.0        # Límite inferior de setpoint
PH_MAX        = 7.5        # Límite superior de setpoint

# ═══════════════════════════════════════════════════════════════════════════════
#  Controlador Difuso SISO — Mamdani (réplica de controladorfuzzy.cpp)
# ═══════════════════════════════════════════════════════════════════════════════
def _trimf(x, a, b, c):
    if x <= a or x >= c:
        return 0.0
    if x <= b:
        return (x - a) / (b - a)
    return (c - x) / (c - b)

def _trapmf(x, a, b, c, d):
    if x <= a or x >= d:
        return 0.0
    if b <= x <= c:
        return 1.0
    if x < b:
        return (x - a) / (b - a)
    return (d - x) / (d - c)

def _evaluar(conjunto, x):
    params, tipo = conjunto
    if tipo == 'trimf':
        return _trimf(x, *params)
    return _trapmf(x, *params)

# Conjuntos de entrada: error e ∈ [0, 3.5]
MFS_ENTRADA = {
    'N':  ([0.0,  0.0,  0.3       ], 'trimf' ),   # Neutro
    'PE': ([0.1,  0.5,  1.0       ], 'trimf' ),   # Error Pequeño
    'ME': ([0.7,  1.4,  2.1       ], 'trimf' ),   # Error Medio
    'GE': ([1.8,  2.5,  3.5       ], 'trimf' ),   # Error Grande
    'MG': ([3.0,  3.5,  3.5, 3.5  ], 'trapmf'),   # Error Muy Grande
}

# Conjuntos de salida: t_pulso ∈ [0, 7] s
MFS_SALIDA = {
    'OFF':   ([0.0, 0.0, 0.7           ], 'trimf' ),   # 0 mL
    'POCO':  ([0.0, 1.4, 2.8           ], 'trimf' ),   # ~55 mL
    'MEDIO': ([2.1, 3.5, 4.9           ], 'trimf' ),   # ~137 mL
    'MUCHO': ([4.2, 5.6, 7.0           ], 'trimf' ),   # ~218 mL
    'MAX':   ([6.3, 7.0, 7.0,  7.0     ], 'trapmf'),   # 275 mL
}

# Reglas: (entrada, salida)
REGLAS = [
    ('N',  'OFF'  ),
    ('PE', 'POCO' ),
    ('ME', 'MEDIO'),
    ('GE', 'MUCHO'),
    ('MG', 'MAX'  ),
]

def fuzzy_calcular(error):
    """Retorna t_pulso [s] para el error dado. error debe ser ≥ 0."""
    e = max(0.0, min(E_MAX, error))
    num, den = 0.0, 0.0
    N_PTS = 71
    for i in range(N_PTS):
        x  = i * 7.0 / (N_PTS - 1)
        mu = 0.0
        for (e_nombre, s_nombre) in REGLAS:
            mu_in  = _evaluar(MFS_ENTRADA[e_nombre], e)
            mu_out = _evaluar(MFS_SALIDA [s_nombre], x)
            mu = max(mu, min(mu_in, mu_out))
        num += x * mu
        den += mu
    return num / den if den > 0.0 else 0.0

# ═══════════════════════════════════════════════════════════════════════════════
#  PCA9685 — inicialización idéntica a prueba_total.py (RPWM3, 50 Hz)
# ═══════════════════════════════════════════════════════════════════════════════
fd_pca = None
pca_ok = False

try:
    fd_pca = os.open('/dev/i2c-1', os.O_RDWR)
    fcntl.ioctl(fd_pca, 0x0703, PCA_ADDR)
    os.write(fd_pca, bytes([0x00, 0x10])); time.sleep(0.001)   # SLEEP
    os.write(fd_pca, bytes([0xFE, 0x79])); time.sleep(0.001)   # PRESCALE → 50 Hz
    os.write(fd_pca, bytes([0x00, 0x20])); time.sleep(0.001)   # Wake + AUTO-INCREMENT
    time.sleep(0.001)
    os.write(fd_pca, bytes([0x00, 0xA0])); time.sleep(0.001)   # RESTART
    pca_ok = True
    print("[PCA9685] Inicializado 0x40 @ 50 Hz")
except Exception as e:
    print(f"[PCA9685] No disponible: {e}")
    if fd_pca is not None:
        try: os.close(fd_pca)
        except: pass
        fd_pca = None

def _pca_raw(canal, valor):
    """Escribe valor PWM 0–4095 en el canal dado."""
    if not pca_ok:
        return
    reg   = 0x06 + canal * 4
    valor = max(0, min(4095, valor))
    try:
        os.write(fd_pca, bytes([reg, 0x00, 0x00, valor & 0xFF, valor >> 8]))
    except Exception as e:
        print(f"  [PCA] Error escritura: {e}")

def bomba_on():
    _pca_raw(CH_NEUTRALIZ, 4095)   # 100% — lógica RPWM3

def bomba_off():
    if not pca_ok:
        return
    reg = 0x06 + CH_NEUTRALIZ * 4
    try:
        os.write(fd_pca, bytes([reg, 0x00, 0x00, 0x00, 0x10]))   # FULL OFF
    except Exception as e:
        print(f"  [PCA] Error apagado: {e}")

# ═══════════════════════════════════════════════════════════════════════════════
#  lgpio — OE y ZC (idéntico a prueba_total.py)
# ═══════════════════════════════════════════════════════════════════════════════
h = None
fase_viva = [True]

if _LGPIO:
    try:
        h = lgpio.gpiochip_open(0)
        lgpio.gpio_claim_output(h, GPIO_OE, 0, 0)
        lgpio.gpio_claim_input(h, GPIO_ZC, lgpio.SET_PULL_UP)

        def _zc_worker():
            prev = 0
            while fase_viva[0]:
                curr = lgpio.gpio_read(h, GPIO_ZC)
                if curr == 1 and prev == 0:
                    lgpio.gpio_write(h, GPIO_OE, 1)
                    time.sleep(50e-6)
                    lgpio.gpio_write(h, GPIO_OE, 0)
                prev = curr
                time.sleep(10e-6)

        threading.Thread(target=_zc_worker, daemon=True).start()
        print("[lgpio]  OE=GPIO17  ZC=GPIO27  activos")
    except Exception as e:
        print(f"[lgpio] Error: {e} — continuando sin ZC")
        h = None

# ═══════════════════════════════════════════════════════════════════════════════
#  RS-485 — RK500-12
# ═══════════════════════════════════════════════════════════════════════════════
try:
    ser = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=0.5)
    print(f"[Serial] {SERIAL_PORT} @ {SERIAL_BAUD} baud")
except Exception as e:
    print(f"[Serial] Error: {e}")
    ser = None

def _modbus_crc(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
    return crc

def leer_ph(reintentos=3):
    """Retorna (ph, temp) o None."""
    if ser is None:
        return None
    for intento in range(reintentos):
        ser.reset_input_buffer()
        ser.write(QUERY_PH)
        time.sleep(0.35)
        resp = ser.read(64)
        if len(resp) >= 15 and _modbus_crc(resp[:-2]) == (resp[-2] | resp[-1] << 8):
            ph   = struct.unpack('>f', resp[3:7])[0]
            temp = struct.unpack('>f', resp[11:15])[0]
            return ph, temp
        if intento < reintentos - 1:
            time.sleep(0.3)
    return None

# ═══════════════════════════════════════════════════════════════════════════════
#  Estado compartido (protegido con lock)
# ═══════════════════════════════════════════════════════════════════════════════
_lock          = threading.Lock()
_setpoint      = PH_SP_DEFAULT
_lazo_activo   = True        # False cuando el usuario escribe "pausa"
_ultimo_ph     = None
_ultimo_temp   = None
_ultimo_error  = None
_ultimo_tpulso = None
_registros     = []          # lista de dicts para el CSV

def _ts():
    return datetime.now().strftime("%H:%M:%S")

def _log(ph, temp, error, t_pulso, accion):
    """Agrega una fila al registro en memoria."""
    row = {
        'timestamp': datetime.now().isoformat(timespec='seconds'),
        'ph':        round(ph,      3),
        'temp_C':    round(temp,    1),
        'setpoint':  _setpoint,
        'error':     round(error,   3),
        't_pulso_s': round(t_pulso, 2),
        'accion':    accion,
    }
    with _lock:
        _registros.append(row)
    return row

def _guardar_csv():
    nombre = f"prueba_control_ph_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    ruta   = os.path.join(os.path.dirname(__file__), nombre)
    campos = ['timestamp', 'ph', 'temp_C', 'setpoint', 'error', 't_pulso_s', 'accion']
    with open(ruta, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=campos)
        w.writeheader()
        with _lock:
            w.writerows(_registros)
    return ruta

# ═══════════════════════════════════════════════════════════════════════════════
#  Hilo de control: lazo de 30 s con pulso
# ═══════════════════════════════════════════════════════════════════════════════
_stop_event = threading.Event()

def _hilo_control():
    """
    Cada Ts=30 s:
      1. Lee pH.
      2. Pre-filtro: si error ≤ 0 → no actúa.
      3. Fuzzy → t_pulso.
      4. Activa bomba durante t_pulso segundos.
      5. Registra en CSV.
    Entre ciclos, imprime pH cada 5 s para monitoreo visual.
    """
    global _ultimo_ph, _ultimo_temp, _ultimo_error, _ultimo_tpulso

    t_inicio_ciclo = time.monotonic()
    TICK           = 5.0    # intervalo de monitoreo visual [s]
    t_ultimo_tick  = time.monotonic()

    print(f"\n[Control] Iniciado — Ts={TS_S}s  T_max={T_PULSO_MAX}s  "
          f"SP={_setpoint}  (escribe 'exit' para salir)\n")

    while not _stop_event.is_set():
        ahora = time.monotonic()

        # ── Tick de monitoreo (cada 5 s) ────────────────────────────────────
        if ahora - t_ultimo_tick >= TICK:
            t_ultimo_tick = ahora
            r = leer_ph(reintentos=2)
            if r:
                ph, temp = r
                with _lock:
                    _ultimo_ph   = ph
                    _ultimo_temp = temp
                    sp           = _setpoint
                error = sp - ph
                estado = "PAUSA" if not _lazo_activo else \
                         ("pH OK" if error <= 0 else f"e={error:+.2f}")
                print(f"  [{_ts()}]  pH={ph:.3f}  T={temp:.1f}°C  "
                      f"SP={sp:.1f}  {estado}")
            else:
                print(f"  [{_ts()}]  Sin respuesta del sensor")
            t_ultimo_tick = time.monotonic()

        # ── Ciclo de control (cada Ts=30 s) ────────────────────────────────
        if ahora - t_inicio_ciclo >= TS_S:
            t_inicio_ciclo = time.monotonic()

            if not _lazo_activo:
                print(f"  [{_ts()}]  [PAUSA] Ciclo omitido")
                continue

            r = leer_ph(reintentos=3)
            if not r:
                print(f"  [{_ts()}]  [ERROR] Sin pH en ciclo de control")
                continue

            ph, temp = r
            with _lock:
                sp           = _setpoint
                _ultimo_ph   = ph
                _ultimo_temp = temp

            error = sp - ph

            # Pre-filtro: error ≤ 0 → el hongo se encarga de acidificar
            if error <= 0.0:
                _log(ph, temp, error, 0.0, 'prefiltro')
                print(f"\n  [{_ts()}]  CICLO — pH={ph:.3f}  e={error:+.3f} → "
                      f"PRE-FILTRO (sin acción)\n")
                continue

            # Fuzzy → t_pulso
            t_pulso = fuzzy_calcular(error)
            t_pulso = max(0.0, min(float(T_PULSO_MAX), t_pulso))
            t_pulso_s = round(t_pulso)      # resolución 1 s

            with _lock:
                _ultimo_error  = error
                _ultimo_tpulso = t_pulso

            print(f"\n  [{_ts()}]  CICLO — pH={ph:.3f}  e={error:+.3f} → "
                  f"t_pulso={t_pulso:.2f}s (redond.={t_pulso_s}s)")

            _log(ph, temp, error, t_pulso, f'pulso_{t_pulso_s}s')

            # Pulso de bomba
            if t_pulso_s > 0:
                print(f"  [{_ts()}]  🔵 Bomba ON  ({t_pulso_s} s)...")
                bomba_on()
                time.sleep(t_pulso_s)
                bomba_off()
                print(f"  [{_ts()}]  ⚫ Bomba OFF")
            else:
                print(f"  [{_ts()}]  Pulso = 0 s → sin acción")
            print()

        time.sleep(0.5)

# ═══════════════════════════════════════════════════════════════════════════════
#  Hilo de entrada de comandos
# ═══════════════════════════════════════════════════════════════════════════════
def _hilo_comandos():
    global _setpoint, _lazo_activo

    ayuda = (
        "\n  Comandos:\n"
        "    sp <val>     → cambiar setpoint   (ej: sp 6.5)\n"
        "    pulso <seg>  → pulso manual 1-7 s (ej: pulso 3)\n"
        "    pausa        → suspender lazo de control\n"
        "    reanudar     → reactivar lazo\n"
        "    ph           → leer pH ahora\n"
        "    log          → mostrar últimas 5 entradas\n"
        "    exit         → guardar CSV y salir\n"
    )
    print(ayuda)

    while not _stop_event.is_set():
        try:
            raw = input()
        except EOFError:
            _stop_event.set()
            break

        partes = raw.strip().lower().split()
        if not partes:
            continue
        cmd = partes[0]

        if cmd == 'exit':
            _stop_event.set()
            break

        elif cmd == 'sp' and len(partes) == 2:
            try:
                val = float(partes[1])
                if PH_MIN <= val <= PH_MAX:
                    with _lock:
                        _setpoint = val
                    print(f"  Setpoint → {val}")
                else:
                    print(f"  Setpoint debe estar en [{PH_MIN}, {PH_MAX}]")
            except ValueError:
                print("  Valor inválido. Uso: sp 6.5")

        elif cmd == 'pulso' and len(partes) == 2:
            try:
                seg = int(partes[1])
                if 1 <= seg <= T_PULSO_MAX:
                    print(f"  [{_ts()}]  Pulso manual {seg} s → Bomba ON")
                    bomba_on()
                    time.sleep(seg)
                    bomba_off()
                    print(f"  [{_ts()}]  Bomba OFF")
                else:
                    print(f"  Segundos debe ser 1–{T_PULSO_MAX}")
            except ValueError:
                print("  Uso: pulso 3")

        elif cmd == 'pausa':
            _lazo_activo = False
            print("  Lazo de control PAUSADO (lecturas continúan)")

        elif cmd == 'reanudar':
            _lazo_activo = True
            print("  Lazo de control REANUDADO")

        elif cmd == 'ph':
            print("  Leyendo pH...")
            r = leer_ph()
            if r:
                print(f"  pH={r[0]:.3f}  T={r[1]:.1f}°C")
            else:
                print("  Sin respuesta")

        elif cmd == 'log':
            with _lock:
                ultimos = _registros[-5:]
            if not ultimos:
                print("  Sin registros aún")
            else:
                print(f"\n  {'Timestamp':<20} {'pH':>6} {'SP':>5} {'Error':>7} {'t_pulso':>8}  Acción")
                for r in ultimos:
                    print(f"  {r['timestamp']:<20} {r['ph']:>6.3f} {r['setpoint']:>5.1f} "
                          f"{r['error']:>+7.3f} {r['t_pulso_s']:>7.2f}s  {r['accion']}")
                print()

        elif cmd == 'ayuda' or cmd == '?':
            print(ayuda)

        else:
            print(f"  Comando no reconocido: '{raw.strip()}'. Escribe 'ayuda'.")

# ═══════════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════════
def _limpiar():
    bomba_off()
    fase_viva[0] = False
    if h is not None:
        try: lgpio.gpio_write(h, GPIO_OE, 1)
        except: pass
        try: lgpio.gpiochip_close(h)
        except: pass
    if fd_pca is not None:
        try: os.close(fd_pca)
        except: pass
    if ser:
        try: ser.close()
        except: pass

def _signal_handler(sig, frame):
    print("\n  Interrupción recibida...")
    _stop_event.set()

signal.signal(signal.SIGINT,  _signal_handler)
signal.signal(signal.SIGTERM, _signal_handler)

def main():
    global _setpoint

    # Setpoint por argumento
    if len(sys.argv) == 2:
        try:
            sp = float(sys.argv[1])
            if PH_MIN <= sp <= PH_MAX:
                _setpoint = sp
            else:
                print(f"  Setpoint fuera de rango [{PH_MIN}, {PH_MAX}], usando {PH_SP_DEFAULT}")
        except ValueError:
            pass

    print("\n" + "=" * 58)
    print("  Prueba Control pH — Fuzzy SISO   Biorreactor IPN")
    print("=" * 58)
    print(f"  Setpoint inicial : {_setpoint}")
    print(f"  Ts               : {TS_S} s")
    print(f"  T_pulso_max      : {T_PULSO_MAX} s")
    print(f"  Canal bomba      : PCA9685 CH{CH_NEUTRALIZ} (100% durante pulso)")
    print("=" * 58)

    # Verificar sensor
    print("  Verificando sensor de pH...")
    r = leer_ph()
    if not r:
        print("  [ERROR] Sin respuesta del sensor. Verifica conexión.")
        _limpiar()
        sys.exit(1)
    print(f"  Sensor OK — pH={r[0]:.3f}  T={r[1]:.1f}°C\n")

    # Iniciar hilos
    t_ctrl = threading.Thread(target=_hilo_control,   daemon=True)
    t_cmd  = threading.Thread(target=_hilo_comandos,  daemon=True)
    t_ctrl.start()
    t_cmd.start()

    # Esperar salida
    _stop_event.wait()

    print("\n  Deteniendo...")
    _limpiar()

    # Guardar CSV
    if _registros:
        ruta = _guardar_csv()
        print(f"  CSV guardado en: {ruta}")
        print(f"  Total de ciclos registrados: {len(_registros)}")
    else:
        print("  Sin datos para guardar.")

    print("  Salida limpia.\n")

if __name__ == '__main__':
    main()
