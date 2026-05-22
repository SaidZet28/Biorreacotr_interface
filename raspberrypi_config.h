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
//  │  Pin 3  → GPIO2 / SDA  ← I2C Bus 1 (datos)  │
//  │  Pin 5  → GPIO3 / SCL  ← I2C Bus 1 (reloj)  │
//  │  Pin 6  → GND          ← masa común          │
//  │  Pin 8  → GPIO14/ TXD  ← UART (RS-485 TX)   │  ← opcional si se usa
//  │  Pin 10 → GPIO15/ RXD  ← UART (RS-485 RX)   │    ttyAMA0 en lugar de
//  │                                               │    adaptador USB
//  └──────────────────────────────────────────────┘
//
//  Para habilitar I2C: agregar  dtparam=i2c_arm=on  en /boot/firmware/config.txt
//  Para habilitar UART nativo: dtoverlay=disable-bt (libera ttyAMA0 del Bluetooth)
// ═══════════════════════════════════════════════════════════════════════════

// ── I2C ─────────────────────────────────────────────────────────────────────
// Bus I2C-1: GPIO2 (SDA, pin físico 3) + GPIO3 (SCL, pin físico 5)
static constexpr int RPI_I2C_BUS = 1;        // /dev/i2c-1

// ── PCA9685 — Driver PWM 16 canales ─────────────────────────────────────────
// Dirección I2C: 0x40 (AD0–AD5 = GND)
// Frecuencia PWM: 50 Hz (período 20 ms, compatible con servos y SSR)
static constexpr int    PCA9685_I2C_BUS  = RPI_I2C_BUS;
static constexpr int    PCA9685_FREQ_HZ  = 50;

// Asignación de canales (debe coincidir con el cableado físico al PCA9685)
//  Canal 0 → Calentador (PWM analógico, 0–100 %)
//  Canal 1 → Bomba Etanol (PWM analógico, 0–100 %)
//  Canal 2 → Bomba Agua   (PWM analógico, 0–100 %)
//  Canal 3 → Recirculación (no conectado en esta versión)
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
// Adaptador: USB-RS485 → /dev/ttyUSB0  (detección automática en la app)
// Alternativa nativa: GPIO14/GPIO15 → /dev/ttyAMA0 (requiere dtoverlay=disable-bt)
static constexpr int SERIAL_BAUD = 115200;   // 8N1, sin control de flujo
