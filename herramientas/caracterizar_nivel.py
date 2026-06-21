#!/usr/bin/env python3
# caracterizar_nivel.py — Curva de calibración del sensor de nivel XM125
#
# Uso en la RPi:
#   python3 caracterizar_nivel.py
#
# Flujo:
#   1. Conecta al XM125 vía I2C (0x52, bus 1) y calibra
#   2. Reactor vacío → toma distancia de referencia D_VACIO
#   3. Agrega volúmenes conocidos de agua e registra distancia con cada adición
#   4. Guarda CSV con (volumen_acumulado_ml, distancia_mm, nivel_pct)
#   5. Al finalizar imprime los parámetros DIST_VACIO y DIST_LLENO y la regresión lineal
#
# Requisitos:
#   sudo pip3 install smbus2 numpy

import os, sys, time, csv
from datetime import datetime

try:
    from smbus2 import SMBus, i2c_msg
except ImportError:
    print("Falta smbus2.  Instala con:  sudo pip3 install smbus2")
    sys.exit(1)

try:
    import numpy as np
    NUMPY_OK = True
except ImportError:
    NUMPY_OK = False
    print("[Aviso] numpy no instalado — se omitirá la regresión lineal.")
    print("        Instala con:  sudo pip3 install numpy\n")

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuración
# ═══════════════════════════════════════════════════════════════════════════════
XM125_ADDR  = 0x52
I2C_BUS     = 1
RANGE_START    = 50      # mm — inicio del rango de detección
RANGE_END      = 1300    # mm — fin del rango
DIST_SOPORTE   = 225.0   # mm — reflexión fija del soporte (se descarta)
MARGEN_SOPORTE = 20.0    # mm — ±margen alrededor del soporte
N_MUESTRAS  = 5       # lecturas promediadas por punto

timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
ARCHIVO_CSV   = os.path.join(os.path.dirname(__file__),
                             f"caracterizacion_nivel_{timestamp_str}.csv")

# ═══════════════════════════════════════════════════════════════════════════════
#  Driver XM125 (I2C)
# ═══════════════════════════════════════════════════════════════════════════════
bus = None

def xm125_write(reg: int, val: int):
    msg = i2c_msg.write(XM125_ADDR, [
        (reg >> 8) & 0xFF,  reg & 0xFF,
        (val >> 24) & 0xFF, (val >> 16) & 0xFF,
        (val >>  8) & 0xFF,  val & 0xFF
    ])
    bus.i2c_rdwr(msg)

def xm125_read(reg: int) -> int:
    w = i2c_msg.write(XM125_ADDR, [(reg >> 8) & 0xFF, reg & 0xFF])
    r = i2c_msg.read(XM125_ADDR, 4)
    bus.i2c_rdwr(w, r)
    d = list(r)
    return (d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3]

def xm125_init() -> bool:
    """Configura rango y calibra. Retorna True si OK."""
    try:
        xm125_write(0x0040, RANGE_START)
        xm125_write(0x0041, RANGE_END)
        xm125_write(0x0100, 1)           # APPLY_CONFIG_AND_CALIBRATE
        for _ in range(60):
            time.sleep(0.1)
            st = xm125_read(0x0003)
            if not (st & 0x80000000):
                print(f"  [XM125] Calibrado OK  (STATUS = {hex(st)})")
                return True
        print("  [XM125] Timeout en calibración")
        return False
    except Exception as e:
        print(f"  [XM125] Error en init: {e}")
        return False

