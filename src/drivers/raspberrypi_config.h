#pragma once

// ═══════════════════════════════════════════════════════════════════════════
//  Configuración de hardware — Raspberry Pi 4
//  Biorreactor HMI — IPN UPIIZ / ENCB
// ═══════════════════════════════════════════════════════════════════════════
//
//  MAPA DE PINES FÍSICOS (conector J8, 40 pines)
//  ┌──────────────────────────────────────────────┐
//  │  Pin 1  → 3.3 V (alimentación sensores)      │
//  │  Pin 2  → 5 V   (alimentación PCA9685)       │
//  │  Pin 3  → GPIO2 / SDA  ← I2C Bus 1 (datos)   │
//  │  Pin 5  → GPIO3 / SCL  ← I2C Bus 1 (reloj)   │
//  │  Pin 6  → GND          ← masa común          │
//  │  Pin 8  → GPIO14/ TXD  ← UART (RS-485 TX)    │
//  │  Pin 10 → GPIO15/ RXD  ← UART (RS-485 RX)    │
//  │                                              │
//  │  Pin 11 → GPIO17       ← OE PCA9685          │
//  │  Pin 13 → GPIO27       ← Cruce por cero AC   │
//  └──────────────────────────────────────────────┘
//
//  Para habilitar I2C: agregar  dtparam=i2c_arm=on  en /boot/firmware/config.txt
//  Para habilitar UART nativo: dtoverlay=disable-bt (libera ttyAMA0 del Bluetooth)
// ═══════════════════════════════════════════════════════════════════════════

// ── GPIO ─────────────────────────────────────────────────────────────────────
// Pin físico 11 → BCM 17: Output Enable del PCA9685 (activo LOW)
//   LOW  → PWM activos  |  HIGH → todos los canales deshabilitados (parada segura)
// Requiere pigpio. Salida digital.
static constexpr int GPIO_OE_PCA9685 = 17;

// Pin físico 13 → BCM 27: detección de cruce por cero AC del calentador
// Requiere pigpio (pigpiod corriendo). Entrada — interrupción en flanco de subida.
static constexpr int GPIO_ZERO_CROSS = 27;

// ── I2C ─────────────────────────────────────────────────────────────────────
// Bus I2C-1: GPIO2 (SDA, pin físico 3) + GPIO3 (SCL, pin físico 5)
static constexpr int RPI_I2C_BUS = 1;        // /dev/i2c-1

// ── PCA9685 — Driver PWM 16 canales ─────────────────────────────────────────
// Dirección I2C: 0x40 (AD0–AD5 = GND)
// Frecuencia PWM: 60 Hz (red eléctrica México) — sincronizada con cruce por cero
static constexpr int    PCA9685_I2C_BUS  = RPI_I2C_BUS;
static constexpr int    PCA9685_FREQ_HZ  = 60;

// Asignación de canales (debe coincidir con el cableado físico al PCA9685)
//  Canal 0 → Calentador (PWM analógico, 0–100 %)
//  Canal 1 → Bomba Neutralizador (PWM analógico, 0–100 %) — control pH SISO
//  Canal 2 → Bomba Agua          (PWM analógico, 0–100 %)
//  Canal 3 → Iluminación   (PWM analógico, 0–100 %)
//  Canal 4 → Airlift       (no conectado en esta versión)
//  Canal 5 → Bomba Nivel   (digital: ON / OFF)

// ── XM125 — Sensor radar de distancia (SparkFun Qwiic) ──────────────────────
// Dirección I2C: 0x52 (fija en hardware SparkFun)
// Bus: I2C-1 (comparte bus con PCA9685; direcciones distintas)
static constexpr int    XM125_I2C_BUS   = RPI_I2C_BUS;

// Geometría del biorreactor para conversión distancia→nivel (ajustar en campo)
//   DIST_VACIO: distancia sensor→superficie cuando el reactor está vacío (mm)
//   DIST_LLENO: distancia sensor→superficie cuando el reactor está lleno  (mm)
static constexpr double DIST_VACIO_MM   = 400.0;
static constexpr double DIST_LLENO_MM  =  50.0;

// ── RS-485 — Sensores pH (RK50012) y DO (RK50004) ───────────────────────────
// Puerto: GPIO14 (TXD, pin 8) + GPIO15 (RXD, pin 10) → /dev/ttyAMA0
// Requiere dtoverlay=disable-bt en /boot/firmware/config.txt (libera ttyAMA0 del BT)
static constexpr int    SERIAL_BAUD       = 9600;    // 8N1, sin control de flujo — Modbus RTU

// ── Llenado óptimo — Mezcla inicial por pH ───────────────────────────────────
// Volumen total operativo del biorreactor [L]
// MEDIDO: llenado a 55 L en 1409 s con BombaNivel (prueba 2026-06)
static constexpr double VOLUMEN_TANQUE_L       = 55.0;

// pH del agua de suministro (fuente A)
static constexpr double PH_AGUA_DEFAULT        = 7.0;

// pH de la sustancia B en el tanque de dosificación (neutralizador)
// CALIBRAR: medir con pHímetro la solución real y actualizar este valor
static constexpr double PH_SUSTANCIA_B         = 12.0;

// Caudal de Bomba Neutralizador al 100% PWM [mL/s]
// MEDIDO: 55 L llenados en 1409 s → Q = 55000/1409 ≈ 39 mL/s (prueba 2026-06)
// Usado para calcular t_pulso_max = 0.5% × 55000 mL / 39 mL/s ≈ 7 s
static constexpr double CAUDAL_BOMBA_B_ML_S    = 39.0;

// Tiempo máximo de pulso de la bomba neutralizador por ciclo [s]
// = (0.5% × VOLUMEN_TANQUE_L × 1000) / CAUDAL_BOMBA_B_ML_S = 275 / 39 ≈ 7 s
static constexpr double T_PULSO_MAX_S          = 7.0;

// Tiempo de muestreo del lazo de control pH [s]
// Derivado del tiempo de mezclado θm = 130 s → Ts = θm / 4.3 ≈ 30 s
static constexpr double TS_CONTROL_PH_S        = 30.0;

// Nivel mínimo para que el sensor de pH haga contacto con el líquido [%]
static constexpr double NIVEL_CONTACTO_PH_PCT  = 20.0;

// ── Histéresis de nivel ───────────────────────────────────────────────────────
// PENDIENTE DE VALIDACIÓN: valores sujetos a caracterización del sensor XM125.
//
// Lógica de estados:
//   nivel < NIVEL_MAX_PCT  → operación normal, control pH habilitado
//   nivel ≥ NIVEL_MAX_PCT  → deshabilitar pH, activar bomba de drenado
//   nivel ≤ NIVEL_HIST_PCT → desactivar drenado, rehabilitar pH
//
// Banda de histéresis: NIVEL_MAX_PCT − NIVEL_HIST_PCT = 10 %
// Propósito de la banda: tiempo suficiente para estabilización de la mezcla
// y para evitar ciclado continuo de la bomba de drenado.
static constexpr double NIVEL_MAX_PCT      = 95.0;   // umbral de corte superior [%]
static constexpr double NIVEL_HIST_PCT     = 85.0;   // umbral de reactivación  [%]

// Alias para compatibilidad — nivel objetivo de la FSM de preparación
static constexpr double NIVEL_LLENADO_PCT  = NIVEL_HIST_PCT;
