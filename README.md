# Interfaz HMI — Biorreactor Airlift

Sistema de interfaz hombre-máquina para el control y monitoreo de un biorreactor tipo airlift.
Desarrollado como trabajo terminal de la carrera de [CARRERA] en el [INSTITUTO/UNIDAD].

---

## Autores

| Rol | Nombre |
|---|---|
| Alumno | [NOMBRE ALUMNO 1] |
| Alumno | [NOMBRE ALUMNO 2] |
| Asesor | [NOMBRE ASESOR] |
| Co-asesor | [NOMBRE CO-ASESOR] (si aplica) |

**Institución:** Instituto Politécnico Nacional — UPIIZ / ENCB  
**Fecha:** 2026

---

## Tecnologías

- **Qt 6.5.3 / QML 2.15** — interfaz gráfica
- **C++17** — backend de control
- **Raspberry Pi 4** — hardware objetivo
- **Protocolo RS-485 Modbus RTU** — sensores pH y DO
- **I²C** — PCA9685 (actuadores PWM) y XM125 (nivel por radar)

---

## Variables y banderas importantes

### Backend C++ — GestorBiorreactor

#### Sensores (read-only desde QML)

| Variable | Tipo | Descripción |
|---|---|---|
| `sensorTem` | `double` | Temperatura del medio [°C] — fusión de ambos sensores RS-485 |
| `sensorPH` | `double` | pH del medio — RK500-12 (slave 0x03) |
| `sensorNivel` | `double` | Nivel del tanque [%] — XM125 radar I²C |
| `sensorLuz` | `double` | Intensidad de iluminación [%] |
| `sensorDO` | `double` | Oxígeno disuelto [mg/L] — RK500-04 (slave 0x0A) |

#### Setpoints (configurables por el usuario)

| Variable | Tipo | Rango | Descripción |
|---|---|---|---|
| `setpointTem` | `double` | 20–100 °C | Temperatura objetivo del proceso |
| `setpointPH` | `double` | 1–14 | pH objetivo del proceso |
| `setpointLuz` | `double` | 0–100 % | Intensidad de luz objetivo |

#### Nivel de llenado (constante de hardware)

| Constante | Archivo | Valor actual | Descripción |
|---|---|---|---|
| `NIVEL_LLENADO_PCT` | `raspberrypi_config.h` | 85.0 % | Nivel objetivo de llenado del tanque. **Calibrar en campo** midiendo la distancia real vacío/lleno. |
| `NIVEL_CONTACTO_PH_PCT` | `raspberrypi_config.h` | 20.0 % | Nivel mínimo para que el sensor de pH haga contacto con el líquido |

#### Estado del proceso

| Variable | Tipo | Descripción |
|---|---|---|
| `procesoActivo` | `bool` | `true` cuando el proceso biológico está en curso |
| `estadoPreparacion` | `int` | Estado de la máquina de estados de preparación (-1 a 6) |
| `progresoPreparacion` | `double` | Progreso de preparación (0.0 a 1.0) |
| `preparacionCompletada` | `bool` | `true` cuando la preparación llega al estado 6 |
| `alertaEscalacion` | `bool` | `true` cuando el acondicionamiento supera 120 s sin converger |

#### Alertas

| Variable | Tipo | Condición de activación |
|---|---|---|
| `alertaDivergenciaTemp` | `bool` | Diferencia > 1 °C entre los dos sensores de temperatura RS-485 |
| `alertaSerial` | `bool` | Sin datos RS-485 por más de 3 segundos |
| `alertaNivel` | `bool` | Sin respuesta del XM125 tras 5 intentos consecutivos |

#### Llenado óptimo (cálculo automático al iniciar preparación)

| Variable | Tipo | Descripción |
|---|---|---|
| `litrosAgua` | `double` | Litros de agua calculados para la mezcla |
| `mlSustanciaB` | `double` | Mililitros de sustancia B calculados |

#### Controladores habilitados

| Variable | Tipo | Descripción |
|---|---|---|
| `fuzzyPHHabilitado` | `bool` | Controlador Fuzzy de pH activo (activo en estados 3, 5 y durante proceso) |
| `histeresisNivelHabilitado` | `bool` | Controlador de histéresis de nivel activo |

#### Salidas de actuadores (para monitoreo)

| Variable | Tipo | Rango | Actuador |
|---|---|---|---|
| `salidaCalentador` | `double` | 0–100 % | PCA9685 canal 0 |
| `salidaBombaEtanol` | `double` | 0–100 % | PCA9685 canal 1 |
| `salidaBombaAgua` | `double` | 0–100 % | PCA9685 canal 2 |
| `salidaBombaNivel` | `bool` | ON/OFF | PCA9685 canal 5 |

