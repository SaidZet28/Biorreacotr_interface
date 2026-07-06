# Biorreactor HMI — Contexto del proyecto (TT2)

Interfaz Qt6 (QML + C++) para el control de un biorreactor sobre Raspberry Pi 4.
IPN UPIIZ / ENCB. Repo: https://github.com/SaidZet28/Biorreacotr_interface (rama `master`).
Idioma del código y comentarios: **español**.

> Escribe respuestas concisas y directas. Antes de trabajar, pregunta lo necesario
> si algo está ambiguo. Marca cada requisito de hardware/seguridad con cuidado.

---

## Hardware

- **Raspberry Pi 4**, bus **I2C-1** (`/dev/i2c-1`), compartido por XM125 y PCA9685.
- **XM125** radar 60 GHz @ `0x52` — sensor de **nivel** (distancia→nivel).
- **PCA9685** @ `0x40` — driver PWM 16 canales, 60 Hz. `GPIO17` = OE (**activo LOW**, vía pigpio).
- **GPIO27** = cruce por cero AC → burst firing del calentador.
- **RS-485** en `/dev/ttyAMA0` (9600 8N1, Modbus RTU): sensores pH (RK50012) y DO (RK50004).

### Canales PCA9685 (`src/drivers/driverpca9685.h`)
| Canal | Constante           | Uso |
|-------|---------------------|-----|
| 0     | `CH_CALENTADOR`     | Calentador (burst firing por cruce por cero) |
| 1     | `CH_BOMBA_ETANOL`   | Legacy — **no usar** |
| 2     | `CH_BURBUJEO`       | Bomba de aire / burbujeo |
| 3     | `CH_BOMBA_NEUT_A`   | Bomba llenado 1 **/** neutralizador A |
| 4     | `CH_BOMBA_NEUT_B`   | Bomba llenado 2 **/** neutralizador B |
| 5     | `CH_TIRA_LED`       | Tira LED |
| 8     | `CH_BOMBA_VAC1`     | Vaciado / drenado 1 |
| 10    | `CH_BOMBA_VAC2`     | Vaciado / drenado 2 |

**Importante:** CH3/CH4 tienen doble función — llenan el tanque (preparación) y dosifican
neutralizador (control pH). Van **en serie**: se encienden/apagan juntas. CH8/CH10 (drenado)
igual, juntas.

---

## Arquitectura del software

- **Frontend QML**: pantallas en la raíz y en `qml/screens`, `qml/components`, `qml/popups`.
- **Backend C++** (`src/`):
  - `backend/gestorbiorreactor.{h,cpp}` — **controlador central**. `QObject` expuesto a QML
    vía `Q_PROPERTY` (+ señales `NOTIFY`). Contiene todos los timers y lazos de control.
  - `backend/gestoraudio`, `backend/translationmanager`.
  - `controllers/` — `controladorpid`, `controladorfuzzy`, `controladorhisteresis`.
  - `drivers/` — `driverpca9685`, `driverxm125`, `raspberrypi_config.h` (constantes calibradas).
- `tests/` — `tst_pid`, `tst_fuzzy`, `tst_histeresis`, `tst_parseartrama` (Qt Test).
- `herramientas/` — scripts **Python de referencia** (caracterización/calibración). Son la
  fuente de verdad de la lógica que se porta a C++.

### Macros de compilación
- `Q_OS_LINUX` — habilita la ruta de hardware real (I2C, pigpio). En Windows/desktop no.
- `SIMULACION_ACTIVA` — cuando está definida, **sin hardware**: datos sintéticos, sin serial,
  sin XM125, sin PCA9685. Útil para desarrollo en Windows.

### Convenciones
- Setters de sensores comparan con epsilon y emiten `NOTIFY` solo si cambia.
- Escrituras a hardware siempre dentro de `#ifdef Q_OS_LINUX` / fuera de `SIMULACION_ACTIVA`.
- Patrón de lectura no bloqueante en timers (ej. XM125: tick par mide, tick impar lee).

---

## Lazos de control (`gestorbiorreactor.cpp`)

Timers principales:
- `m_timerControlLoop` (1 s) → `ejecutarControlLoop()`:
  - **Temperatura**: PID + feedforward. `K_PLANTA_TEMP = 0.6291 °C/%`, `T_amb` capturada al
    arrancar el proceso. FOPDT: K=0.6291, τ=23088 s, θ=204 s. Sintonía PI (Kp=30, ki=0.001299).
    Salida a `CH_CALENTADOR` vía burst firing (`onCrucePorCero`, GPIO27).
  - **pH (fuzzy SISO)**: pulso cada `Ts = 30 s`. Guardas: error>0, nivel<`m_nivelMaxPct`, y
    **no** drenando. Pulso enciende CH3/CH4 al 100%.
