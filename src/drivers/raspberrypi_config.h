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

// Asignación de canales (debe coincidir con el cableado físico al PCA9685;
// fuente de verdad: DriverPCA9685 en src/drivers/driverpca9685.h)
//  Canal 0  → Manta calefactora 1 (burst firing por cruce por cero)
//  Canal 1  → Manta calefactora 2 (siempre sincronizada con CH0)
//  Canal 2  → Bomba de aire / burbujeo
//  Canal 3  → Bomba llenado 1 / neutralizador A (en serie con CH4)
//  Canal 4  → Bomba llenado 2 / neutralizador B (en serie con CH3)
//  Canal 5  → Tira LED (digital: ON / OFF)
//  Canal 8  → Bomba vaciado / drenado 1 (en serie con CH10)
//  Canal 10 → Bomba vaciado / drenado 2 (en serie con CH8)

// ── XM125 — Sensor radar de distancia (SparkFun Qwiic) ──────────────────────
// Dirección I2C: 0x52 (fija en hardware SparkFun)
// Bus: I2C-1 (comparte bus con PCA9685; direcciones distintas)
static constexpr int    XM125_I2C_BUS   = RPI_I2C_BUS;

// Geometría del biorreactor para conversión distancia→nivel (calibrado en campo 2026-06)
//   DIST_VACIO: distancia sensor→superficie cuando el reactor está vacío (mm)
//   DIST_LLENO: distancia sensor→superficie cuando el reactor está lleno a 55 L (mm)
// nivel% = (DIST_VACIO_MM − distMm) / (DIST_VACIO_MM − DIST_LLENO_MM) × 100
static constexpr double DIST_VACIO_MM   = 1150.0;  // tanque vacío
static constexpr double DIST_LLENO_MM  =  145.0;  // tanque lleno (55 L = 100 %)

// ── Protección de sobrellenado (histéresis en DISTANCIA, no en %) ────────────
// Se trabaja en mm porque DIST_VACIO_MM aún es placeholder; DIST_LLENO_MM sí
// está confirmado. Recordar: menor distancia = mayor nivel (sensor mira hacia
// abajo), así que drenar SUBE la distancia.
//   distancia ≤ DIST_NIVEL_ALTO_MM      → tanque lleno: alarma + parar llenado + drenar
//   distancia ≥ DIST_NIVEL_OBJETIVO_MM  → drenado suficiente: parar drenado + limpiar alarma
static constexpr double DIST_NIVEL_ALTO_MM     = 150.0;  // nivel máximo (banda de operación 150–216)
static constexpr double DIST_NIVEL_OBJETIVO_MM = 216.0;  // nivel seguro/objetivo tras drenar

// Extracción (vaciado por etapas, pantalla de extracción). Distancias del banco
// (CSV banco_nivel_20260708_033243, agua real por picos crudos + multipath, NO la moda buggy):
//   Vaciado 1 abre SOLO CH10 (EV superior) y drena hasta DIST_EV_SUPERIOR_MM.
//   Vaciado 2 abre SOLO CH8  (EV inferior) y drena hasta DIST_EV_INFERIOR_MM.
// Drenar AUMENTA la distancia; se para cuando dist ≥ referencia (confirmación CONFIRM_NIVEL_N).
static constexpr double DIST_EV_SUPERIOR_MM    = 640.0;  // corte del Vaciado 1 (CH10)
static constexpr double DIST_EV_INFERIOR_MM    = 870.0;  // corte del Vaciado 2 (CH8)
static constexpr int    VACIADO_TIMEOUT_S      = 240;    // tope de tiempo por etapa (seguridad)

// ── Flotador doble de nivel (PCF8574) ────────────────────────────────────────
// Reemplaza al radar XM125 en el control de nivel. Dos bolas en el mismo vástago:
// B (baja) marca el nivel de operación y A (alta) el tope. Se llena hasta B.
//   A=0 B=0 → Vacío · A=0 B=1 → Operativo · A=1 B=1 → Lleno · A=1 B=0 → Falla
// Por defecto el valor del pin ES el de la tabla (tal como se ve en los círculos de
// Mantenimiento). Si el cableado resulta al revés, en Mantenimiento → Sensor de nivel
// se puede intercambiar A/B e invertir la lectura sin recompilar (se guarda en el .ini).
// USAR_FLOTADOR = false regresa al radar (su código sigue en el proyecto).
static constexpr bool   USAR_FLOTADOR              = true;
static constexpr int    FLOTADOR_PIN_A             = 0;     // P0 → bola alta (A)
static constexpr int    FLOTADOR_PIN_B             = 1;     // P1 → bola baja (B)
static constexpr int    FLOTADOR_PERIODO_MS        = 200;   // lectura cada 200 ms
static constexpr int    FLOTADOR_CONFIRM_MS        = 2000;  // un estado nuevo debe sostenerse 2 s (burbujeo)
static constexpr int    FLOTADOR_EXTRA_LLENADO_S   = 10;    // seguir llenando tras activarse B
static constexpr int    FLOTADOR_EXTRA_DRENADO_S   = 5;     // seguir drenando tras liberarse A
static constexpr int    FLOTADOR_MAX_LLENADO_S     = 300;   // sin llegar a Operativo → paro + alerta de bombas
static constexpr int    FLOTADOR_MAX_DRENADO_S     = 120;   // A sin liberarse → paro + alerta de bombas
// Extracción manual (con el flotador no se sabe la altura): el operador cierra cada
// etapa; si no lo hace, la válvula se cierra sola tras este tope.
static constexpr int    FLOTADOR_VACIADO_MAX_S     = 600;

// Confirmación de umbral (anti salto espurio del radar): N lecturas sostenidas para cruzar
// cada umbral de la histéresis antes de arrancar/parar el drenado.
static constexpr int    CONFIRM_NIVEL_N        = 5;

