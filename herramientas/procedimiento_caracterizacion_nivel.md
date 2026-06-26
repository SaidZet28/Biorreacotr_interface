# Procedimiento: Caracterización del Sensor de Nivel XM125

**Proyecto:** Biorreactor TT2  
**Fecha:** 20 junio 2026  
**Sensor:** Acconeer XM125 (radar pulsado, I2C 0x52)  
**Script:** `herramientas/caracterizar_nivel.py`

---

## Objetivo

Obtener la curva de calibración que relaciona el **volumen de líquido** en el biorreactor con la **distancia reportada** por el XM125. Con esto se determinan los parámetros `DIST_VACIO` y `DIST_LLENO` que usa el sistema de control, y se verifica la linealidad de la respuesta.

---

## Material necesario

- Raspberry Pi con XM125 conectado vía I2C (bus 1, dirección 0x52)
- Biorreactor vacío (limpio y seco)
- Probeta graduada (resolución ≤ 10 ml)
- Agua destilada o la solución de cultivo (lo que se usará en operación real)
- Cronómetro o temporizador de 10 s
- Terminal SSH o teclado+pantalla en la RPi

---

## Montaje del sensor

1. Fija el sensor **centrado sobre la boca del reactor**, apuntando verticalmente hacia abajo.
2. Asegúrate de que no haya obstrucciones dentro del cono de detección (el XM125 tiene un ángulo de haz de ≈ ±15°).
3. Mide y anota la **altura de instalación** (distancia desde el sensor hasta el fondo vacío del reactor). Este valor debe quedar dentro del rango `RANGE_START`–`RANGE_END` configurado en el script (50–600 mm).
4. El sensor no debe tocar líquido ni vapor condensado directamente; si se esperan salpicaduras, cubre la cara del sensor con una membrana PTFE permeable al radar.

---

## Preparación del software

```bash
# En la RPi
sudo pip3 install smbus2 numpy
cd ~/TT2/Programas/Interfaz/Prototipo/herramientas
```

Opcional — verificar que el XM125 responde antes de correr la caracterización:

```bash
python3 prueba_total.py
# Comando: Nivel
# Debe imprimir distancia en mm sin errores
```

---

## Procedimiento paso a paso

### Paso 0 — Verificación inicial

1. Enciende la Raspberry Pi y espera el arranque completo.
2. Conecta el XM125 al bus I2C y verifica con `i2cdetect -y 1` que aparece en la dirección `0x52`.
3. El reactor debe estar **vacío y seco**.

### Paso 1 — Ejecutar el script

```bash
python3 caracterizar_nivel.py
```

El script calibra el sensor (≈ 2 s) y luego pide confirmar que el reactor está vacío. Presiona **Enter** para tomar la distancia de referencia `D_VACIO`.

> **Nota:** Si la lectura en vacío arroja un error o valor fuera de rango, ajusta `RANGE_END` en la parte superior del script para que sea ligeramente mayor que la altura real del reactor.

### Paso 2 — Adiciones de volumen

Repite el siguiente ciclo hasta llenar el reactor al nivel máximo de operación:

| Sub-paso | Acción |
|----------|--------|
| 2.1 | Mide con la probeta el volumen a agregar. Usa incrementos **iguales** (recomendado: 50 ml o 100 ml). |
| 2.2 | Vierte el agua lentamente sobre la pared del reactor para evitar espuma y burbujas. |
| 2.3 | Espera **10 segundos** para que el nivel se estabilice. |
| 2.4 | Ingresa el volumen en el script y presiona Enter. |
| 2.5 | Anota observaciones si las hay (espuma visible, salpicaduras, etc.). |

**Mínimo recomendado:** 8 puntos de medición (incluyendo vacío y lleno máximo).

### Paso 3 — Punto de reactor lleno

Al alcanzar el volumen máximo de operación, anota la distancia reportada como `D_LLENO`.

### Paso 4 — Terminar la prueba

Escribe `q` cuando el script pida el siguiente volumen. El script mostrará automáticamente:

- `DIST_VACIO` y `DIST_LLENO` en mm
- Regresión lineal (Volumen = a·Distancia + b) con coeficiente R²

---

## Criterios de aceptación

| Parámetro | Criterio |
|-----------|----------|
| R² de regresión lineal | ≥ 0.98 |
| Repetibilidad (mismo punto, 3 mediciones) | σ ≤ 2 mm |
| Rango sin lecturas erróneas (-1) | 100 % de los puntos |

Si R² < 0.98, el reactor tiene geometría no cilíndrica o hay reflexiones parásitas. En ese caso usar la tabla de calibración directamente (interpolación) en lugar de los parámetros lineales.

---

## Actualizar parámetros en el sistema

Una vez obtenidos `DIST_VACIO` y `DIST_LLENO`, actualízalos en dos lugares:

**1. `herramientas/prueba_total.py` (líneas ~43-44):**
```python
DIST_VACIO = XXX.X   # mm
DIST_LLENO =  XX.X   # mm
```

**2. `src/backend/gestorbiorreactor.cpp`** — busca las constantes equivalentes y actualízalas, o agrégalas si aún no existen.

---

## Salida del script

El CSV generado (`caracterizacion_nivel_YYYYMMDD_HHMMSS.csv`) contiene:

```
#, timestamp, evento, volumen_agregado_ml, volumen_acumulado_ml, distancia_mm, nivel_pct, notas
```

Úsalo para graficar la curva en Excel, Python o el software de tu preferencia y adjuntar al reporte de TT2.