- `m_timerRS485` (500 ms) → alterna consulta pH/DO (Modbus RTU).
- `m_timerNivel` (500 ms) → `leerSensorNivel()` (XM125, patrón par/impar).
- `m_timerWatchdogSerial` (3 s) y `m_timerWatchdogI2C` (2 s) → alertas por pérdida de datos.
- `m_timerStaleness` (1 s), `m_timerPreparacion` (1 s, FSM de llenado), `m_timerSimulacion` (sim).

---

## Sensor de nivel — implementado (bloques 1 y 2, commit `1311398`)

### Lectura (`src/drivers/driverxm125.cpp`)
- I2C vía `I2C_RDWR` (no `I2C_SLAVE`, para no interferir en el bus compartido).
- `inicializar()` calibra (bloqueante ~1-2 s). Rango **50–1500 mm** (idéntico al Python).
- `leerResultado()`:
  1. Lee **todos** los picos: distancia `0x0011+j`, fuerza `0x001B+j` (**int32 signed**, millidB).
  2. Selecciona el pico de **mayor fuerza** (no el más cercano).
  3. **Filtro de confirmación** (estado en el driver): acepta directo si `|nuevo−aceptado| ≤ 30 mm`;
     si no, requiere **3 lecturas consecutivas** en la zona candidata para cambiar.
  4. Devuelve la distancia aceptada en mm; durante confirmaciones devuelve la última aceptada;
     `-1.0` solo en fallo de I2C (alimenta el watchdog).
- **No** se portó el filtro del soporte (~230 mm) del Python — decisión del usuario.

### Conversión y seguridad (`gestorbiorreactor.cpp`)
- `nivel% = (DIST_VACIO_MM − dist)/(DIST_VACIO_MM − DIST_LLENO_MM) × 100`, clamp 0–100.
- `evaluarSeguridadNivel()` — **protección de sobrellenado, histéresis en mm** (robusta porque
  `DIST_VACIO_MM` sigue sin calibrar). Recordar: **menor distancia = mayor nivel**; drenar sube la distancia.
  - `dist ≤ DIST_NIVEL_ALTO_MM (145)` → parar CH3/CH4, drenar CH8/CH10 ON, `alertaNivel=true`, bloquear pH.
  - drenar hasta `dist ≥ DIST_NIVEL_OBJETIVO_MM (216)` → drenado OFF, `alertaNivel=false` (auto).
  - El drenado **físico** requiere salidas habilitadas (OE LOW → proceso o preparación activos).
    La alarma visual funciona siempre.
- `salidaBombaNivel` reutilizado: `true` = drenado activo.
- La GUI ya muestra `sensorNivel` y `alertaNivel` (PantallaPrincipal, Pantalla7, PantallaProcesos,
  PantallaPreparacion).

### Constantes de nivel (`src/drivers/raspberrypi_config.h`)
- `DIST_VACIO_MM = 1150.0` — **PLACEHOLDER, sin calibrar**.
- `DIST_LLENO_MM = 145.0` — confirmado en físico (55 L = 100 %).
- `DIST_NIVEL_ALTO_MM = 145.0`, `DIST_NIVEL_OBJETIVO_MM = 216.0`.
- Otras: `VOLUMEN_TANQUE_L=55`, `TS_CONTROL_PH_S=30`, `T_PULSO_MAX_S=20`,
  `NIVEL_MAX_PCT=100`, `NIVEL_HIST_PCT=95`.

### Referencias Python (`herramientas/`)
- `escanear_nivel.py` — picos ordenados por fuerza.
- `prueba_visual_nivel.py` — filtro de confirmación (`MARGEN_CONFIRM=30`, `CONFIRMAR_N=3`).
- `caracterizar_nivel.py` — herramienta de calibración.

---

## Pendientes

- [ ] **Calibrar `DIST_VACIO_MM`** (medir tanque vacío; hoy 1150 es placeholder).
- [ ] Quitar código vestigial `m_histeresisNivel` / `m_histeresisNivelHabilitado`
      (ya no actúa sobre hardware tras el bloque 2).
- [ ] Probar en físico: selección por fuerza (ojo con el reflejo del soporte ~230 mm, ya que
      no hay filtro de soporte) y corte de drenado exacto a 216 mm.
- [ ] Opcional: alarma sonora vía `gestoraudio` al activarse el nivel alto.

---

## Build / test / git

- **Windows (dev):** Qt Creator, kit Qt 6.5.3 MinGW.
- **Raspberry Pi (target):** requiere Qt6, Qt6 SerialPort y **pigpio** (pigpiod corriendo).
- Tests unitarios en `tests/` (Qt Test).
- **Git:** aparecen `.git/index.lock` / `HEAD.lock` si el plugin de Git de **Qt Creator** (o
  VS Code / GitHub Desktop) corre a la vez que la terminal. Si pasa: cerrar esas apps y
  `Remove-Item .git\index.lock,.git\HEAD.lock -Force`. Commitear desde un solo lugar.
- No commitear artefactos de `build/` ni temporales de Office (`~$*.docx`).