def leer_distancia_mm() -> float | None:
    """
    Dispara una medición y retorna la distancia al objeto MÁS CERCANO (mm).
    El sensor apunta hacia abajo → el objeto más cercano es la superficie del líquido.
    Retorna None si no hay objeto en rango o hay error.
    """
    try:
        xm125_write(0x0100, 2)           # CMD_MEASURE_DISTANCE
        for _ in range(20):
            time.sleep(0.05)
            if not (xm125_read(0x0003) & 0x80000000):
                break
        result   = xm125_read(0x0010)
        num_dist = result & 0x0F
        if num_dist == 0:
            return None
        picos = [xm125_read(0x0011 + j) for j in range(num_dist)]
        print(f"  [DEBUG] picos detectados: {picos} mm")
        # Descartar reflexión fija del soporte (~225 mm)
        candidatos = [d for d in picos
                      if abs(d - DIST_SOPORTE) > MARGEN_SOPORTE]
        print(f"  [DEBUG] candidatos tras filtro: {candidatos} mm")
        if not candidatos:
            return None
        return float(min(candidatos))
    except Exception as e:
        print(f"  [Error lectura] {e}")
        return None

def leer_distancia_promedio(n: int = N_MUESTRAS) -> float | None:
    """Promedia n lecturas consecutivas para reducir ruido."""
    vals = []
    for _ in range(n):
        d = leer_distancia_mm()
        if d is not None:
            vals.append(d)
        time.sleep(0.1)
    if not vals:
        return None
    return sum(vals) / len(vals)

# ═══════════════════════════════════════════════════════════════════════════════
#  Helpers de consola
# ═══════════════════════════════════════════════════════════════════════════════
def pedir_float(prompt: str, min_val: float = 0.0) -> float | None:
    while True:
        try:
            txt = input(prompt).strip()
            if txt.lower() == 'q':
                return None
            val = float(txt)
            if val < min_val:
                print(f"  Debe ser ≥ {min_val}")
                continue
            return val
        except ValueError:
            print("  Número inválido. Escribe 'q' para terminar.")

# ═══════════════════════════════════════════════════════════════════════════════
#  Análisis final
# ═══════════════════════════════════════════════════════════════════════════════
def analizar(filas: list[dict]) -> None:
    if len(filas) < 2:
        print("\n  Se necesitan al menos 2 puntos para el análisis.")
        return

    vols = [f['volumen_acumulado_ml'] for f in filas]
    dists = [f['distancia_mm'] for f in filas]

    print("\n" + "─" * 52)
    print("  RESULTADOS DE CALIBRACIÓN")
    print("─" * 52)
    print(f"  Puntos registrados  : {len(filas)}")
    print(f"  Volumen mín / máx   : {min(vols):.0f} ml  /  {max(vols):.0f} ml")
    print(f"  Distancia mín / máx : {min(dists):.1f} mm  /  {max(dists):.1f} mm")

    # Parámetros directos (primer y último punto)
    dist_vacio = filas[0]['distancia_mm']
    dist_lleno = filas[-1]['distancia_mm']
    print(f"\n  DIST_VACIO  = {dist_vacio:.1f} mm  (primer punto)")
    print(f"  DIST_LLENO  = {dist_lleno:.1f} mm  (último punto)")
    print(f"\n  Copia en prueba_total.py / gestorbiorreactor.cpp:")
    print(f"    DIST_VACIO = {dist_vacio:.1f}")
    print(f"    DIST_LLENO = {dist_lleno:.1f}")

    if NUMPY_OK and len(filas) >= 3:
        # Regresión lineal: distancia vs volumen
        x = np.array(dists)
        y = np.array(vols)
        coef = np.polyfit(x, y, 1)
        y_pred = np.polyval(coef, x)
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        r2 = 1 - ss_res / ss_tot if ss_tot > 0 else float('nan')
        print(f"\n  Regresión lineal  Volumen = a·Distancia + b:")
        print(f"    a = {coef[0]:.4f}   b = {coef[1]:.2f}   R² = {r2:.4f}")
        if r2 < 0.98:
            print("  [Aviso] R² < 0.98 — respuesta no lineal; considera curva polinomial.")
        else:
            print("  [OK] Linealidad aceptable (R² ≥ 0.98).")