---

### Variables QML — Main.qml (ApplicationWindow)

| Variable | Tipo | Descripción |
|---|---|---|
| `estadoActual` | `string` | Estado activo de la máquina de estados de navegación HMI |
| `procesoListoParaIniciar` | `bool` | `true` cuando el usuario confirma la introducción del organismo |
| `var_nombre_proyecto` | `string` | Nombre del proyecto activo |
| `var_nombre_experimento` | `string` | Nombre del experimento activo |
| `var_deseada_tiempo_total_horas` | `real` | Duración total programada del experimento [horas] |
| `idiomaActual` | `string` | Idioma seleccionado en PantallaAjustes |
| `unidadTemperatura` | `string` | `"C"` o `"F"` |

---

### Constantes de hardware — raspberrypi_config.h

| Constante | Valor actual | Descripción |
|---|---|---|
| `NIVEL_LLENADO_PCT` | 85.0 % | Nivel objetivo de llenado — **calibrar en campo** |
| `NIVEL_CONTACTO_PH_PCT` | 20.0 % | Nivel mínimo para contacto del sensor pH |
| `VOLUMEN_TANQUE_L` | 35.85 L | Volumen total del biorreactor airlift |
| `PH_SUSTANCIA_B` | 12.0 | pH de la sustancia básica — **calibrar con pHímetro** |
| `PH_AGUA_DEFAULT` | 7.0 | pH del agua de suministro |
| `CAUDAL_BOMBA_B_ML_S` | 5.0 mL/s | Caudal de bomba etanol al 100% — **calibrar en campo** |
| `DIST_VACIO_MM` | 400.0 mm | Distancia XM125 → superficie con tanque vacío — **calibrar** |
| `DIST_LLENO_MM` | 50.0 mm | Distancia XM125 → superficie con tanque lleno — **calibrar** |
| `SERIAL_BAUD` | 9600 | Baudrate RS-485 para sensores RK500-12 y RK500-04 |

---

### Protocolo RS-485 — Modbus RTU

| Sensor | Slave | Query (hex) | Respuesta |
|---|---|---|---|
| RK500-12 (pH) | 0x03 | `03 03 00 00 00 06 C4 2A` | 17 bytes: pH float + interno + temp float |
| RK500-04 (DO) | 0x0A | `0A 03 00 00 00 06 C4 B3` | 17 bytes: DO float + saturación + temp float |

**Calibración pH (sección 8.2 del manual RK500-12):**

| Punto | Comando hex |
|---|---|
| pH 4.00 | `03 06 00 55 00 04 99 FB` |
| pH 7.00 | `03 06 00 55 00 07 D9 FA` |
| pH 10.00 | `03 06 00 55 00 0A 18 3F` |

**Calibración DO — aire (sección 7.5 del manual RK500-04):**  
`0A 06 00 1A 00 01 68 B6`

---

## Compilación

```bash
# Modo simulación (Windows / desarrollo sin hardware)
cmake -B build -DSIMULACION=ON
cmake --build build

# Modo hardware real (Raspberry Pi 4)
cmake -B build -DSIMULACION=OFF
cmake --build build -j4
```

**Permisos necesarios en RPi:**
```bash
sudo usermod -aG i2c,dialout $USER
```

---

## Estructura del proyecto

```
Prototipo/
├── src/
│   ├── backend/       ← GestorBiorreactor, GestorAudio, TranslationManager
│   ├── controllers/   ← ControladorPID, ControladorFuzzy, ControladorHisteresis
│   └── drivers/       ← DriverPCA9685, DriverXM125, raspberrypi_config.h
├── *.qml              ← Pantallas y componentes QML
├── assets/            ← Imágenes PNG
├── audio/             ← Archivos WAV embebidos
├── translations/      ← Archivos .ts / .qm (6 idiomas)
├── tests/             ← Tests unitarios (QtTest)
├── herramientas/      ← simular_serial.py (Modbus RTU)
└── diagramas/         ← FSM y arquitectura (.drawio)
```

---

## Persistencia de datos

Todos los archivos se almacenan en `Documentos/Biorreactor/`:

| Archivo | Descripción |
|---|---|
| `biorreactor.ini` | Setpoints actuales (QSettings) |
| `datos_guardados.json` | Proyectos guardados (carrusel en pantalla de proyectos) |
| `registro_experimentos.json` | Historial de experimentos |
| `lecturas_Proy_Exp.json` | Lecturas de sensores por experimento |
| `Proy/Exp/sensores_*.csv` | Exportaciones CSV: Temp, pH, Nivel, Luz, DO |