// Lecturas consecutivas en objetivo para confirmar "nivel alcanzado" (anti lectura falsa).
static constexpr int    LLENADO_CONFIRM_OBJETIVO_N = 4;
// Llenado robusto de preparación:
//  - Si el tanque arranca vacío, el radar da basura por debajo de la última válvula. Se llena
//    "a ciegas" hasta que el radar lea establemente ≤ DIST_REF_CONFIABLE_MM (agua llegó a la
//    referencia confiable, ~647 mm de la calibración).
//  - Luego se llena guiado hasta el objetivo (216 mm), pero se RECHAZA "nivel alcanzado" si
//    llega demasiado pronto vs el caudal calibrado (filtro de plausibilidad): el tiempo del
//    tramo guiado debe ser ≥ FACTOR × (distancia por recorrer / caudal calibrado).
static constexpr double DIST_REF_CONFIABLE_MM      = 660.0; // radar confiable a partir de aquí
static constexpr double FACTOR_PLAUSIBLE_LLENADO   = 0.6;   // fracción del tiempo esperado
// La preparación lleva el nivel al OBJETIVO conocido (216 mm) ±margen, tanto si está muy
// vacío (llena) como si ya tiene algo (drena a 216). Luego el proceso opera en [150,216].
static constexpr double LLENADO_MARGEN_MM          = 8.0;   // banda muerta alrededor del objetivo

// Margen que se suma al ETA de calentamiento para el deadline de la alarma de
// escalación de temperatura (estado 3 de preparación). Ver ejecutarControlLoop/ETA.
static constexpr double MARGEN_ESCALACION_TEMP_S = 300.0;  // 5 min

// ── Seguridad ────────────────────────────────────────────────────────────────
// Límites del setpoint de temperatura configurable por el operador [°C]. Se aplican
// en el backend (setSetpointTem) para cubrir TODAS las rutas: teclado, edición de
// proyecto y carga de proyectos guardados.
static constexpr double TEMP_SETPOINT_MIN_C      = 20.0;   // mínimo permitido
static constexpr double TEMP_SETPOINT_MAX_C      = 60.0;   // máximo permitido
// Alerta de divergencia entre los 2 sensores de temperatura (sonda pH vs OD), con
// histéresis para no repicar: los sensores tienen un desfase base de ~1 °C, así que
// dispara solo si superan ON y se limpia al bajar de OFF (evita alarma fantasma).
static constexpr double DIVERGENCIA_TEMP_ON_C    = 2.0;    // dispara si |ΔT| > 2.0 °C
static constexpr double DIVERGENCIA_TEMP_OFF_C   = 1.5;    // limpia si |ΔT| < 1.5 °C
// Corte DURO de calentamiento si la temperatura supera el setpoint por este margen
// (cobertura de control hasta ~60 °C; no hay tope fijo). Independiente del PID.
static constexpr double DELTA_SOBRETEMP_C        = 5.0;    // °C sobre el setpoint
// Watchdog de bombas: si con bombas activas (llenado/drenado) la distancia de nivel
// no cambia al menos UMBRAL en TIMEOUT segundos → aviso de "verificar bombas".
static constexpr double UMBRAL_CAMBIO_NIVEL_MM   = 8.0;    // mm mínimos de cambio
static constexpr int    TIMEOUT_BOMBA_S          = 60;     // s sin cambio → alerta

// ── RS-485 — Sensores pH (RK50012) y DO (RK50004) ───────────────────────────
// Puerto: GPIO14 (TXD, pin 8) + GPIO15 (RXD, pin 10) → /dev/ttyAMA0
// Requiere dtoverlay=disable-bt en /boot/firmware/config.txt (libera ttyAMA0 del BT)
static constexpr int    SERIAL_BAUD       = 9600;    // 8N1, sin control de flujo — Modbus RTU

// ── Llenado con el medio de cultivo ──────────────────────────────────────────
// Un único compuesto sirve de medio; si el organismo lo acidifica se dosifica ese
// mismo medio por CH3/CH4 (lazo de pH). No hay cálculo de mezcla Sustancia B + agua.
// Volumen total operativo del biorreactor [L]
// MEDIDO: llenado a 55 L en 1409 s con BombaNivel (prueba 2026-06)
static constexpr double VOLUMEN_TANQUE_L       = 55.0;

// Tiempo máximo de pulso de la bomba de dosificación del medio por ciclo [s]
// CALIBRADO: tp_max = 20 s — salida fuzzy (0–10 s) × K=2; ΔpH ≈ 0.019/pulso @ 50 L (2026-06)
static constexpr double T_PULSO_MAX_S          = 20.0;

// Tiempo de muestreo del lazo de control pH [s]
// Derivado del tiempo de mezclado θm = 130 s (agitación magnética + flujo aire sin difusor, 2026-06)
// Ts = θm = 130 s redondeado a 30 s por ciclo de control (validado experimentalmente)
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
// Banda de histéresis: NIVEL_MAX_PCT − NIVEL_HIST_PCT = 5 %
// 100 % = 55 L (lleno); 95 % = 50 L (volumen operativo).
// Propósito de la banda: tiempo suficiente para estabilización de la mezcla
// y para evitar ciclado continuo de la bomba de drenado.
static constexpr double NIVEL_MAX_PCT      = 100.0;  // umbral de corte superior [%] — 55 L
static constexpr double NIVEL_HIST_PCT     =  95.0;  // umbral de reactivación  [%] — 50 L

// Alias para compatibilidad — nivel objetivo de la FSM de preparación
static constexpr double NIVEL_LLENADO_PCT  = NIVEL_HIST_PCT;
