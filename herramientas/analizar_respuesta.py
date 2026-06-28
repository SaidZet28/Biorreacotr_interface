#!/usr/bin/env python3
"""analizar_respuesta.py — Análisis de respuesta del controlador fuzzy pH

Uso:
    python3 analizar_respuesta.py                  # último CSV en ~/biorreactor_datos/
    python3 analizar_respuesta.py ruta/datos.csv   # CSV específico

Genera:
    - Gráfica interactiva (matplotlib)
    - PNG guardado junto al CSV
    - Métricas en consola: tiempo de establecimiento, sobreimpulso, error estacionario
"""

import sys
import os
import csv
import glob
from datetime import datetime
import math

try:
    import matplotlib.pyplot as plt
    import matplotlib.gridspec as gridspec
    from matplotlib.patches import Patch
except ImportError:
    print("Instala matplotlib:  pip install matplotlib --break-system-packages")
    sys.exit(1)

# ── Cargar CSV ────────────────────────────────────────────────────────────────
DATA_DIR = os.path.expanduser('~/biorreactor_datos')

def cargar_csv(path=None):
    if path is None:
        archivos = sorted(glob.glob(os.path.join(DATA_DIR, '*.csv')))
        if not archivos:
            print(f"No hay CSVs en {DATA_DIR}")
            sys.exit(1)
        path = archivos[-1]
    print(f"Cargando: {path}")
    registros = []
    with open(path, newline='') as f:
        for r in csv.DictReader(f):
            registros.append({
                'ts':      r['ts'],
                'ph':      float(r['ph']),
                'sp':      float(r['sp']),
                'error':   float(r['error']),
                't_pulso': float(r['t_pulso']),
                'accion':  r['accion'],
            })
    print(f"  {len(registros)} ciclos cargados")
    return registros, path

# ── Tiempo relativo en segundos ───────────────────────────────────────────────
def tiempos_s(registros):
    t0 = datetime.fromisoformat(registros[0]['ts'])
    return [(datetime.fromisoformat(r['ts']) - t0).total_seconds() for r in registros]