# ═══════════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════════
def main():
    global bus

    print("=" * 55)
    print("  Caracterización Sensor de Nivel XM125 — Biorreactor")
    print("=" * 55)
    print(f"  Rango configurado: {RANGE_START} – {RANGE_END} mm")
    print(f"  Promedio por punto: {N_MUESTRAS} lecturas\n")

    # Abrir I2C
    try:
        bus = SMBus(I2C_BUS)
    except Exception as e:
        print(f"  [ERROR] No se pudo abrir I2C-{I2C_BUS}: {e}")
        sys.exit(1)

    # Inicializar XM125
    print("  Inicializando y calibrando XM125 (≈ 2 s)...")
    if not xm125_init():
        bus.close()
        sys.exit(1)

    # ── Punto inicial: reactor vacío ─────────────────────────────────────────
    print("\n  PASO 1: Asegúrate de que el reactor esté VACÍO.")
    input("  Presiona Enter cuando esté listo... ")

    d_vacio = leer_distancia_promedio()
    if d_vacio is None:
        print("  [ERROR] Sin lectura del sensor. Verifica montaje y rango.")
        bus.close()
        sys.exit(1)

    print(f"  ✓ Distancia en vacío = {d_vacio:.1f} mm")

    # Preparar CSV
    with open(ARCHIVO_CSV, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow([
            '#', 'timestamp', 'evento',
            'volumen_agregado_ml', 'volumen_acumulado_ml',
            'distancia_mm', 'nivel_pct', 'notas'
        ])
        ts = datetime.now().strftime("%H:%M:%S")
        writer.writerow([0, ts, 'vacio', 0, 0,
                         round(d_vacio, 1), 0.0, 'reactor vacío'])

    filas = [{'volumen_acumulado_ml': 0.0, 'distancia_mm': d_vacio}]

    print(f"\n  Guardando en: {ARCHIVO_CSV}")
    print("  En cada paso agrega un volumen conocido de agua,")
    print("  espera 10 s a que se estabilice y presiona Enter.\n")
    print("  Escribe 'q' en el volumen para terminar.\n")

    muestra_num   = 0
    vol_acumulado = 0.0

    try:
        while True:
            vol_agregar = pedir_float(
                f"  Volumen a AGREGAR (ml) [acum. actual = {vol_acumulado:.0f} ml] > ",
                min_val=0.1
            )
            if vol_agregar is None:
                break

            input("  Agrega el agua, espera 10 s para estabilización y presiona Enter... ")

            d = leer_distancia_promedio()
            if d is None:
                print("  [ADVERTENCIA] Sin lectura; punto descartado.")
                continue

            vol_acumulado += vol_agregar
            nivel_pct = (d_vacio - d) / max(d_vacio - 1.0, 1.0) * 100.0
            nivel_pct = max(0.0, min(100.0, nivel_pct))

            muestra_num += 1
            ts = datetime.now().strftime("%H:%M:%S")
            notas = input("  Notas opcionales (Enter para omitir): ").strip()

            with open(ARCHIVO_CSV, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([
                    muestra_num, ts, 'adicion',
                    round(vol_agregar, 1), round(vol_acumulado, 1),
                    round(d, 1), round(nivel_pct, 2), notas
                ])

            filas.append({'volumen_acumulado_ml': vol_acumulado, 'distancia_mm': d})

            print(f"  ✓ #{muestra_num}  Vol. acum = {vol_acumulado:.0f} ml  "
                  f"Distancia = {d:.1f} mm  Nivel ≈ {nivel_pct:.1f}%")

    except KeyboardInterrupt:
        print("\n  Interrumpido con Ctrl+C")

    finally:
        bus.close()

    # Análisis
    if len(filas) >= 2:
        analizar(filas)

    print(f"\n  Prueba terminada. {muestra_num} puntos guardados en:")
    print(f"  {ARCHIVO_CSV}\n")

if __name__ == '__main__':
    main()