# ── Métricas de respuesta ─────────────────────────────────────────────────────
def calcular_metricas(registros, ts):
    ph  = [r['ph']  for r in registros]
    sp  = registros[0]['sp']          # setpoint (asume constante)
    err = [r['error'] for r in registros]

    # Sobreimpulso: pH máximo - setpoint  (solo si supera SP)
    ph_max = max(ph)
    sobreimpulso = max(0.0, ph_max - sp)

    # Error estacionario: promedio del último 20% de ciclos
    n_est = max(1, len(ph) // 5)
    e_est = sum(err[-n_est:]) / n_est

    # Tiempo de establecimiento (±0.3 pH del SP, ventana final estable)
    BANDA = 0.3
    t_est = None
    for i in range(len(ph) - 1, -1, -1):
        if abs(err[i]) > BANDA:
            if i + 1 < len(ts):
                t_est = ts[i + 1]
            break

    # Número de pulsos activos
    pulsos = [r for r in registros if r['t_pulso'] > 0]
    t_bomba_total = sum(r['t_pulso'] for r in pulsos)

    return {
        'sp':             sp,
        'ph_inicial':     ph[0],
        'ph_final':       ph[-1],
        'sobreimpulso':   sobreimpulso,
        'error_est':      e_est,
        't_establecimiento': t_est,
        'n_pulsos':       len(pulsos),
        't_bomba_total':  t_bomba_total,
        'duracion_total': ts[-1] if ts else 0,
    }

# ── Gráfica ───────────────────────────────────────────────────────────────────
def graficar(registros, ts, metricas, path_csv):
    ph      = [r['ph']      for r in registros]
    sp_vals = [r['sp']      for r in registros]
    err     = [r['error']   for r in registros]
    tp      = [r['t_pulso'] for r in registros]
    accion  = [r['accion']  for r in registros]

    # Colores por acción
    COLOR_ACCION = {
        'prefiltro': '#6B7280',   # gris — dentro de banda muerta
        'guarda_nivel': '#F59E0B', # amarillo — inhibido por nivel
    }
    def color_bar(a):
        if a.startswith('pulso_'):  return '#3B82F6'   # azul — pulso real
        return COLOR_ACCION.get(a, '#6B7280')

    fig = plt.figure(figsize=(14, 9), facecolor='#111827')
    fig.patch.set_facecolor('#111827')
    gs  = gridspec.GridSpec(3, 1, hspace=0.45, figure=fig,
                            left=0.07, right=0.97, top=0.91, bottom=0.08)

    ax_ph  = fig.add_subplot(gs[0])
    ax_err = fig.add_subplot(gs[1], sharex=ax_ph)
    ax_tp  = fig.add_subplot(gs[2], sharex=ax_ph)

    for ax in (ax_ph, ax_err, ax_tp):
        ax.set_facecolor('#1F2937')
        ax.tick_params(colors='#9CA3AF', labelsize=9)
        ax.spines[:].set_color('#374151')
        ax.grid(True, color='#374151', linewidth=0.5, linestyle='--')
        ax.yaxis.label.set_color('#D1D5DB')
        ax.xaxis.label.set_color('#D1D5DB')
        ax.title.set_color('#F9FAFB')

    # ── Subplot 1: pH vs tiempo ───────────────────────────────────────────────
    ax_ph.plot(ts, ph, color='#34D399', linewidth=2.0, label='pH medido', zorder=3)
    ax_ph.step(ts, sp_vals, color='#F87171', linewidth=1.5,
               linestyle='--', where='post', label='Setpoint', zorder=2)
    ax_ph.axhspan(sp_vals[0] - 0.3, sp_vals[0] + 0.3,
                  color='#F87171', alpha=0.08, label='±0.3 banda')

    if metricas['t_establecimiento'] is not None:
        ax_ph.axvline(metricas['t_establecimiento'], color='#FBBF24',
                      linestyle=':', linewidth=1.2, label=f"t_est={metricas['t_establecimiento']:.0f}s")

    ax_ph.set_ylabel('pH')
    ax_ph.set_title('Respuesta de pH — Control Fuzzy Mamdani')
    ax_ph.legend(loc='lower right', facecolor='#374151', edgecolor='none',
                 labelcolor='#D1D5DB', fontsize=8)

    # ── Subplot 2: Error ─────────────────────────────────────────────────────
    ax_err.plot(ts, err, color='#FB923C', linewidth=1.8, label='Error = SP − pH')
    ax_err.axhline(0,    color='#6B7280', linewidth=0.8)
    ax_err.axhline(0.2,  color='#6B7280', linewidth=0.8, linestyle=':',
                   label='Banda muerta ±0.2')
    ax_err.axhline(-0.2, color='#6B7280', linewidth=0.8, linestyle=':')
    ax_err.fill_between(ts, -0.2, 0.2, color='#6B7280', alpha=0.10)
    ax_err.set_ylabel('Error (pH)')
    ax_err.legend(loc='upper right', facecolor='#374151', edgecolor='none',
                  labelcolor='#D1D5DB', fontsize=8)

    # ── Subplot 3: t_pulso (acción de control) ────────────────────────────────
    bar_colors = [color_bar(a) for a in accion]
    ancho = min(4.0, (ts[-1] - ts[0]) / max(len(ts), 1) * 0.8) if len(ts) > 1 else 4.0
    ax_tp.bar(ts, tp, width=ancho, color=bar_colors, align='center')
    ax_tp.set_ylabel('t_pulso (s)')
    ax_tp.set_xlabel('Tiempo (s)')
    ax_tp.set_ylim(0, 11)
    leyenda = [
        Patch(color='#3B82F6', label='Pulso bomba'),
        Patch(color='#6B7280', label='Banda muerta'),
        Patch(color='#F59E0B', label='Inhibido (nivel)'),
    ]
    ax_tp.legend(handles=leyenda, loc='upper right', facecolor='#374151',
                 edgecolor='none', labelcolor='#D1D5DB', fontsize=8)

    # ── Caja de métricas ─────────────────────────────────────────────────────
    sp   = metricas['sp']
    txt  = (f"SP={sp:.2f}  pH₀={metricas['ph_inicial']:.3f}  "
            f"pH_f={metricas['ph_final']:.3f}\n"
            f"Sobreimpulso={metricas['sobreimpulso']:.3f} pH  "
            f"e_est={metricas['error_est']:.3f} pH  "
            f"Pulsos={metricas['n_pulsos']}  "
            f"t_bomba={metricas['t_bomba_total']:.0f}s  "
            f"Duración={metricas['duracion_total']:.0f}s")
    fig.text(0.5, 0.945, txt, ha='center', va='top', fontsize=8.5,
             color='#9CA3AF', fontfamily='monospace')

    # ── Guardar ───────────────────────────────────────────────────────────────
    out = path_csv.replace('.csv', '_respuesta.png')
    plt.savefig(out, dpi=150, facecolor='#111827')
    print(f"\nPNG guardado: {out}")

    plt.show()

# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else None
    recs, path = cargar_csv(path)
    ts   = tiempos_s(recs)
    met  = calcular_metricas(recs, ts)

    print("\n── Métricas de respuesta ──────────────────────")
    print(f"  Setpoint             : {met['sp']:.2f} pH")
    print(f"  pH inicial           : {met['ph_inicial']:.3f}")
    print(f"  pH final             : {met['ph_final']:.3f}")
    print(f"  Sobreimpulso         : {met['sobreimpulso']:.3f} pH")
    print(f"  Error estacionario   : {met['error_est']:+.3f} pH")
    if met['t_establecimiento'] is not None:
        print(f"  Tiempo establecim.   : {met['t_establecimiento']:.0f} s  "
              f"(banda ±0.3 pH)")
    else:
        print(f"  Tiempo establecim.   : no alcanzado")
    print(f"  Pulsos de bomba      : {met['n_pulsos']}")
    print(f"  Tiempo total bomba   : {met['t_bomba_total']:.0f} s")
    print(f"  Duración del ensayo  : {met['duracion_total']:.0f} s")
    print("───────────────────────────────────────────────\n")

    graficar(recs, ts, met, path)
