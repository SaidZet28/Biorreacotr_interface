#include "gestorbiorreactor.h"
#include "raspberrypi_config.h"
#include <QSettings>
#include <QCoreApplication>
#include <QSerialPortInfo>
#include <QDebug>
#include <QtMath>
#include <QRandomGenerator>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QProcess>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#ifdef Q_OS_WIN
#include <windows.h>
#endif
#ifdef Q_OS_LINUX
#include <unistd.h>   // ::sync() tras exportar a USB
#endif
#if defined(Q_OS_LINUX) && !defined(SIMULACION_ACTIVA)
#include <pigpio.h>
#endif

// ── Constantes del seguidor de agua (portadas del banco de pruebas) ──────────
// Algoritmo interno del filtro predictivo: se ignora cualquier pico fuera de
// [NIVEL_MIN_MM, NIVEL_MAX_MM] (mata multipath y valores imposibles). Ver el
// detalle del filtro en HANDOFF-banco-nivel.md / memoria sensor-nivel-xm125.
static constexpr double SEG_NIVEL_MIN_MM   = 138.0;  // más lleno posible (menor distancia)
static constexpr double SEG_NIVEL_MAX_MM   = 1200.0; // más vacío posible (el vacío lee ~1128-1198)
static constexpr int    SEG_INIT_SAMPLES   = 8;      // frames (~4 s) para fijar el arranque más lejano
static constexpr double SEG_MAX_JUMP_MM    = 20.0;   // salto máx aceptado por lectura (vs predicción)
static constexpr double SEG_DIR_TOL_MM     = 5.0;    // tolerancia hacia atrás en movimiento (ruido)
static constexpr double SEG_MAX_COAST_MM   = 20.0;   // el coasting no se aleja más de esto del ancla
static constexpr int    SEG_STUCK_N        = 14;     // frames sin avanzar → escape (~7 s a 500 ms)
static constexpr double SEG_STUCK_PROG_MM  = 3.0;    // avance mínimo para considerar "sí se movió"
static constexpr double SEG_ESCAPE_MARGEN_MM  = 8.0; // el pico de escape debe ir claramente en la dir
static constexpr double SEG_ESCAPE_VENTANA_MM = 70.0;// sin saltar absurdamente lejos
static constexpr double SEG_FLOOR_LLENADO_MM_S = 0.35;// piso conservador de avance al llenar (−30 %: caudal real < previsto)
// Re-adquisición en estático — SOLO en la zona de control (cerca del nivel de operación).
// Cuando el nivel cambia lento con burbujeo (dosificación de pH) el filtro estático se clava;
// si un pico plausible cercano persiste, se adopta. NO aplica en zonas lejanas (multipath/fondo).
static constexpr double SEG_REACQ_ZONA_MM    = 300.0; // solo con ancla ≤ esto (banda de operación)
static constexpr double SEG_REACQ_VENTANA_MM = 70.0;  // salto máx permitido en la re-adquisición
static constexpr double SEG_REACQ_TOL_MM     = 6.0;   // tolerancia de consistencia del candidato
static constexpr int    SEG_REACQ_N          = 6;     // cuadros consistentes para adoptar (~3 s)

// Carpeta raíz donde se almacenan todos los datos de la aplicación.
// Linux (Raspberry Pi): ~/Documents/Biorreactor
// Windows:             Documentos/Biorreactor
static QString basePathStr()
{
    QString docs = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (docs.isEmpty())
        docs = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString dir = docs + "/Biorreactor";
    QDir().mkpath(dir);
    return dir;
}

static QString iniPath() {
    return basePathStr() + "/biorreactor.ini";
}

// Reemplaza caracteres inválidos en nombres de archivo/directorio.
static QString sanitizarNombre(const QString &s)
{
    QString r = s.trimmed();
    for (QChar c : {QChar('/'), QChar('\\'), QChar(':'), QChar('*'),
                    QChar('?'), QChar('"'), QChar('<'), QChar('>'), QChar('|')})
        r.replace(c, '_');
    return r.isEmpty() ? QStringLiteral("sin_nombre") : r;
}

// Umbral de staleness: si no hay datos en 5 s, la alerta se activa
static constexpr int UMBRAL_STALENESS_MS = 5000;

// ─────────────────────────────────────────────────────────────────────────────
// Constructor / Destructor
// ─────────────────────────────────────────────────────────────────────────────

GestorBiorreactor::GestorBiorreactor(QObject *parent) : QObject(parent)
{
    // Configurar controladores
    // PID Temperatura — identificado 2026-07 con prueba escalón (FOPDT)
    // Planta: K=0.6291 °C/%, τ=23088 s, θ=204 s
    // Sintonía IMC agresiva (λ=τ): Kp=30, Ti=23088 s, Td=0 (PI puro)
    // Conversión paralela: ki = Kp/Ti = 30/23088 = 0.001299, kd = 0
    m_pidTemp.configurar(30.0, 0.001299, 0.0, 1.0, 0.0, 100.0);
    m_histeresisNivel.configurar(5.0);

#ifndef SIMULACION_ACTIVA
    // Serial
    connect(&m_puerto, &QSerialPort::readyRead,
            this, &GestorBiorreactor::leerDatosSerial);

    // Timer RS-485: alterna consulta pH / DO cada 500 ms
    connect(&m_timerRS485, &QTimer::timeout,
            this, &GestorBiorreactor::consultarSensoresRS485);
    m_timerRS485.setInterval(500);
    m_timerRS485.start();
#endif

    // Timer loop de control: 1 s
    connect(&m_timerControlLoop, &QTimer::timeout,
            this, &GestorBiorreactor::ejecutarControlLoop);
    m_timerControlLoop.setInterval(1000);
    m_timerControlLoop.start();

#ifndef SIMULACION_ACTIVA
    // Watchdog serial: 3 s sin datos → alerta
    m_timerWatchdogSerial.setSingleShot(true);
    m_timerWatchdogSerial.setInterval(3000);
    connect(&m_timerWatchdogSerial, &QTimer::timeout,
            this, &GestorBiorreactor::onWatchdogSerialTimeout);

    // Watchdog I2C: 2 s sin datos nivel → alerta
    m_timerWatchdogI2C.setSingleShot(true);
    m_timerWatchdogI2C.setInterval(2000);
    connect(&m_timerWatchdogI2C, &QTimer::timeout,
            this, &GestorBiorreactor::onWatchdogI2CTimeout);
#endif

    // Timer staleness: revisa cada 1 s
    connect(&m_timerStaleness, &QTimer::timeout,
            this, &GestorBiorreactor::verificarStaleness);
    m_timerStaleness.setInterval(1000);
    m_timerStaleness.start();

    // Timer temperatura del gabinete (RTC DS3231): cada 5 s. Indicador, no crítico.
    connect(&m_timerTempHmi, &QTimer::timeout,
            this, &GestorBiorreactor::leerTempHmi);
    m_timerTempHmi.setInterval(5000);
    m_timerTempHmi.start();
    leerTempHmi();   // primera lectura inmediata

    // Timer preparación: se activa solo cuando el operador inicia la preparación
    connect(&m_timerPreparacion, &QTimer::timeout,
            this, &GestorBiorreactor::tickPreparacion);
    m_timerPreparacion.setInterval(1000);

#ifndef SIMULACION_ACTIVA
    // Timer nivel: lee XM125 cada 500 ms
    connect(&m_timerNivel, &QTimer::timeout,
            this, &GestorBiorreactor::leerSensorNivel);
    m_timerNivel.setInterval(500);
    m_timerNivel.start();

    // Inicializar hardware (solo funciona en Linux / RPi)
    m_pca9685.inicializar(1, 50);
    // El nivel usa el SEGUIDOR DE AGUA sobre picos crudos → el XM125 se inicializa en
    // modo caracterización (reset + 100-2000 mm), no en el modo de "pico más fuerte".
    m_xm125.inicializarCaracterizacion(1);

#ifdef Q_OS_LINUX
    // Cruce por cero — pigpio ya inicializado por DriverPCA9685::inicializar()
    gpioSetMode(GPIO_ZERO_CROSS, PI_INPUT);
    gpioSetPullUpDown(GPIO_ZERO_CROSS, PI_PUD_DOWN);
    if (gpioSetAlertFuncEx(GPIO_ZERO_CROSS, &GestorBiorreactor::callbackZC, this) != 0)
        qWarning() << "[ZC] No se pudo registrar callback en GPIO" << GPIO_ZERO_CROSS;
    else
        qDebug() << "[ZC] Burst firing activo en GPIO" << GPIO_ZERO_CROSS;
#endif

    buscarYConectar();
#else
    // Modo simulación: generar datos sintéticos cada segundo
    connect(&m_timerSimulacion, &QTimer::timeout,
            this, &GestorBiorreactor::tickSimulacion);
    m_timerSimulacion.setInterval(1000);
    m_timerSimulacion.start();
    qDebug() << "[SIM] Modo simulación activo — sin hardware real";
#endif

    cargarConfiguracion();
}

GestorBiorreactor::~GestorBiorreactor()
{
#ifndef SIMULACION_ACTIVA
#ifdef Q_OS_LINUX
    gpioSetAlertFuncEx(GPIO_ZERO_CROSS, nullptr, nullptr);  // desregistrar callback ZC
#endif
    m_pca9685.habilitarSalidas(false);   // OE HIGH — corte inmediato de todos los actuadores
    if (m_puerto.isOpen()) m_puerto.close();
#endif
    guardarConfiguracion();
}

// ─────────────────────────────────────────────────────────────────────────────
// Getters / Setters — Sensores
// ─────────────────────────────────────────────────────────────────────────────

double GestorBiorreactor::sensorTem()   const { return m_sensorTem;   }
double GestorBiorreactor::sensorPH()    const { return m_sensorPH;    }
double GestorBiorreactor::sensorNivel() const { return m_sensorNivel; }
double GestorBiorreactor::sensorLuz()   const { return m_sensorLuz;   }
double GestorBiorreactor::sensorDO()    const { return m_sensorDO;    }
double GestorBiorreactor::tempHmi()     const { return m_tempHmi;     }
double GestorBiorreactor::distanciaNivelMm() const { return m_distanciaNivelMm; }
bool   GestorBiorreactor::seguidorNivelHit() const { return m_seguidorHit; }

void GestorBiorreactor::setSensorTem(double v) {
    if (qAbs(m_sensorTem - v) < 1e-9) return;
    m_sensorTem = v; emit sensorTemChanged();
}
void GestorBiorreactor::setSensorPH(double v) {
    if (qAbs(m_sensorPH - v) < 1e-9) return;
    m_sensorPH = v; emit sensorPHChanged();
}
void GestorBiorreactor::setSensorNivel(double v) {
    if (qAbs(m_sensorNivel - v) < 1e-9) return;
    m_sensorNivel = v; emit sensorNivelChanged();
}
void GestorBiorreactor::setSensorLuz(double v) {
    if (qAbs(m_sensorLuz - v) < 1e-9) return;
    m_sensorLuz = v; emit sensorLuzChanged();
}
void GestorBiorreactor::setSensorDO(double v) {
    if (qAbs(m_sensorDO - v) < 1e-9) return;
    m_sensorDO = v; emit sensorDOChanged();
}
void GestorBiorreactor::setTempHmi(double v) {
    if (qAbs(m_tempHmi - v) < 0.05) return;   // el DS3231 tiene 0.25 °C de resolución
    m_tempHmi = v; emit tempHmiChanged();
}

// ─────────────────────────────────────────────────────────────────────────────
// Getters / Setters — Setpoints
// ─────────────────────────────────────────────────────────────────────────────

double GestorBiorreactor::setpointTem()   const { return m_setpointTem;   }
double GestorBiorreactor::setpointPH()    const { return m_setpointPH;    }
double GestorBiorreactor::nivelLlenadoPct() const { return NIVEL_LLENADO_PCT; }
double GestorBiorreactor::setpointLuz()   const { return m_setpointLuz;   }

void GestorBiorreactor::setSetpointTem(double v) {
    v = qBound(TEMP_SETPOINT_MIN_C, v, TEMP_SETPOINT_MAX_C);  // límite operativo del control
    if (qAbs(m_setpointTem - v) < 1e-9) return;
    m_setpointTem = v; emit setpointTemChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointPH(double v) {
    if (qAbs(m_setpointPH - v) < 1e-9) return;
    m_setpointPH = v; emit setpointPHChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointLuz(double v) {
    if (qAbs(m_setpointLuz - v) < 1e-9) return;
    m_setpointLuz = v; emit setpointLuzChanged(); guardarConfiguracion();
}

// Ajuste de la luz EN VIVO durante el proceso: fija el % y, si el proceso está activo (la tira
// LED ya encendida), escribe el PWM de inmediato para ver el cambio de brillo en el foco.
void GestorBiorreactor::setLuzProceso(double pct) {
    pct = std::clamp(pct, 0.0, 100.0);
    if (qAbs(m_setpointLuz - pct) > 1e-9) { m_setpointLuz = pct; emit setpointLuzChanged(); guardarConfiguracion(); }
#ifndef SIMULACION_ACTIVA
    if (m_procesoActivo)
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_TIRA_LED, m_setpointLuz);
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
// Alertas
// ─────────────────────────────────────────────────────────────────────────────

bool GestorBiorreactor::alertaDivergenciaTemp() const { return m_alertaDivergenciaTemp; }
bool GestorBiorreactor::alertaSerial()          const { return m_alertaSerial; }
bool GestorBiorreactor::alertaNivel()           const { return m_alertaNivel;  }

void GestorBiorreactor::setAlertaDivergenciaTemp(bool v) {
    if (m_alertaDivergenciaTemp == v) return;
    m_alertaDivergenciaTemp = v; emit alertaDivergenciaTempChanged();
    if (v) qWarning() << "[WD] Divergencia de temperatura:" << m_tempPH << "vs" << m_tempDO;
}
void GestorBiorreactor::setAlertaSerial(bool v) {
    if (m_alertaSerial == v) return;
    m_alertaSerial = v; emit alertaSerialChanged();
}
void GestorBiorreactor::setAlertaNivel(bool v) {
    if (m_alertaNivel == v) return;
    m_alertaNivel = v; emit alertaNivelChanged();
}
bool GestorBiorreactor::alertaSobreTemp() const { return m_alertaSobreTemp; }
bool GestorBiorreactor::alertaBombas()    const { return m_alertaBombas;    }
void GestorBiorreactor::setAlertaSobreTemp(bool v) {
    if (m_alertaSobreTemp == v) return;
    m_alertaSobreTemp = v; emit alertaSobreTempChanged();
    if (v) qWarning() << "[WD] SOBRE-TEMPERATURA: corte de calentamiento. T ="
                      << m_sensorTem << " SP =" << m_setpointTem;
}
void GestorBiorreactor::setAlertaBombas(bool v) {
    if (m_alertaBombas == v) return;
    m_alertaBombas = v; emit alertaBombasChanged();
    if (v) qWarning() << "[WD] Bombas activas sin cambio de nivel — verificar bombas.";
}
bool GestorBiorreactor::sensorSerialValido() const { return m_sensorSerialValido; }
bool GestorBiorreactor::sensorNivelValido()  const { return m_sensorNivelValido;  }
void GestorBiorreactor::setSensorSerialValido(bool v) {
    if (m_sensorSerialValido == v) return;
    m_sensorSerialValido = v; emit sensorSerialValidoChanged();
}
void GestorBiorreactor::setSensorNivelValido(bool v) {
    if (m_sensorNivelValido == v) return;
    m_sensorNivelValido = v; emit sensorNivelValidoChanged();
}

// ─────────────────────────────────────────────────────────────────────────────
// Proceso
// ─────────────────────────────────────────────────────────────────────────────

bool GestorBiorreactor::procesoActivo() const { return m_procesoActivo; }

void GestorBiorreactor::setProcesoActivo(bool activo)
{
    if (m_procesoActivo == activo) return;
    m_procesoActivo = activo;

    if (activo) {
        m_tAmbiente = m_sensorTem;           // Capturar T_amb para feedforward
        m_pca9685.habilitarSalidas(true);   // OE LOW — activar salidas PWM
        // Al activar el proceso completo, ambos controladores quedan habilitados
        if (!m_fuzzyPHHabilitado) {
            m_fuzzyPHHabilitado = true;
            emit fuzzyPHHabilitadoChanged();
        }
        if (!m_histeresisNivelHabilitado) {
            m_histeresisNivelHabilitado = true;
            emit histeresisNivelHabilitadoChanged();
        }
    } else {
        // Detener registro si estaba activo (evita pérdida silenciosa de datos)
        if (m_timerRegistro.isActive()) detenerRegistro();

        // Estado seguro: corte atómico de hardware, luego cero en todos los canales
        m_pca9685.habilitarSalidas(false);   // OE HIGH — todos los actuadores off en hardware
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO,   0.0);
        m_pca9685.escribirDigital   (DriverPCA9685::CH_TIRA_LED,  false);
        m_pca9685.escribirDigital   (DriverPCA9685::CH_CALENTADOR,   false);
        m_pca9685.escribirDigital   (DriverPCA9685::CH_CALENTADOR_2, false);
        m_pca9685.escribirDigital   (DriverPCA9685::CH_BOMBA_VAC1, false);   // drenado off
        m_pca9685.escribirDigital   (DriverPCA9685::CH_BOMBA_VAC2, false);
        m_drenandoNivel = false;
        m_rellenandoNivel = false;
        m_ticksNivelBajo = m_ticksNivelLleno = 0;
        m_accionLlenado = -99;   // sin llenado/drenado activo → seguidor de agua "estático"

        // Limpiar alertas de seguridad y el watchdog de bombas
        setAlertaSobreTemp(false);
        setAlertaBombas(false);
        m_distRefBomba = -1.0; m_ticksBombaSinCambio = 0;

        m_fuzzyPHHabilitado         = false;
        m_histeresisNivelHabilitado = false;
        m_zcDisparando              = false;
        m_zcContador                = 0;
        m_zcTotal                   = 0;
        emit fuzzyPHHabilitadoChanged();
        emit histeresisNivelHabilitadoChanged();

        m_pidTemp.reiniciar();
        m_histeresisNivel.reiniciar();
        m_salidaCalentador  = 0.0;
        m_salidaBombaEtanol = 0.0;
        m_salidaBombaAgua   = 0.0;
        m_salidaBombaNivel  = false;
        emit salidaCalentadorChanged();
        emit salidaBombaEtanolChanged();
        emit salidaBombaAguaChanged();
        emit salidaBombaNivelChanged();
    }
    emit procesoActivoChanged();
}

// ─────────────────────────────────────────────────────────────────────────────
// Salidas de control
// ─────────────────────────────────────────────────────────────────────────────

double GestorBiorreactor::salidaCalentador()         const { return m_salidaCalentador;    }
double GestorBiorreactor::etaCalentamientoSeg()      const { return m_etaCalentamientoSeg; }
double GestorBiorreactor::salidaBombaEtanol()        const { return m_salidaBombaEtanol;   }  // t_pulso [s]
double GestorBiorreactor::salidaBombaAgua()          const { return m_salidaBombaAgua;     }
bool   GestorBiorreactor::salidaBombaNivel()         const { return m_salidaBombaNivel;    }
bool   GestorBiorreactor::pulsoNeutralizadorActivo() const { return m_pulsoNeutralizador;  }

// ─────────────────────────────────────────────────────────────────────────────
// Persistencia
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::cargarConfiguracion()
{
    QSettings s(iniPath(), QSettings::IniFormat);
    s.beginGroup("Setpoints");
    m_setpointTem   = s.value("temperatura", 0.0).toDouble();
    m_setpointPH    = s.value("pH",          0.0).toDouble();
    m_setpointLuz   = s.value("luz",         0.0).toDouble();
    s.endGroup();
    s.beginGroup("CalibracionTanque");
    m_calibTLlenadoS    = s.value("tLlenadoS",    0.0).toDouble();
    m_calibTVaciadoS    = s.value("tVaciadoS",    0.0).toDouble();
    m_calibDVacioMm     = s.value("dVacioMm",     -1.0).toDouble();
    m_calibDOperacionMm = s.value("dOperacionMm", -1.0).toDouble();
    s.endGroup();
    emit setpointTemChanged();
    emit setpointPHChanged();
    emit setpointLuzChanged();
    emit calibracionTanqueChanged();
}

void GestorBiorreactor::guardarConfiguracion()
{
    QSettings s(iniPath(), QSettings::IniFormat);
    s.beginGroup("Setpoints");
    s.setValue("temperatura", m_setpointTem);
    s.setValue("pH",          m_setpointPH);
    s.setValue("luz",         m_setpointLuz);
    s.endGroup();
}

void GestorBiorreactor::resetearSetpoints()
{
    bool changed = false;
    if (qAbs(m_setpointTem)   > 1e-9) { m_setpointTem   = 0.0; emit setpointTemChanged();   changed = true; }
    if (qAbs(m_setpointPH)    > 1e-9) { m_setpointPH    = 0.0; emit setpointPHChanged();    changed = true; }
    if (qAbs(m_setpointLuz)   > 1e-9) { m_setpointLuz   = 0.0; emit setpointLuzChanged();   changed = true; }
    if (changed) guardarConfiguracion();
}

// ─────────────────────────────────────────────────────────────────────────────
// Persistencia JSON de modelos QML
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::guardarModelo(const QString &nombre, const QVariantList &datos)
{
    QJsonArray arr;
    for (const QVariant &v : datos)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    QFile f(basePathStr() + "/" + nombre + ".json");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

QVariantList GestorBiorreactor::cargarModelo(const QString &nombre)
{
    QFile f(basePathStr() + "/" + nombre + ".json");
    if (!f.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    QVariantList result;
    for (const QJsonValue &v : doc.array())
        result.append(v.toObject().toVariantMap());
    return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Modo simulación
// ─────────────────────────────────────────────────────────────────────────────

bool GestorBiorreactor::modoSimulacion() const
{
#ifdef SIMULACION_ACTIVA
    return true;
#else
    return false;
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
// Habilitación individual de controladores (usados internamente por preparación)
// ─────────────────────────────────────────────────────────────────────────────

bool GestorBiorreactor::fuzzyPHHabilitado()         const { return m_fuzzyPHHabilitado; }
bool GestorBiorreactor::histeresisNivelHabilitado() const { return m_histeresisNivelHabilitado; }

double GestorBiorreactor::nivelMaxPct()  const { return m_nivelMaxPct;  }
double GestorBiorreactor::nivelHistPct() const { return m_nivelHistPct; }

void GestorBiorreactor::setNivelMaxPct(double v)
{
    v = qBound(50.0, v, 100.0);
    if (qFuzzyCompare(m_nivelMaxPct, v)) return;
    m_nivelMaxPct = v;
    emit nivelMaxPctChanged();
}

void GestorBiorreactor::setNivelHistPct(double v)
{
    v = qBound(10.0, v, m_nivelMaxPct - 5.0);
    if (qFuzzyCompare(m_nivelHistPct, v)) return;
    m_nivelHistPct = v;
    emit nivelHistPctChanged();
}

int GestorBiorreactor::segundoProximoCiclo() const
{
    int restante = static_cast<int>(TS_CONTROL_PH_S) - m_contadorCicloPH;
    return qMax(0, restante);
}

void GestorBiorreactor::dispararPulsoManual(int segundos)
{
    // Inyecta un pulso inmediato ignorando el lazo fuzzy — solo para pruebas de actuador.
    int seg = qBound(1, segundos, static_cast<int>(T_PULSO_MAX_S));
    m_tPulsoRestante = seg;
    if (!m_pulsoNeutralizador) {
        m_pulsoNeutralizador = true;
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 100.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 100.0);
        emit pulsoNeutralizadorActivoChanged();
    }
}

void GestorBiorreactor::habilitarFuzzyPH(bool v)
{
    if (m_fuzzyPHHabilitado == v) return;
    m_fuzzyPHHabilitado = v;
    if (!v) {
        // Al deshabilitar el lazo pH solo se detiene la dosificación (CH3/CH4).
        // El burbujeo (CH2) NO se toca aquí: el mezclado debe seguir para que la
        // lectura de pH sea válida.
        m_salidaBombaEtanol = 0.0;
        m_salidaBombaAgua   = 0.0;
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
        emit salidaBombaEtanolChanged();
        emit salidaBombaAguaChanged();
    }
    emit fuzzyPHHabilitadoChanged();
}

void GestorBiorreactor::habilitarHisteresisNivel(bool v)
{
    if (m_histeresisNivelHabilitado == v) return;
    m_histeresisNivelHabilitado = v;
    if (!v) {
        // Solo baja el indicador de drenado. CH_TIRA_LED (foco) NO se toca aquí:
        // resabio del mapeo viejo donde CH5 era la bomba de nivel.
        m_salidaBombaNivel = false;
        emit salidaBombaNivelChanged();
    }
    emit histeresisNivelHabilitadoChanged();
}

// ─────────────────────────────────────────────────────────────────────────────
// Preparación del tanque — máquina de estados
// ─────────────────────────────────────────────────────────────────────────────

int     GestorBiorreactor::estadoPreparacion()     const { return m_estadoPreparacion; }
int     GestorBiorreactor::segFasePreparacion()    const { return m_ticksPrep; }
double  GestorBiorreactor::progresoPreparacion()   const { return m_progresoPreparacion; }
bool    GestorBiorreactor::preparacionCompletada() const { return m_preparacionCompletada; }
bool    GestorBiorreactor::alertaEscalacion()      const { return m_alertaEscalacion; }
bool    GestorBiorreactor::esperandoConfirmacionVacio() const { return m_esperandoConfirmacionVacio; }

QString GestorBiorreactor::textoTareaPreparacion() const
{
    switch (m_estadoPreparacion) {
    case 0:  return QCoreApplication::translate("Main", "Verificando sensores...");
    case 1:  return m_accionLlenado == -1
                 ? QCoreApplication::translate("Main", "Ajustando el nivel (drenando el exceso)...")
                 : QCoreApplication::translate("Main", "Llenando el tanque con el medio...");
    case 2:  return QCoreApplication::translate("Main", "Acondicionando pH y temperatura...");
    case 3:  return QCoreApplication::translate("Main", "Tanque listo — introduzca el organismo");
    default: return QCoreApplication::translate("Main", "Iniciando...");
    }
}

QString GestorBiorreactor::textoDetallePreparacion() const
{
    switch (m_estadoPreparacion) {
    case 0:
        if (!m_sensorSerialValido && !m_sensorNivelValido)
            return QCoreApplication::translate("Main", "⚠ Sin respuesta de los sensores (pH/DO/temperatura y nivel). Revise las conexiones.");
        if (!m_sensorSerialValido)
            return QCoreApplication::translate("Main", "⚠ Sin respuesta de los sensores RS-485 (pH/DO/temperatura). Revise la conexión.");
        if (!m_sensorNivelValido)
            return QCoreApplication::translate("Main", "⚠ Sin respuesta del sensor de nivel. Revise la conexión.");
        return QCoreApplication::translate("Main", "Comprobando que los sensores estén conectados y entregando lecturas.");
    case 1:
        return m_accionLlenado == -1
             ? QCoreApplication::translate("Main", "El nivel está por encima del objetivo: drenando el exceso hasta el nivel funcional. El burbujeo mantiene la mezcla homogénea.")
             : QCoreApplication::translate("Main", "Llevando el nivel al objetivo con el medio de cultivo. El burbujeo mantiene la mezcla homogénea.");
    case 2: {
        const QString tem = (m_sensorTem < m_setpointTem - 1.0)
            ? QCoreApplication::translate("Main", "Calentando hacia el objetivo. ")
            : QCoreApplication::translate("Main", "Temperatura en objetivo. ");
        QString ph;
        if (m_setpointPH < m_sensorPH)
            ph = QCoreApplication::translate("Main", "El pH objetivo es menor al actual: el control de pH se hará durante el proceso (el organismo acidifica el medio).");
        else if (qAbs(m_sensorPH - m_setpointPH) <= 0.5)
            ph = QCoreApplication::translate("Main", "pH en objetivo.");
        else
            ph = QCoreApplication::translate("Main", "Ajustando el pH hacia el objetivo (dosificando).");
        return tem + ph;
    }
    case 3:
        return QCoreApplication::translate("Main", "pH, temperatura y nivel estables. Luz encendida. Introduzca el organismo y confirme para continuar.");
    default: return QString();
    }
}

void GestorBiorreactor::setEstadoPreparacion(int estado)
{
    m_estadoPreparacion = estado;
    m_ticksPrep         = 0;
    m_contadorEstabPH   = 0;
    m_contadorEstabFino = 0;
    m_ticksNivelObjetivo = 0;
    m_accionLlenado      = -99;   // fuerza aplicar la acción en el primer tick del llenado
    m_radarConfiable     = false;
    m_ticksRadarConf     = 0;
    m_tGuiadoInicio      = 0;
    m_distInicioGuiado   = -1.0;

    // Configurar controladores/salidas según el estado (FSM de 4 fases:
    // 0=Verificación, 1=Llenado, 2=Acondicionamiento, 3=Listo)
    switch (estado) {
    case 1:  // Llenado
        if (!m_procesoActivo) {
            m_procesoActivo = true;
            m_tAmbiente = m_sensorTem;   // T_amb para feedforward/ETA
            emit procesoActivoChanged();
        }
        m_pca9685.habilitarSalidas(true);          // OE LOW — salidas activas
        habilitarFuzzyPH(false);                   // aún no se controla el pH durante el llenado
        habilitarHisteresisNivel(false);
        // Burbujeo APAGADO durante el llenado: la superficie agitada degrada el radar y el
        // seguidor de agua pierde el eco del agua. El mezclado arranca en Acondicionamiento
        // (fase 2), justo cuando empieza el control de pH. Solo se apaga del todo en el paro seguro.
        break;
    case 2:  // Acondicionamiento — control de temperatura y pH hasta estabilidad
        // Burbujeo/mezclado ON al COMPLETAR el llenado y durante todo el proceso: sin mezclado
        // la lectura de pH no es representativa. Solo se apaga en el paro seguro.
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO, 100.0);
        // Si el pH objetivo es MENOR al actual, se SALTA el control de pH en la
        // preparación: no se puede bajar por dosificación (solo sube). El pH se
        // controlará durante el proceso, cuando el organismo acidifique el medio.
        habilitarFuzzyPH(m_setpointPH >= m_sensorPH);
        habilitarHisteresisNivel(false);
        // Reiniciar el timer de escalación por ETA al entrar al acondicionamiento
        m_etaInicialSeg = -1.0; m_etaLockCnt = 0;
        m_etaLockPrevMin = -1;  m_segDesdeBloqueoEta = 0;
        break;
    case 3:  // Listo — encender la luz y esperar la confirmación del operador
        habilitarFuzzyPH(true);
        habilitarHisteresisNivel(true);
        // Luz por PWM según el setpoint (antes era digital ON = 100 % siempre). Editable en vivo
        // durante el proceso con setLuzProceso().
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_TIRA_LED, m_setpointLuz);
        setPreparacionCompletada(true);
        break;
    }

    // Progreso: 4 fases
    static const double hitos[] = { 0.0, 0.34, 0.67, 1.0 };
    setProgresoPreparacion(hitos[qBound(0, estado, 3)]);

    emit estadoPreparacionChanged();
}

void GestorBiorreactor::setProgresoPreparacion(double v)
{
    if (qAbs(m_progresoPreparacion - v) < 1e-9) return;
    m_progresoPreparacion = v;
    emit progresoPreparacionChanged();
}

void GestorBiorreactor::setPreparacionCompletada(bool v)
{
    if (m_preparacionCompletada == v) return;
    m_preparacionCompletada = v;
    emit preparacionCompletadaChanged();
}

void GestorBiorreactor::setAlertaEscalacion(bool v)
{
    if (m_alertaEscalacion == v) return;
    m_alertaEscalacion = v;
    emit alertaEscalacionChanged();
}


void GestorBiorreactor::iniciarPreparacion()
{
    // Bloquear solo si hay preparación activa en curso (estados 1-5).
    // Permite reiniciar desde -1 (nuevo experimento) o 6 (ciclo anterior completado).
    if (m_timerPreparacion.isActive() && m_estadoPreparacion > 0 && m_estadoPreparacion < 3) return;

    m_timerPreparacion.stop();

    m_estadoPreparacion     = 0;
    m_ticksPrep             = 0;
    m_contadorEstabPH       = 0;
    m_contadorEstabFino     = 0;
    m_preparacionCompletada = false;
    m_alertaEscalacion      = false;
    m_progresoPreparacion   = 0.0;
    if (m_esperandoConfirmacionVacio) {
        m_esperandoConfirmacionVacio = false;
        emit esperandoConfirmacionVacioChanged();
    }

    emit estadoPreparacionChanged();
    emit progresoPreparacionChanged();
    emit preparacionCompletadaChanged();
    emit alertaEscalacionChanged();

    m_timerPreparacion.start();
}

void GestorBiorreactor::cancelarPreparacion()
{
    m_timerPreparacion.stop();
    setProcesoActivo(false);   // apaga todos los actuadores y reinicia controladores
    m_estadoPreparacion     = -1;
    m_preparacionCompletada = false;
    m_alertaEscalacion      = false;
    m_progresoPreparacion   = 0.0;
    emit estadoPreparacionChanged();
    emit progresoPreparacionChanged();
    emit preparacionCompletadaChanged();
    emit alertaEscalacionChanged();
    emit preparacionCancelada();
}

void GestorBiorreactor::confirmarTanqueVacio(bool vacio)
{
    m_tanqueVacio = vacio;
    if (m_esperandoConfirmacionVacio) {
        m_esperandoConfirmacionVacio = false;
        emit esperandoConfirmacionVacioChanged();
    }
    setEstadoPreparacion(1);   // arranca el llenado (fase 1)
}

void GestorBiorreactor::pantallaReposo(bool dormir)
{
    // Modo reposo: solo apaga/enciende el backlight de la pantalla; NO toca actuadores
    // ni el proceso. El apagado total del equipo lo realiza el botón físico (corta la
    // energía de la RP y de las bombas a la vez, por lo que es seguro para los actuadores).
#ifdef Q_OS_LINUX
    // vcgencmd display_power 0 = pantalla off, 1 = on. Cubre HDMI/DSI en RPi.
    QProcess::startDetached(QStringLiteral("/usr/bin/vcgencmd"),
                            QStringList() << QStringLiteral("display_power")
                                          << (dormir ? QStringLiteral("0") : QStringLiteral("1")));
#else
    Q_UNUSED(dormir);
#endif
}

void GestorBiorreactor::detenerProceso()
{
    // Fin del cultivo (Detener/Finalizar): dejar el equipo en estado seguro.
    m_timerPreparacion.stop();
    setProcesoActivo(false);   // OE HIGH + canales usados a 0 + detiene registro + resetea PID
    if (m_estadoPreparacion != -1) {
        m_estadoPreparacion = -1;
        emit estadoPreparacionChanged();
    }
}

void GestorBiorreactor::apagarActuadores()
{
    // Red de seguridad de la pantalla de inicio: deja el equipo en estado seguro
    // pase lo que pase. Cubre el caso de un crash + reinicio automático donde los
    // registros del PCA9685 pudieron quedar con canales encendidos.
    m_timerPreparacion.stop();
    if (m_procesoActivo) setProcesoActivo(false);   // detiene control + registro
    for (int c = 0; c < 16; ++c) m_pca9685.escribirCanal(c, 0);
    m_pca9685.habilitarSalidas(false);              // OE HIGH — salidas deshabilitadas
    m_drenandoNivel = false;
}

int GestorBiorreactor::vaciadoEtapa() const { return m_vaciadoEtapa; }

void GestorBiorreactor::iniciarVaciado(int nivel)
{
    // Extracción AUTOMÁTICA por distancia. Abre UNA sola electroválvula y drena hasta la
    // referencia; el corte lo hace procesarVaciadoAuto() con cada lectura del nivel.
    //   nivel 1 → SOLO CH10 (EV superior) → drena hasta DIST_EV_SUPERIOR_MM (640)
    //   nivel 2 → SOLO CH8  (EV inferior) → drena hasta DIST_EV_INFERIOR_MM (870)
    m_pca9685.habilitarSalidas(true);
    if (nivel == 1) {
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);  // CH8 cerrada
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, true);   // CH10 abierta
    } else {  // nivel 2
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);  // CH10 cerrada
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, true);   // CH8 abierta
    }
    m_vaciadoEtapa        = nivel;
    m_ticksVaciadoConfirm = 0;
    m_vaciadoDeadline     = QDateTime::currentDateTime().addSecs(VACIADO_TIMEOUT_S);
    qDebug() << "[Vaciado] Etapa" << nivel << "iniciada (auto por distancia)";
    emit vaciadoEtapaChanged();
}

// Corte automático del vaciado por etapas: drenar aumenta la distancia; al llegar (y sostener
// CONFIRM_NIVEL_N lecturas) a la referencia de la etapa, cierra la válvula y avisa a la GUI.
void GestorBiorreactor::procesarVaciadoAuto()
{
    if (m_vaciadoEtapa == 0) return;

    // Tope de tiempo de seguridad: si el radar nunca llega, no dejar la bomba corriendo.
    if (QDateTime::currentDateTime() > m_vaciadoDeadline) {
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
        const int etapa = m_vaciadoEtapa;
        m_vaciadoEtapa = 0; m_ticksVaciadoConfirm = 0;
        qWarning() << "[Vaciado] Timeout etapa" << etapa;
        emit vaciadoEtapaChanged();
        emit vaciadoAbortado(QStringLiteral("Tiempo excedido en el vaciado (revisar bomba/válvula)."));
        return;
    }

    if (m_distanciaNivelMm < 0.0) { m_ticksVaciadoConfirm = 0; return; }  // sin lectura válida

    const double ref = (m_vaciadoEtapa == 1) ? DIST_EV_SUPERIOR_MM : DIST_EV_INFERIOR_MM;
    if (m_distanciaNivelMm >= ref) {          // drenó hasta la altura de la EV
        if (++m_ticksVaciadoConfirm >= CONFIRM_NIVEL_N) {
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
            const int etapa = m_vaciadoEtapa;
            m_vaciadoEtapa = 0; m_ticksVaciadoConfirm = 0;
            qDebug() << "[Vaciado] Etapa" << etapa << "completa: dist=" << m_distanciaNivelMm << "mm (ref" << ref << ")";
            emit vaciadoEtapaChanged();
            emit vaciadoEtapaCompletada(etapa);
        }
    } else {
        m_ticksVaciadoConfirm = 0;
    }
}

void GestorBiorreactor::detenerVaciado()
{
    // Paro de emergencia: cierra ambas válvulas y cancela la etapa en curso. Deja OE como esté
    // (permite encadenar). El apagado seguro total lo hace finalizarVaciado.
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
    if (m_vaciadoEtapa != 0) { m_vaciadoEtapa = 0; m_ticksVaciadoConfirm = 0; emit vaciadoEtapaChanged(); }
    qDebug() << "[Vaciado] Detenido (manual)";
}

void GestorBiorreactor::finalizarVaciado()
{
    // Fin de la extracción (o salida de la pantalla): válvulas cerradas + OE HIGH.
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
    m_pca9685.habilitarSalidas(false);   // OE HIGH — estado seguro
    if (m_vaciadoEtapa != 0) { m_vaciadoEtapa = 0; m_ticksVaciadoConfirm = 0; emit vaciadoEtapaChanged(); }
    qDebug() << "[Vaciado] Finalizado — salidas deshabilitadas";
}

// ── Vaciado manual (apartado en Opciones) — 3 toggles independientes ──────────
bool GestorBiorreactor::vaciadoManualInf() const { return m_vaciadoManualInf; }
bool GestorBiorreactor::vaciadoManualSup() const { return m_vaciadoManualSup; }
bool GestorBiorreactor::vaciadoManualAux() const { return m_vaciadoManualAux; }

void GestorBiorreactor::toggleVaciadoManual(int cual)
{
    // Solo con el equipo en reposo: si hay proceso/preparación o caracterización activa,
    // se ignora (evita pelear con los lazos de control o drenar un cultivo en curso).
    if (m_procesoActivo || m_caractActiva) {
        qWarning() << "[VaciadoManual] Ignorado: equipo no está en reposo";
        return;
    }

    bool *estado = nullptr; int canal = -1;
    switch (cual) {
    case 0: estado = &m_vaciadoManualInf; canal = DriverPCA9685::CH_BOMBA_VAC1; break;  // EV inferior
    case 1: estado = &m_vaciadoManualSup; canal = DriverPCA9685::CH_BOMBA_VAC2; break;  // EV superior
    case 2: estado = &m_vaciadoManualAux; canal = DriverPCA9685::CH_BOMBA_VAC3; break;  // EV vaciado 3
    default: return;
    }

    *estado = !*estado;
    if (*estado) m_pca9685.habilitarSalidas(true);   // OE LOW al primer encendido
    m_pca9685.escribirDigital(canal, *estado);
    qDebug() << "[VaciadoManual] canal" << canal << (*estado ? "ON" : "OFF");
    emit vaciadoManualChanged();
}

void GestorBiorreactor::cerrarVaciadoManual()
{
    // Salida del apartado: cierra las 3 electroválvulas + OE HIGH (estado seguro).
    m_vaciadoManualInf = m_vaciadoManualSup = m_vaciadoManualAux = false;
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC3, false);
    m_pca9685.habilitarSalidas(false);   // OE HIGH — estado seguro
    qDebug() << "[VaciadoManual] Cerrado — válvulas y salidas deshabilitadas";
    emit vaciadoManualChanged();
}

// ═════════════════════════════════════════════════════════════════════════════
//  MANTENIMIENTO — prueba manual de actuadores y del flotador de nivel (PCF8574)
//  Cada actuador se apaga solo al terminar su tiempo. Al salir: todo en 0 + OE HIGH.
// ═════════════════════════════════════════════════════════════════════════════
namespace {
struct ActuadorMant { int chA; int chB; int tiempoS; };
// chB = -1 si el actuador usa un solo canal. El calentador tiene menos tiempo
// para no calentar la manta en seco.
constexpr ActuadorMant MANT_ACTUADORES[] = {
    { DriverPCA9685::CH_BOMBA_NEUT_A, DriverPCA9685::CH_BOMBA_NEUT_B, 10 },  // 0 bombas llenado (serie)
    { DriverPCA9685::CH_BURBUJEO,     -1,                             10 },  // 1 burbujeo
    { DriverPCA9685::CH_BOMBA_VAC1,   -1,                             10 },  // 2 EV1
    { DriverPCA9685::CH_BOMBA_VAC2,   -1,                             10 },  // 3 EV2
    { DriverPCA9685::CH_BOMBA_VAC3,   -1,                             10 },  // 4 EV3
    { DriverPCA9685::CH_TIRA_LED,     -1,                             10 },  // 5 tira LED
    { DriverPCA9685::CH_CALENTADOR,   DriverPCA9685::CH_CALENTADOR_2,  5 },  // 6 calentador (siempre juntos)
};
}

bool GestorBiorreactor::mantActiva() const { return m_mantActiva; }
int  GestorBiorreactor::flotadorDireccion() const { return m_flotadorDireccion; }
int  GestorBiorreactor::flotadorPuerto()    const { return m_flotadorPuerto; }

QVariantList GestorBiorreactor::mantRestantes() const
{
    QVariantList l;
    for (int i = 0; i < MANT_NUM_ACTUADORES; ++i) l.append(m_mantRestantes[i]);
    return l;
}

void GestorBiorreactor::entrarMantenimiento()
{
    if (m_mantActiva) return;
    if (m_procesoActivo || m_caractActiva) {
        qWarning() << "[Mant] No disponible: equipo no está en reposo";
        return;
    }

    // Pausar el lazo de nivel del XM125 para que el drenado de seguridad no actúe
    // mientras se prueban bombas y válvulas a mano.
    m_timerNivel.stop();

    mantApagarTodo();
    flotadorBuscar();

    m_mantActiva = true;
    emit mantActivaChanged();

    connect(&m_timerMantenimiento, &QTimer::timeout,
            this, &GestorBiorreactor::tickMantenimiento, Qt::UniqueConnection);
    m_mantSubTick = 0;
    m_timerMantenimiento.setInterval(200);
    m_timerMantenimiento.start();
    qDebug() << "[Mant] Modo mantenimiento ACTIVO";
}

void GestorBiorreactor::salirMantenimiento()
{
    if (!m_mantActiva) return;
    m_timerMantenimiento.stop();
    mantApagarTodo();
    m_pcf8574.cerrar();

    // Reanudar el lazo de nivel de producción desde cero.
    resyncNivel();
#ifndef SIMULACION_ACTIVA
    m_timerNivel.start();
#endif

    m_mantActiva = false;
    emit mantActivaChanged();
    qDebug() << "[Mant] Modo mantenimiento FINALIZADO — salidas en estado seguro";
}

void GestorBiorreactor::mantToggleActuador(int id)
{
    if (!m_mantActiva || m_procesoActivo) return;
    if (id < 0 || id >= MANT_NUM_ACTUADORES) return;
    const bool encender = (m_mantRestantes[id] == 0);
    m_mantRestantes[id] = encender ? MANT_ACTUADORES[id].tiempoS : 0;
    mantEscribirActuador(id, encender);
    emit mantActuadoresChanged();
}

void GestorBiorreactor::mantEscribirActuador(int id, bool encender)
{
    const ActuadorMant &a = MANT_ACTUADORES[id];
    if (encender) m_pca9685.habilitarSalidas(true);   // OE LOW al encender
    m_pca9685.escribirDigital(a.chA, encender);
    if (a.chB >= 0) m_pca9685.escribirDigital(a.chB, encender);
    qDebug() << "[Mant] actuador" << id << (encender ? "ON" : "OFF");

    // Si ya no queda ninguno encendido → OE HIGH (estado seguro)
    bool alguno = false;
    for (int i = 0; i < MANT_NUM_ACTUADORES; ++i) alguno = alguno || m_mantRestantes[i] > 0;
    if (!alguno) m_pca9685.habilitarSalidas(false);
}

void GestorBiorreactor::mantApagarTodo()
{
    for (int i = 0; i < MANT_NUM_ACTUADORES; ++i) {
        m_mantRestantes[i] = 0;
        m_pca9685.escribirDigital(MANT_ACTUADORES[i].chA, false);
        if (MANT_ACTUADORES[i].chB >= 0)
            m_pca9685.escribirDigital(MANT_ACTUADORES[i].chB, false);
    }
    m_pca9685.habilitarSalidas(false);   // OE HIGH
    emit mantActuadoresChanged();
}

void GestorBiorreactor::flotadorBuscar()
{
    m_pcf8574.cerrar();
    m_flotadorDireccion = -1;
    m_flotadorPuerto    = -1;
    // PCF8574 usa 0x20-0x27 y PCF8574A 0x38-0x3F (según A0-A2). Nada más del bus
    // vive ahí (PCA9685 0x40, XM125 0x52, RTC 0x68), así que es seguro escanear.
    QVector<int> direcciones;
    for (int d = 0x20; d <= 0x27; ++d) direcciones.append(d);
    for (int d = 0x38; d <= 0x3F; ++d) direcciones.append(d);
    for (int d : direcciones) {
        if (m_pcf8574.inicializar(1, d)) { m_flotadorDireccion = d; break; }
    }
    if (m_flotadorDireccion < 0) qWarning() << "[Mant] PCF8574 no encontrado en el bus I2C-1";
    emit flotadorChanged();
}

void GestorBiorreactor::tickMantenimiento()
{
    // Lectura del flotador (cada 200 ms)
    if (m_pcf8574.conectado()) {
        bool ok = false;
        const int v = m_pcf8574.leerPuerto(ok);
        const int nuevo = ok ? v : -1;
        if (nuevo != m_flotadorPuerto) { m_flotadorPuerto = nuevo; emit flotadorChanged(); }
    }

    // Descuento de tiempos (cada 1 s) y apagado automático
    if (++m_mantSubTick < 5) return;
    m_mantSubTick = 0;
    bool cambio = false;
    for (int i = 0; i < MANT_NUM_ACTUADORES; ++i) {
        if (m_mantRestantes[i] <= 0) continue;
        cambio = true;
        if (--m_mantRestantes[i] == 0) mantEscribirActuador(i, false);
    }
    if (cambio) emit mantActuadoresChanged();
}

// ── Calibración del tanque ────────────────────────────────────────────────────
double GestorBiorreactor::calibTLlenadoS()    const { return m_calibTLlenadoS; }
double GestorBiorreactor::calibTVaciadoS()     const { return m_calibTVaciadoS; }
double GestorBiorreactor::calibDVacioMm()      const { return m_calibDVacioMm; }
double GestorBiorreactor::calibDOperacionMm()  const { return m_calibDOperacionMm; }

void GestorBiorreactor::calibAccion(int accion)
{
    // Control manual de actuadores durante la calibración. 0=parar, 1=llenar, 2=drenar.
    if (accion == 0) {   // parar seguro
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
        m_pca9685.habilitarSalidas(false);   // OE HIGH
        return;
    }
    m_pca9685.habilitarSalidas(true);        // OE LOW — salidas activas
    const bool llenar = (accion == 1);
    const bool drenar = (accion == 2);
    m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, llenar ? 100.0 : 0.0);
    m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, llenar ? 100.0 : 0.0);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, drenar);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, drenar);
}

void GestorBiorreactor::guardarCalibracionTanque(double tLlenadoS, double tVaciadoS,
                                                 double dVacioMm, double dOperacionMm)
{
    m_calibTLlenadoS    = tLlenadoS;
    m_calibTVaciadoS    = tVaciadoS;
    m_calibDVacioMm     = dVacioMm;
    m_calibDOperacionMm = dOperacionMm;
    QSettings s(iniPath(), QSettings::IniFormat);
    s.beginGroup("CalibracionTanque");
    s.setValue("tLlenadoS",    m_calibTLlenadoS);
    s.setValue("tVaciadoS",    m_calibTVaciadoS);
    s.setValue("dVacioMm",     m_calibDVacioMm);
    s.setValue("dOperacionMm", m_calibDOperacionMm);
    s.endGroup();
    emit calibracionTanqueChanged();
    qDebug() << "[Calib] Tanque guardado — llenado" << tLlenadoS << "s, vaciado"
             << tVaciadoS << "s, dVacio" << dVacioMm << "dOper" << dOperacionMm;
}

// ═════════════════════════════════════════════════════════════════════════════
//  CARACTERIZACIÓN DEL SENSOR DE NIVEL — herramienta de diagnóstico
//  Reinicia el XM125 igual que xm125_distance.py (reset + 100-2000 mm), muestra
//  TODOS los picos crudos (sin filtro) y permite accionar actuadores a mano +
//  grabar un CSV con la línea de tiempo (muestras + eventos de actuador).
// ═════════════════════════════════════════════════════════════════════════════
bool         GestorBiorreactor::caractActiva()      const { return m_caractActiva; }
QVariantList GestorBiorreactor::caractPicos()        const { return m_caractPicos; }
double       GestorBiorreactor::caractTempSensor()  const { return m_caractTempSensor; }
bool         GestorBiorreactor::caractNearEdge()    const { return m_caractNearEdge; }
int          GestorBiorreactor::caractNumMuestras() const { return m_caractMuestras.size(); }
bool         GestorBiorreactor::caractEV1()         const { return m_caractEV1; }
bool         GestorBiorreactor::caractEV2()         const { return m_caractEV2; }
bool         GestorBiorreactor::caractBurbujeo()    const { return m_caractBurbujeo; }
bool         GestorBiorreactor::caractBombas()      const { return m_caractBombas; }
bool         GestorBiorreactor::caractGrabando()    const { return m_caractGrabando; }

void GestorBiorreactor::entrarCaracterizacion()
{
    if (m_caractActiva) return;
    if (m_procesoActivo) {
        qWarning() << "[Caract] No disponible con el proceso activo";
        return;
    }

    // Pausar el lazo de nivel de producción para no competir en el bus I2C
    m_timerNivel.stop();

    // Reinicializar el sensor igual que xm125_distance.py (reset + 100-2000 mm).
    // Cerrar antes para no filtrar el fd de producción.
    m_xm125.cerrar();
    if (!m_xm125.inicializarCaracterizacion(1))
        qWarning() << "[Caract] XM125 no inicializó en modo caracterización";

    // Habilitar salidas (OE LOW) y dejar los 5 canales usados en 0
    m_pca9685.habilitarSalidas(true);
    m_caractEV1 = m_caractEV2 = m_caractBurbujeo = m_caractBombas = false;
    m_pca9685.escribirDigital(DriverPCA9685::CH_BURBUJEO,     false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_NEUT_A, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_NEUT_B, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1,   false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2,   false);
    emit caractActuadoresChanged();

    m_caractActiva = true;
    emit caractActivaChanged();

    connect(&m_timerCaracterizacion, &QTimer::timeout,
            this, &GestorBiorreactor::tickCaracterizacion, Qt::UniqueConnection);
    m_timerCaracterizacion.setInterval(500);
    m_timerCaracterizacion.start();
    qDebug() << "[Caract] Modo caracterización ACTIVO";
}

void GestorBiorreactor::salirCaracterizacion()
{
    if (!m_caractActiva) return;
    m_timerCaracterizacion.stop();

    if (m_caractGrabando) caractDetenerGrabacion();   // cierra CSV si estaba grabando

    // Apagar los 5 canales usados + OE HIGH (red de seguridad)
    m_pca9685.escribirDigital(DriverPCA9685::CH_BURBUJEO,     false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_NEUT_A, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_NEUT_B, false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1,   false);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2,   false);
    m_pca9685.habilitarSalidas(false);   // OE HIGH — estado seguro
    m_caractEV1 = m_caractEV2 = m_caractBurbujeo = m_caractBombas = false;
    emit caractActuadoresChanged();

    // Restaurar el sensor a la config de producción — que ahora ES la de caracterización
    // (reset + 100-2000 mm), porque el nivel de producción usa el seguidor sobre picos crudos.
    m_xm125.cerrar();
    m_xm125.inicializarCaracterizacion(1);

    // Reanudar el lazo de nivel de producción y re-armar el seguidor de agua desde cero.
    resyncNivel();
    m_timerNivel.start();

    m_caractActiva = false;
    m_caractPicos.clear();
    emit caractPicosChanged();
    emit caractActivaChanged();
    qDebug() << "[Caract] Modo caracterización FINALIZADO — salidas en estado seguro";
}

void GestorBiorreactor::caractToggleEV1()
{
    if (!m_caractActiva) return;
    m_caractEV1 = !m_caractEV1;
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, m_caractEV1);
    emit caractActuadoresChanged();
    if (m_caractGrabando) caractRegistrarEvento("EV1", m_caractEV1);
}

void GestorBiorreactor::caractToggleEV2()
{
    if (!m_caractActiva) return;
    m_caractEV2 = !m_caractEV2;
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, m_caractEV2);
    emit caractActuadoresChanged();
    if (m_caractGrabando) caractRegistrarEvento("EV2", m_caractEV2);
}

void GestorBiorreactor::caractToggleBurbujeo()
{
    if (!m_caractActiva) return;
    m_caractBurbujeo = !m_caractBurbujeo;
    m_pca9685.escribirDigital(DriverPCA9685::CH_BURBUJEO, m_caractBurbujeo);
    emit caractActuadoresChanged();
    if (m_caractGrabando) caractRegistrarEvento("BURBUJEO", m_caractBurbujeo);
}

void GestorBiorreactor::caractToggleBombas()
{
    if (!m_caractActiva) return;
    m_caractBombas = !m_caractBombas;   // CH3 y CH4 van en serie: juntas
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_NEUT_A, m_caractBombas);
    m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_NEUT_B, m_caractBombas);
    emit caractActuadoresChanged();
    if (m_caractGrabando) caractRegistrarEvento("BOMBAS", m_caractBombas);
}

void GestorBiorreactor::tickCaracterizacion()
{
    if (!m_xm125.conectado()) return;
    QThread::msleep(200);  // deja respirar al event loop

    bool ok = false; double tempC = 0.0; uint32_t resultado = 0;
    QVector<DriverXM125::PicoCrudo> picos = m_xm125.medirPicosCrudos(ok, tempC, resultado);
    if (!ok) return;   // ciclo sin medición válida (ocupado o error)

    m_caractTempSensor = tempC;
    m_caractNearEdge   = (resultado & 0x00000100u);   // near_start_edge (bit 8)

    QVariantList lista;
    for (const DriverXM125::PicoCrudo &p : picos) {
        QVariantMap m;
        m["dist"] = p.distMm;
        m["raw"]  = static_cast<double>(p.fuerzaRaw);            // valor crudo del registro
        m["q16"]  = p.fuerzaRaw / 65536.0;                       // interpretación Q16 (script viejo)
        m["db"]   = static_cast<int32_t>(p.fuerzaRaw) / 1000.0;  // interpretación dB con signo
        lista.append(m);
    }
    m_caractPicos = lista;
    emit caractPicosChanged();

    if (m_caractGrabando) {
        QVariantMap muestra;
        muestra["tipo"]      = "M";
        muestra["hora"]      = QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm:ss.zzz");
        muestra["t_ms"]      = m_caractInicioGrab.msecsTo(QDateTime::currentDateTime());
        muestra["near_edge"] = m_caractNearEdge;
        muestra["temp_c"]    = tempC;
        muestra["EV1"]       = m_caractEV1;
        muestra["EV2"]       = m_caractEV2;
        muestra["burbujeo"]  = m_caractBurbujeo;
        muestra["bombas"]    = m_caractBombas;
        muestra["picos"]     = lista;
        m_caractMuestras.append(muestra);
    }
}

void GestorBiorreactor::caractRegistrarEvento(const QString &actuador, bool estado)
{
    QVariantMap ev;
    ev["tipo"]     = "E";
    ev["hora"]     = QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm:ss.zzz");
    ev["t_ms"]     = m_caractInicioGrab.msecsTo(QDateTime::currentDateTime());
    ev["actuador"] = actuador;
    ev["estado"]   = estado ? "ON" : "OFF";
    ev["EV1"]      = m_caractEV1;
    ev["EV2"]      = m_caractEV2;
    ev["burbujeo"] = m_caractBurbujeo;
    ev["bombas"]   = m_caractBombas;
    m_caractMuestras.append(ev);
}

void GestorBiorreactor::caractIniciarGrabacion()
{
    if (!m_caractActiva || m_caractGrabando) return;
    m_caractMuestras.clear();
    m_caractInicioGrab = QDateTime::currentDateTime();
    m_caractGrabando = true;
    emit caractGrabandoChanged();
    // Estado inicial de los actuadores como eventos en t=0 (baseline)
    caractRegistrarEvento("EV1",      m_caractEV1);
    caractRegistrarEvento("EV2",      m_caractEV2);
    caractRegistrarEvento("BURBUJEO", m_caractBurbujeo);
    caractRegistrarEvento("BOMBAS",   m_caractBombas);
    qDebug() << "[Caract] Grabación INICIADA";
}

QString GestorBiorreactor::caractDetenerGrabacion()
{
    if (!m_caractGrabando) return QString();
    m_caractGrabando = false;
    QString ruta = caractEscribirCSV();
    emit caractGrabandoChanged();
    qDebug() << "[Caract] Grabación DETENIDA —" << m_caractMuestras.size() << "filas →" << ruta;
    return ruta;
}

QString GestorBiorreactor::caractEscribirCSV()
{
    if (m_caractMuestras.isEmpty()) {
        qWarning() << "[Caract] Sin muestras para exportar";
        return QString();
    }

    const QString carpeta = basePathStr() + "/Caracterizacion";
    QDir().mkpath(carpeta);
    const QString nombre = "caract_nivel_" +
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".csv";
    QFile f(carpeta + "/" + nombre);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "[Caract] No se pudo crear" << f.fileName();
        return QString();
    }

    QTextStream out(&f);
    out.setEncoding(QStringConverter::Utf8);
    out << "# Caracterización XM125 (modo diagnóstico: reset + rango 100-2000 mm, SIN filtro)\n"
        << "# Inicio: " << m_caractInicioGrab.toString("dd/MM/yyyy HH:mm:ss") << "\n"
        << "# Formato largo: una fila por pico (tipo M); filas tipo E = eventos de actuador.\n"
        << "# fuerza_q16 = raw/65536 (interpretación del script viejo); "
           "fuerza_db = int32(raw)/1000 (interpretación dB con signo).\n"
        << "# Actuadores: 1=ON, 0=OFF.  EV1=CH8, EV2=CH10, burbujeo=CH2, bombas=CH3+CH4.\n#\n"
        << "tipo,hora,t_ms,pico,dist_mm,fuerza_raw,fuerza_q16,fuerza_db,"
           "near_edge,temp_c,EV1,EV2,burbujeo,bombas,actuador,evento\n";

    auto b01 = [](const QVariant &v) -> QString { return v.toBool() ? "1" : "0"; };

    for (const QVariantMap &m : m_caractMuestras) {
        const QString estados = b01(m["EV1"]) + "," + b01(m["EV2"]) + ","
                              + b01(m["burbujeo"]) + "," + b01(m["bombas"]);
        if (m["tipo"].toString() == "E") {
            // Evento de actuador: columnas de sensor vacías
            out << "E," << m["hora"].toString() << "," << m["t_ms"].toLongLong()
                << ",,,,,,,," << estados << ","
                << m["actuador"].toString() << "," << m["estado"].toString() << "\n";
        } else {
            const QString cab = "M," + m["hora"].toString() + ","
                              + QString::number(m["t_ms"].toLongLong());
            const QString cola = "," + QString(m["near_edge"].toBool() ? "1" : "0") + ","
                               + QString::number(m["temp_c"].toDouble(), 'f', 1) + ","
                               + estados + ",,";   // actuador/evento vacíos
            const QVariantList picos = m["picos"].toList();
            if (picos.isEmpty()) {
                out << cab << ",,,,," << cola << "\n";   // muestra sin objeto detectado
            } else {
                for (int j = 0; j < picos.size(); ++j) {
                    const QVariantMap p = picos[j].toMap();
                    out << cab << "," << j << ","
                        << QString::number(p["dist"].toDouble(), 'f', 0) << ","
                        << QString::number(p["raw"].toDouble(),  'f', 0) << ","
                        << QString::number(p["q16"].toDouble(),  'f', 4) << ","
                        << QString::number(p["db"].toDouble(),   'f', 3)
                        << cola << "\n";
                }
            }
        }
    }

    out.flush();
    f.flush();
    f.close();
#ifdef Q_OS_LINUX
    ::sync();
#endif
    return f.fileName();
}

void GestorBiorreactor::apagarSistema()
{
    // Paro seguro y apagado limpio de la Raspberry.
    // NOTA: ya no está cableado a la UI (el botón de inicio ahora hace pantallaReposo()).
    // Se conserva por si se necesita un apagado limpio opcional en el futuro.
    m_timerPreparacion.stop();
    setProcesoActivo(false);   // apaga controladores + pone canales usados a 0 + OE HIGH
    guardarConfiguracion();
#ifdef Q_OS_LINUX
    // Cero explícito de los 16 canales del PCA9685 (defensivo: aunque OE flote en LOW
    // al cortar energía, las salidas quedan apagadas) y OE HIGH.
    for (int c = 0; c < 16; ++c) m_pca9685.escribirCanal(c, 0);
    m_pca9685.habilitarSalidas(false);
    // La app corre como root → puede apagar el sistema directamente.
    QProcess::startDetached(QStringLiteral("/sbin/shutdown"),
                            QStringList() << QStringLiteral("-h") << QStringLiteral("now"));
#endif
}

void GestorBiorreactor::continuarDesdeEscalacion()
{
    setAlertaEscalacion(false);
    m_ticksPrep = 0;   // reinicia contador para dar otro intervalo completo
    m_segDesdeBloqueoEta = 0;   // otra ventana completa de ETA_inicial + margen
}

void GestorBiorreactor::tickPreparacion()
{
    m_ticksPrep++;

    switch (m_estadoPreparacion) {

    case 0: {
        // Verificación: los sensores deben estar conectados y entregando lecturas.
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 2) setEstadoPreparacion(1);
#else
        // Sensores OK → NO avanza solo: primero pregunta si el tanque está vacío. La GUI
        // muestra el popup mientras m_esperandoConfirmacionVacio; el avance a llenado lo
        // hace confirmarTanqueVacio() con la respuesta del operador.
        if (m_sensorSerialValido && m_sensorNivelValido && !m_drenandoNivel) {
            if (!m_esperandoConfirmacionVacio) {
                m_esperandoConfirmacionVacio = true;
                emit esperandoConfirmacionVacioChanged();
            }
        }
#endif
        break;
    }

    case 1: {
        // Llenado ROBUSTO hasta la banda de operación (objetivo 216 mm). Menor dist = más lleno.
        //  A) Si arranca vacío: llena a CIEGAS hasta que el radar sea confiable (≤660 mm),
        //     porque por debajo de la última válvula el radar da basura.
        //  B) Luego llena/drena guiado hasta el objetivo, RECHAZANDO "nivel alcanzado" si
        //     llega demasiado pronto vs el caudal calibrado (filtro de plausibilidad).
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 5) setEstadoPreparacion(2);
#else
        auto aplicarAccion = [&](int accion) {
            if (accion == m_accionLlenado) return;
            m_accionLlenado = accion;
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, accion == 1 ? 100.0 : 0.0);
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, accion == 1 ? 100.0 : 0.0);
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, accion == -1);
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, accion == -1);
            m_salidaBombaAgua = (accion == 1) ? 100.0 : 0.0;
            emit salidaBombaAguaChanged();
        };

        // ── A) Llenado ciego hasta radar confiable (solo si el tanque arrancó vacío) ──
        if (m_tanqueVacio && !m_radarConfiable) {
            aplicarAccion(1);   // llenar
            if (m_distanciaNivelMm >= 0.0 && m_distanciaNivelMm <= DIST_REF_CONFIABLE_MM) {
                if (++m_ticksRadarConf >= CONFIRM_NIVEL_N) {   // agua llegó a la referencia
                    m_radarConfiable   = true;
                    m_ticksRadarConf   = 0;
                    m_tGuiadoInicio    = m_ticksPrep;
                    m_distInicioGuiado = m_distanciaNivelMm;
                }
            } else {
                m_ticksRadarConf = 0;
            }
            break;   // sigue en ciego hasta confirmar
        }
        // Arranque no-vacío: el radar ya es confiable; marcar el inicio del tramo guiado.
        if (!m_radarConfiable) {
            m_radarConfiable   = true;
            m_tGuiadoInicio    = m_ticksPrep;
            m_distInicioGuiado = (m_distanciaNivelMm >= 0.0) ? m_distanciaNivelMm : DIST_REF_CONFIABLE_MM;
        }

        // ── B) Tramo guiado: llevar el nivel al OBJETIVO conocido (216 mm ±margen) ──
        // Llena si está más vacío que el objetivo; DRENA si ya tiene algo (más lleno que el
        // objetivo). Así siempre arranca el cultivo desde el mismo nivel conocido (216).
        int accion;
        if (m_distanciaNivelMm < 0.0)                                              accion = 1;   // sin lectura → llenar
        else if (m_distanciaNivelMm > DIST_NIVEL_OBJETIVO_MM + LLENADO_MARGEN_MM)  accion = 1;   // muy vacío → llenar
        else if (m_distanciaNivelMm < DIST_NIVEL_OBJETIVO_MM - LLENADO_MARGEN_MM)  accion = -1;  // ya algo lleno → drenar a 216
        else                                                                      accion = 0;   // en 216 ±margen
        aplicarAccion(accion);

        if (accion == 0) {
            // Filtro de plausibilidad por tiempo/caudal: no aceptar el objetivo si el radar
            // "llegó" demasiado pronto (salto espurio). Caudal desde la calibración.
            double caudal = 0.8;   // mm/s por defecto
            if (m_calibTLlenadoS > 1.0 && m_calibDVacioMm > m_calibDOperacionMm)
                caudal = (m_calibDVacioMm - m_calibDOperacionMm) / m_calibTLlenadoS;
            const double esperado = qMax(0.0, (m_distInicioGuiado - DIST_NIVEL_OBJETIVO_MM)
                                              / qMax(caudal, 0.05));
            const double transcurrido = m_ticksPrep - m_tGuiadoInicio;
            if (transcurrido >= FACTOR_PLAUSIBLE_LLENADO * esperado) {
                if (++m_ticksNivelObjetivo >= LLENADO_CONFIRM_OBJETIVO_N) setEstadoPreparacion(2);
            } else {
                m_ticksNivelObjetivo = 0;   // lectura prematura → ignorar y seguir llenando
            }
        } else {
            m_ticksNivelObjetivo = 0;
        }
#endif
        break;
    }

    case 2: {  // Acondicionamiento: temperatura y pH hasta estabilidad (30 s en margen)
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 10) setEstadoPreparacion(3);
#else
        // Temperatura: el equipo SOLO calienta → objetivo alcanzado si está a ≤1°C.
        const bool temOk = qAbs(m_sensorTem - m_setpointTem) <= 1.0;
        // pH: si el setpoint es MENOR al actual no se puede bajar por control → se
        // espera a que el organismo acidifique (pH "listo" para la preparación). Si el
        // setpoint es mayor/igual, el lazo difuso dosifica para subirlo hasta el margen.
        const bool phListo = (m_setpointPH < m_sensorPH)
                           ? true
                           : (qAbs(m_sensorPH - m_setpointPH) <= 0.5);
        if (phListo && temOk) {
            if (++m_contadorEstabFino >= 30) setEstadoPreparacion(3);   // estable 30 s → listo
        } else {
            m_contadorEstabFino = 0;
            // Alarma de escalación con deadline = ETA_inicial + margen (temperatura).
            // ETA_inicial se fija cuando el ETA se estabiliza (10 lecturas en el mismo
            // minuto); si no es calculable ("-") se espera.
            if (m_etaInicialSeg < 0.0) {
                const double eta = m_etaCalentamientoSeg;
                if (eta < 0.0) {
                    m_etaLockCnt = 0; m_etaLockPrevMin = -1;
                } else {
                    const int mn = static_cast<int>(qRound(eta / 60.0));
                    if (mn == m_etaLockPrevMin) {
                        if (++m_etaLockCnt >= 10) { m_etaInicialSeg = eta; m_segDesdeBloqueoEta = 0; }
                    } else {
                        m_etaLockPrevMin = mn; m_etaLockCnt = 1;
                    }
                }
            } else if (++m_segDesdeBloqueoEta >= (m_etaInicialSeg + MARGEN_ESCALACION_TEMP_S)
                       && !m_alertaEscalacion) {
                setAlertaEscalacion(true);
            }
        }
#endif
        break;
    }

    case 3:  // Listo — esperando que el operador confirme la introducción del organismo
        break;
    }

    // Refrescar los textos dinámicos (sensores en verificación, dirección de pH, etc.)
    emit estadoPreparacionChanged();
}

void GestorBiorreactor::tickSimulacion()
{
#ifdef SIMULACION_ACTIVA
    m_tickSim += 1.0;

    auto noise = [](double amp) -> double {
        return amp * (QRandomGenerator::global()->generateDouble() * 2.0 - 1.0);
    };

    setSensorTem  (24.5  + 1.5  * qSin(m_tickSim * 0.05) + noise(0.10));
    setSensorPH   ( 7.2  + 0.3  * qCos(m_tickSim * 0.03) + noise(0.02));
    setSensorNivel(85.0  + 5.0  * qSin(m_tickSim * 0.02) + noise(0.50));
    // Luz: oscila alrededor del setpoint si está configurado, si no alrededor de 60 %
    setSensorLuz  ((m_setpointLuz > 1e-9 ? m_setpointLuz : 60.0) + 4.0 * qCos(m_tickSim * 0.04) + noise(0.30));
    setSensorDO   ( 8.2  + 0.5  * qCos(m_tickSim * 0.07) + noise(0.05));

    // Evitar alertas de staleness — marcar como datos recibidos ahora
    m_ultimaLecturaRS485 = QDateTime::currentDateTime();
    m_ultimaLecturaI2C   = QDateTime::currentDateTime();
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
// Puerto serial
// ─────────────────────────────────────────────────────────────────────────────

bool GestorBiorreactor::puertoConectado() const { return m_puerto.isOpen(); }
QString GestorBiorreactor::nombrePuerto() const { return m_puerto.portName(); }

bool GestorBiorreactor::buscarYConectar(const QString &nombreForzado)
{
#ifdef SIMULACION_ACTIVA
    Q_UNUSED(nombreForzado)
    return false;
#endif
    if (m_puerto.isOpen()) m_puerto.close();

    QString portName = nombreForzado;
    if (portName.isEmpty()) {
        // 1ª pasada: puerto UART nativo (GPIO14/GPIO15 → ttyAMA0)
        for (const QSerialPortInfo &info : QSerialPortInfo::availablePorts()) {
            if (info.portName() == "ttyAMA0") {
                portName = info.portName();
                break;
            }
        }
        // 2ª pasada: adaptador USB-RS485 como alternativa
        if (portName.isEmpty()) {
            for (const QSerialPortInfo &info : QSerialPortInfo::availablePorts()) {
                if (info.portName().startsWith("ttyUSB")) {
                    portName = info.portName();
                    break;
                }
            }
        }
        // 3ª pasada: cualquier puerto no-Bluetooth
        if (portName.isEmpty()) {
            for (const QSerialPortInfo &info : QSerialPortInfo::availablePorts()) {
                if (!info.portName().contains("Bluetooth", Qt::CaseInsensitive)) {
                    portName = info.portName();
                    break;
                }
            }
        }
    }
    if (portName.isEmpty()) {
        qWarning() << "[Serial] Sin puertos disponibles";
        emit puertoConectadoChanged(); emit nombrePuertoChanged();
        return false;
    }

    m_puerto.setPortName(portName);
    m_puerto.setBaudRate(QSerialPort::Baud9600);
    m_puerto.setDataBits(QSerialPort::Data8);
    m_puerto.setParity(QSerialPort::NoParity);
    m_puerto.setStopBits(QSerialPort::OneStop);
    m_puerto.setFlowControl(QSerialPort::NoFlowControl);

    if (!m_puerto.open(QIODevice::ReadWrite)) {
        qWarning() << "[Serial] No se pudo abrir" << portName;
        emit puertoConectadoChanged(); emit nombrePuertoChanged();
        return false;
    }

    m_buffer.clear();
    resetWatchdogSerial();
    qDebug() << "[Serial] Conectado a" << portName;
    emit puertoConectadoChanged(); emit nombrePuertoChanged();
    return true;
}

void GestorBiorreactor::desconectar()
{
#ifdef SIMULACION_ACTIVA
    return;
#endif
    if (!m_puerto.isOpen()) return;
    m_puerto.close();
    m_buffer.clear();
    m_timerWatchdogSerial.stop();
    emit puertoConectadoChanged(); emit nombrePuertoChanged();
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot: recepción de datos serial
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::leerDatosSerial()
{
    m_buffer += m_puerto.readAll();
    if (m_buffer.size() > 4096) m_buffer.clear();
    resetWatchdogSerial();
    procesarBufferModbus();
}

// ─────────────────────────────────────────────────────────────────────────────
// Modbus RTU helpers
// ─────────────────────────────────────────────────────────────────────────────

static quint16 modbusRtuCrc(const QByteArray &data)
{
    quint16 crc = 0xFFFF;
    for (quint8 byte : data) {
        crc ^= byte;
        for (int i = 0; i < 8; ++i) {
            if (crc & 0x0001) crc = (crc >> 1) ^ 0xA001;
            else              crc >>= 1;
        }
    }
    return crc;
}

static float bytesToFloat(const QByteArray &data, int offset)
{
    quint32 raw = (static_cast<quint32>((quint8)data[offset])   << 24) |
                  (static_cast<quint32>((quint8)data[offset+1]) << 16) |
                  (static_cast<quint32>((quint8)data[offset+2]) <<  8) |
                   static_cast<quint32>((quint8)data[offset+3]);
    float result;
    memcpy(&result, &raw, sizeof(result));
    return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Modbus RTU buffer processor
// Detecta frames completos en m_buffer y los pasa a parsearTrama().
// Protocolo esperado:
//   Lectura (func 0x03): slave(1)+func(1)+byteCount(1)+data(byteCount)+CRC(2)
//   Escritura (func 0x06): 8 bytes fijos (eco de calibración)
// Si el primer byte no corresponde a un frame válido se descarta para re-sincronizar.
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::procesarBufferModbus()
{
    while (m_buffer.size() >= 5) {
        quint8 funcCode = static_cast<quint8>(m_buffer[1]);
        int expectedLen = 0;

        if (funcCode == 0x03) {
            if (m_buffer.size() < 3) break;
            int byteCount = static_cast<quint8>(m_buffer[2]);
            expectedLen = 3 + byteCount + 2;
        } else if (funcCode == 0x06) {
            expectedLen = 8;
        } else {
            m_buffer.remove(0, 1);  // re-sincronizar
            continue;
        }

        if (m_buffer.size() < expectedLen) break;

        QByteArray frame = m_buffer.left(expectedLen);
        m_buffer.remove(0, expectedLen);

        // Verificar CRC antes de parsear
        quint16 calcCrc = modbusRtuCrc(frame.left(expectedLen - 2));
        quint16 recvCrc = static_cast<quint16>((quint8)frame[expectedLen - 2]) |
                          static_cast<quint16>((quint8)frame[expectedLen - 1] << 8);
        if (calcCrc != recvCrc) {
            qWarning() << "[Modbus] CRC error en frame:" << frame.toHex(' ');
            continue;
        }

        parsearTrama(frame);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parser Modbus RTU
// Soporta:
//   Lectura (func 0x03) de sensor pH  (slave 0x03): extrae pH + temperatura
//   Lectura (func 0x03) de sensor DO  (slave 0x0A): extrae DO + temperatura
//   Escritura (func 0x06): eco de confirmación de calibración
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::parsearTrama(const QByteArray &frame)
{
    if (frame.size() < 5) return;

    quint8 slaveId  = static_cast<quint8>(frame[0]);
    quint8 funcCode = static_cast<quint8>(frame[1]);

    m_ultimaLecturaRS485 = QDateTime::currentDateTime();

    if (funcCode == 0x03) {
        quint8 byteCount = static_cast<quint8>(frame[2]);
        if (frame.size() < 3 + byteCount + 2 || byteCount < 12) return;

        float val1 = bytesToFloat(frame, 3);   // pH o DO
        float temp = bytesToFloat(frame, 11);  // temperatura (offset 3+4+4)

        if (slaveId == 0x03) {
            // RK500-12 pH sensor: val1=pH, val2=internal(skip), val3=temp
            if (val1 >= 0.0f && val1 <= 14.0f)    setSensorPH(static_cast<double>(val1));
            if (temp >= -10.0f && temp <= 120.0f) {
                m_tempPH = temp; m_tempPHValida = true;
                actualizarTemperaturaFusionada();
            }
        } else if (slaveId == 0x0A) {
            // RK500-04 DO sensor: val1=DO, val2=saturation(skip), val3=temp
            if (val1 >= 0.0f && val1 <= 20.0f)    setSensorDO(static_cast<double>(val1));
            if (temp >= -10.0f && temp <= 120.0f) {
                m_tempDO = temp; m_tempDOValida = true;
                actualizarTemperaturaFusionada();
            }
        }
    } else if (funcCode == 0x06) {
        qDebug() << "[CAL] Sensor 0x" << Qt::hex << slaveId << "confirmó calibración";
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fusión de temperatura: promedio de ambos sensores RS-485
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::actualizarTemperaturaFusionada()
{
    if (m_tempPHValida && m_tempDOValida) {
        setSensorTem((m_tempPH + m_tempDO) / 2.0);
        // Histéresis: dispara sobre ON, limpia bajo OFF (evita repicar por el desfase base).
        const double difTemp = qAbs(m_tempPH - m_tempDO);
        if (m_alertaDivergenciaTemp) {
            if (difTemp < DIVERGENCIA_TEMP_OFF_C) setAlertaDivergenciaTemp(false);
        } else {
            if (difTemp > DIVERGENCIA_TEMP_ON_C)  setAlertaDivergenciaTemp(true);
        }
    } else if (m_tempPHValida) {
        setSensorTem(m_tempPH);
    } else if (m_tempDOValida) {
        setSensorTem(m_tempDO);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer: consultar sensores RS-485 alternando pH / DO
// Protocolo: Modbus RTU, función 0x03 (read holding registers), 6 registros.
//   pH sensor  slave 0x03 — RK500-12 manual sección 7.1
//   DO sensor  slave 0x0A — RK500-04 manual sección 7.1
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::consultarSensoresRS485()
{
    if (!m_puerto.isOpen()) return;

    // Frames precalculados con CRC-16/Modbus incluido
    static const QByteArray queryPH = QByteArray::fromHex("030300000006C42A");
    static const QByteArray queryDO = QByteArray::fromHex("0A0300000006C4B3");

    m_puerto.write(m_turnoRS485 == 0 ? queryPH : queryDO);
    m_turnoRS485 = (m_turnoRS485 + 1) % 2;
}

// ─────────────────────────────────────────────────────────────────────────────
// Calibración pH via RS-485
// Frames exactos del manual RK500-12 (sección 8.2).
// Función 0x06 — registro 0x0055.
// Un valor 0.0 indica que ese punto no fue medido y se omite.
// En modo simulación el puerto está cerrado → retorna sin hacer nada (no-op).
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::enviarCalibracionPH(double ph4, double ph7, double ph10)
{
    if (!m_puerto.isOpen()) return;

    static const QByteArray cmdPH4  = QByteArray::fromHex("03060055000499FB");
    static const QByteArray cmdPH7  = QByteArray::fromHex("030600550007D9FA");
    static const QByteArray cmdPH10 = QByteArray::fromHex("03060055000A183F");

    if (ph4  > 0.0) m_puerto.write(cmdPH4);
    if (ph7  > 0.0) m_puerto.write(cmdPH7);
    if (ph10 > 0.0) m_puerto.write(cmdPH10);

    qDebug() << "[CAL] Calibración pH enviada — LOW:" << ph4 << "MID:" << ph7 << "HIGH:" << ph10;
}

// ─────────────────────────────────────────────────────────────────────────────
// Calibración DO via RS-485 (air calibration)
// Frame exacto del manual RK500-04 (sección 7.5).
// Función 0x06 — registro 0x001A.
// Procedimiento: sensor en aire, esperar ~180 s a que estabilice, luego llamar.
// En modo simulación es no-op (puerto cerrado).
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::enviarCalibracionDO()
{
    if (!m_puerto.isOpen()) return;

    static const QByteArray cmdAir = QByteArray::fromHex("0A06001A000168B6");
    m_puerto.write(cmdAir);

    qDebug() << "[CAL] Calibración DO (aire) enviada";
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer: leer sensor de nivel XM125 vía I2C
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::leerSensorNivel()
{
    if (!m_xm125.conectado()) return;

    // Una medición por tick (500 ms): pide TODOS los picos crudos y corre el seguidor de
    // agua. medirPicosCrudos() puede bloquear ~decenas de ms (acotado) esperando BUSY=0.
    bool ok = false; double tempC = 0.0; uint32_t resultado = 0;
    QVector<DriverXM125::PicoCrudo> crudos = m_xm125.medirPicosCrudos(ok, tempC, resultado);
    if (!ok) {   // ciclo sin medición válida (ocupado o error de I2C)
        if (++m_fallosNivel >= 5) setAlertaNivel(true);
        return;
    }
    m_fallosNivel = 0;

    // Datos frescos → alimenta el watchdog I2C (el sensor respondió, aunque no haya picos).
    m_ultimaLecturaI2C = QDateTime::currentDateTime();
    m_timerWatchdogI2C.setInterval(2000);
    m_timerWatchdogI2C.start();

    // Recolectar las distancias de todos los picos y actualizar el seguidor de agua.
    QVector<double> dists;
    dists.reserve(crudos.size());
    for (const DriverXM125::PicoCrudo &p : crudos) dists.append(p.distMm);
    actualizarSeguidorNivel(dists);

    // Salida del seguidor → distancia de nivel de producción. Mientras el seguidor arranca
    // (~4 s) m_nivelFiltrado es -1 → m_distanciaNivelMm queda -1 (sin lectura, control seguro).
    m_distanciaNivelMm = m_nivelFiltrado;
    emit distanciaNivelMmChanged();

    if (m_distanciaNivelMm < 0.0) return;   // seguidor aún sin valor: no evaluar seguridad/%

    double nivel = (DIST_VACIO_MM - m_distanciaNivelMm) / (DIST_VACIO_MM - DIST_LLENO_MM) * 100.0;
    nivel = std::clamp(nivel, 0.0, 100.0);
    setSensorNivel(nivel);

    // Protección de sobrellenado + alarma (histéresis en mm). También decide el
    // estado de alertaNivel en una lectura buena (alto = drenando, si no false).
    evaluarSeguridadNivel();

    // Vaciado por etapas (extracción): corta la válvula al llegar a la referencia.
    procesarVaciadoAuto();

    // ── Watchdog de bombas ────────────────────────────────────────────────────
    // Con bombas activas (llenando en estado 1, o drenando por sobrellenado) la
    // distancia debe cambiar. Si no cambia ≥ UMBRAL_CAMBIO_NIVEL_MM en
    // TIMEOUT_BOMBA_S → aviso de "verificar bombas". Esta función corre cada 500 ms por
    // cada lectura válida del XM125.
    const bool llenando = (m_estadoPreparacion == 1) &&
                          (m_distanciaNivelMm > DIST_NIVEL_OBJETIVO_MM);
    const bool bombasActivas = m_drenandoNivel || llenando || m_rellenandoNivel;
    if (!bombasActivas) {
        m_distRefBomba = -1.0; m_ticksBombaSinCambio = 0;
        setAlertaBombas(false);
    } else if (m_distRefBomba < 0.0) {
        m_distRefBomba = m_distanciaNivelMm; m_ticksBombaSinCambio = 0;
    } else if (qAbs(m_distanciaNivelMm - m_distRefBomba) >= UMBRAL_CAMBIO_NIVEL_MM) {
        m_distRefBomba = m_distanciaNivelMm; m_ticksBombaSinCambio = 0;
        setAlertaBombas(false);
    } else if (++m_ticksBombaSinCambio >= TIMEOUT_BOMBA_S) {
        setAlertaBombas(true);   // bombas activas pero nivel estancado
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SEGUIDOR DE AGUA — filtro predictivo con compuerta (portado del banco de nivel)
//  De TODOS los picos crudos del XM125 elige el que corresponde al agua por su
//  MOVIMIENTO (no por ser el más fuerte: el fuerte suele ser la tapa fija, el fondo
//  o un multipath). Ver detalle en HANDOFF-banco-nivel.md / memoria sensor-nivel-xm125.
// ═════════════════════════════════════════════════════════════════════════════

// Re-sincroniza: re-arranca el seguidor (re-acumula el pico más lejano en rango ~4 s).
void GestorBiorreactor::resyncNivel()
{
    m_trackInitNivel = false; m_initSamplesNivel = 0; m_initMaxFarNivel = -1.0;
    m_velNivel = 0.0; m_trackMissNivel = 0; m_stuckFramesNivel = 0; m_seguidorHit = false;
    m_forzarReacqNivel = false; m_reacqCand = -1.0; m_reacqCount = 0;
    m_nivelFiltrado = -1.0;
    qDebug() << "[Nivel] Re-sincronizando seguidor de agua…";
}

// Re-sync "en operación" (botón de la pantalla de procesos): NO re-arranca desde el vacío
// (eso saltaría al fondo ~1150). Solo re-adquiere el pico de agua más cercano en la zona de
// control en el próximo cuadro estático → corrige el filtro clavado sin tocar las zonas lejanas.
void GestorBiorreactor::resyncNivelOperacion()
{
    m_forzarReacqNivel = true;
    m_reacqCand = -1.0; m_reacqCount = 0; m_trackMissNivel = 0;
    qDebug() << "[Nivel] Re-sync en operación solicitado (re-adquisición en zona de control)";
}

// Banda base por zona (mm): se aprieta conforme sube el nivel (menor distancia). Lejos NO
// se agranda (ahí viven multipath ~1700-1850 y el fondo ~1150); arriba (control) muy apretada.
double GestorBiorreactor::baseBandaNivel(double x) const
{
    if (x > 870.0) return 12.0;
    if (x > 639.0) return 6.0;
    if (x > 300.0) return 3.0;
    return 2.0;                    // zona de control (~216): muy apretada
}

// Dirección del movimiento del nivel según los actuadores activos del HMI:
//   llenar  = FSM de preparación con acción "llenar" (CH3/CH4) → la distancia BAJA
//   drenar  = FSM con acción "drenar" o el drenado de seguridad (CH8/CH10) → la distancia SUBE
// (El vaciado manual de la pantalla de extracción no marca estado → se ve como estático;
//  ahí el seguidor mantiene el ancla, que es seguro.)
int GestorBiorreactor::direccionNivel() const
{
    const bool drenadoManual = m_vaciadoManualInf || m_vaciadoManualSup || m_vaciadoManualAux
                            || (m_vaciadoEtapa != 0);   // vaciado por etapas (extracción)
    // (A) El pulso de pH enciende CH3/CH4 → sube el nivel: contar como "llenando" para que el
    // seguidor siga el ascenso durante la dosificación (si no, se queda estático y se clava).
    // El pH solo dosifica dentro de la banda de operación, así que esto solo actúa ahí.
    const bool llenando = (m_accionLlenado == 1) || m_rellenandoNivel || m_pulsoNeutralizador;
    const bool drenando = (m_accionLlenado == -1) || m_drenandoNivel || drenadoManual;
    if (llenando && !drenando) return -1;
    if (drenando && !llenando) return +1;
    return 0;
}

// De TODOS los picos elige el más cercano a la predicción. SOLO se predice (coasting)
// cuando un actuador mueve el nivel; si está estático se mantiene el ancla (último dato
// confirmado) para que el estimado no derive hacia un reflejo fijo espurio durante un hueco.
void GestorBiorreactor::actualizarSeguidorNivel(const QVector<double> &dists)
{
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    double dt = (m_trackPrevMsNivel > 0) ? (nowMs - m_trackPrevMsNivel) / 1000.0 : 0.5;
    if (dt <= 0.0 || dt > 3.0) dt = 0.5;   // clamp (arranque / huecos largos)

    if (!m_trackInitNivel) {
        // Arranque robusto: acumula el pico MÁS LEJANO en rango durante los primeros
        // SEG_INIT_SAMPLES frames (~4 s) → arranca en el vacío (~1150), no en una
        // estructura cercana (~230) si el eco del fondo se pierde en el primer frame.
        for (double d : dists)
            if (d >= SEG_NIVEL_MIN_MM && d <= SEG_NIVEL_MAX_MM && d > m_initMaxFarNivel)
                m_initMaxFarNivel = d;
        if (++m_initSamplesNivel < SEG_INIT_SAMPLES) return;
        if (m_initMaxFarNivel < 0.0) { m_initSamplesNivel = 0; return; }  // aún sin pico en rango
        m_anchorNivel = m_nivelFiltrado = m_initMaxFarNivel;
        m_ultimoAnchorMovido = m_initMaxFarNivel;
        m_velNivel = 0.0; m_trackMissNivel = 0; m_stuckFramesNivel = 0;
        m_trackInitNivel = true; m_seguidorHit = true; m_trackPrevMsNivel = nowMs;
        return;
    }

    const int  dir      = direccionNivel();   // -1 llenando, +1 drenando, 0 estático
    const bool moviendo = (dir != 0);

    // Predicción empujada por la dirección, con piso conservador (se adelanta a un reflejo fijo).
    double pred;
    if (moviendo) {
        const double piso = (dir < 0) ? -SEG_FLOOR_LLENADO_MM_S
                                       :  std::max(1.0, m_tasaVaciadoNivel * 0.5);
        double velEff = m_velNivel;
        if (dir < 0 && velEff > piso) velEff = piso;   // asegura bajar (más negativo)
        if (dir > 0 && velEff < piso) velEff = piso;   // asegura subir
        pred = m_nivelFiltrado + velEff * dt;
    } else {
        pred = m_anchorNivel; m_velNivel = 0.0;        // estático: mantiene el ancla
    }
    if (pred < SEG_NIVEL_MIN_MM) pred = SEG_NIVEL_MIN_MM;
    if (pred > SEG_NIVEL_MAX_MM) pred = SEG_NIVEL_MAX_MM;

    // Banda: en control apretada; al drenar (más rápido) más holgada. Tope por zona y por salto.
    double banda = baseBandaNivel(pred) + m_trackMissNivel * 3.0;
    double tope  = (pred > 639.0) ? 45.0 : (pred > 300.0 ? 25.0 : 12.0);
    if (dir > 0) { banda *= 1.8; if (tope < 30.0) tope = 30.0; }
    if (banda > tope)             banda = tope;
    if (banda > SEG_MAX_JUMP_MM)  banda = SEG_MAX_JUMP_MM;

    // Elegir el pico más cercano a la predicción, con rango válido y consistencia direccional.
    double best = -1.0, bd = 1e9;
    for (double p : dists) {
        if (p < SEG_NIVEL_MIN_MM || p > SEG_NIVEL_MAX_MM) continue;         // rango válido
        if (dir < 0 && p > m_anchorNivel + SEG_DIR_TOL_MM) continue;        // llenando: no hacia arriba
        if (dir > 0 && p < m_anchorNivel - SEG_DIR_TOL_MM) continue;        // drenando: no hacia abajo
        const double ad = std::fabs(p - pred);
        if (ad <= banda && ad < bd) { bd = ad; best = p; }
    }

    // Tope de velocidad: drenar rápido; llenar más lento en valores lejanos (para no sobrepasar el agua).
    // Bajada (drenado): sin cambio. Subida (llenado): −30% respecto a la velocidad previa, porque
    // el caudal real es menor que el previsto por el tiempo de arranque/paro de las bombas en cada
    // pulso; así el seguidor no se sobrepasa del agua real. (1.0→0.70, 2.0→1.40, 3.5→2.45.)
    double velClamp;
    if (dir > 0)            velClamp = std::max(8.0, m_tasaVaciadoNivel * 2.0);
    else if (pred > 870.0)  velClamp = 0.70;
    else if (pred > 639.0)  velClamp = 1.40;
    else                    velClamp = 2.45;

    if (best >= 0.0) {
        if (moviendo) {
            const double nv = (best - m_nivelFiltrado) / dt;
            m_velNivel = 0.6 * m_velNivel + 0.4 * nv;
            if (m_velNivel >  velClamp) m_velNivel =  velClamp;
            if (m_velNivel < -velClamp) m_velNivel = -velClamp;
        }
        m_anchorNivel = m_nivelFiltrado = best;   // ancla = último dato confirmado
        m_trackMissNivel = 0; m_seguidorHit = true;
    } else {
        // Coasting: la velocidad decae y el valor NO se aleja más de SEG_MAX_COAST_MM del ancla.
        m_velNivel *= 0.85;
        m_nivelFiltrado = moviendo ? pred : m_anchorNivel;
        if (m_anchorNivel >= 0.0) {
            if (m_nivelFiltrado < m_anchorNivel - SEG_MAX_COAST_MM) m_nivelFiltrado = m_anchorNivel - SEG_MAX_COAST_MM;
            if (m_nivelFiltrado > m_anchorNivel + SEG_MAX_COAST_MM) m_nivelFiltrado = m_anchorNivel + SEG_MAX_COAST_MM;
        }
        m_trackMissNivel++; m_seguidorHit = false;
    }

    // Detección de "pegado" a un reflejo fijo + escape: con actuador corriendo el nivel DEBE
    // avanzar; si el ancla no progresa en STUCK_N frames (~7 s), saltar al pico más cercano
    // que SÍ va en la dirección esperada (el agua real).
    if (moviendo) {
        const double progreso = dir * (m_anchorNivel - m_ultimoAnchorMovido);
        if (progreso > SEG_STUCK_PROG_MM) {
            m_ultimoAnchorMovido = m_anchorNivel; m_stuckFramesNivel = 0;
        } else if (++m_stuckFramesNivel >= SEG_STUCK_N) {
            double esc = -1.0, ed = 1e9;
            for (double p : dists) {
                if (p < SEG_NIVEL_MIN_MM || p > SEG_NIVEL_MAX_MM) continue;
                const double delta = dir * (p - m_anchorNivel);   // >0 si va en la dir esperada
                if (delta > SEG_ESCAPE_MARGEN_MM && delta < SEG_ESCAPE_VENTANA_MM) {
                    const double dd = std::fabs(p - m_anchorNivel);
                    if (dd < ed) { ed = dd; esc = p; }
                }
            }
            if (esc >= 0.0) {
                m_anchorNivel = m_nivelFiltrado = esc;
                m_velNivel = dir * std::max(1.0, m_tasaVaciadoNivel * 0.5);
                m_seguidorHit = true;
                qDebug() << "[Nivel] escape de reflejo fijo →" << esc << "mm (dir" << dir << ")";
            }
            m_ultimoAnchorMovido = m_anchorNivel; m_stuckFramesNivel = 0; m_trackMissNivel = 0;
        }
    } else {
        // ── Estático (dir == 0) ──────────────────────────────────────────────
        m_ultimoAnchorMovido = m_anchorNivel; m_stuckFramesNivel = 0;

        // (B) Re-adquisición SOLO en la zona de control (ancla ≤ SEG_REACQ_ZONA_MM). Cuando el
        // nivel cambia lento (pH dosificando con burbujeo) el filtro estático se queda clavado
        // en el ancla; si aparece un pico plausible cercano (banda de operación) consistente
        // durante SEG_REACQ_N cuadros, se adopta para ponerse al día. (D) el botón manual
        // (m_forzarReacqNivel) lo hace de inmediato. En zonas lejanas NO se toca (ancla rígida
        // evita fugarse a multipath/fondo). Solo cuando este cuadro fue coasting (no hubo pico
        // en la banda normal) o cuando se fuerza manualmente.
        const bool enZonaControl = (m_anchorNivel >= 0.0 && m_anchorNivel <= SEG_REACQ_ZONA_MM);
        if (enZonaControl && (!m_seguidorHit || m_forzarReacqNivel)) {
            double cand = -1.0, cdist = 1e9;
            for (double p : dists) {                       // pico de operación más cercano al ancla
                if (p < SEG_NIVEL_MIN_MM || p > SEG_REACQ_ZONA_MM) continue;
                const double d = std::fabs(p - m_anchorNivel);
                if (d < cdist) { cdist = d; cand = p; }
            }
            if (m_forzarReacqNivel) {                       // (D) re-sync manual: salto inmediato
                if (cand >= 0.0 && cdist <= SEG_REACQ_VENTANA_MM) {
                    m_anchorNivel = m_nivelFiltrado = cand; m_seguidorHit = true;
                    qDebug() << "[Nivel] re-sync manual (operación) →" << cand << "mm";
                }
                m_forzarReacqNivel = false; m_reacqCand = -1.0; m_reacqCount = 0;
            } else {
                // Solo picos FUERA de la banda normal (los de dentro ya se toman arriba).
                const bool candFuera = (cand >= 0.0 && cdist > banda && cdist <= SEG_REACQ_VENTANA_MM);
                if (candFuera && std::fabs(cand - m_reacqCand) <= SEG_REACQ_TOL_MM) {
                    if (++m_reacqCount >= SEG_REACQ_N) {
                        m_anchorNivel = m_nivelFiltrado = cand; m_seguidorHit = true;
                        m_reacqCount = 0; m_reacqCand = -1.0;
                        qDebug() << "[Nivel] re-adquisición estática →" << cand << "mm";
                    }
                } else {
                    m_reacqCand = candFuera ? cand : -1.0;
                    m_reacqCount = candFuera ? 1 : 0;
                }
            }
        } else {
            m_reacqCand = -1.0; m_reacqCount = 0;
            if (!enZonaControl) m_forzarReacqNivel = false;   // fuera de zona: no re-adquirir
        }
    }

    if (m_nivelFiltrado < SEG_NIVEL_MIN_MM) m_nivelFiltrado = SEG_NIVEL_MIN_MM;
    if (m_nivelFiltrado > SEG_NIVEL_MAX_MM) m_nivelFiltrado = SEG_NIVEL_MAX_MM;
    m_trackPrevMsNivel = nowMs;
}

// ─────────────────────────────────────────────────────────────────────────────
// Protección de sobrellenado — histéresis en DISTANCIA (mm)
//   • distancia ≤ DIST_NIVEL_ALTO_MM     → tanque lleno: parar llenado (CH3/CH4)
//                                           + drenar (CH8/CH10) + alarma
//   • distancia ≥ DIST_NIVEL_OBJETIVO_MM → drenó suficiente: parar drenado + limpiar
//   Menor distancia = mayor nivel; drenar sube la distancia hasta el objetivo.
//   Se trabaja en mm porque DIST_VACIO_MM sigue sin calibrar (DIST_LLENO_MM sí).
// ─────────────────────────────────────────────────────────────────────────────
void GestorBiorreactor::evaluarSeguridadNivel()
{
    if (m_distanciaNivelMm < 0.0) return;   // sin lectura válida todavía

    const bool anterior        = m_drenandoNivel;
    const bool rellenoAnterior = m_rellenandoNivel;

    // La protección de sobrellenado (drenado físico) SOLO actúa con salidas habilitadas
    // (proceso/preparación activos → OE LOW). En verificación o idle (OE HIGH) drenar
    // sería "fantasma": no cambia el nivel, bloquea la verificación y dispara el watchdog
    // de bombas. Por eso aquí no se drena ni se rellena si no hay proceso activo.
    if (!m_procesoActivo) {
        if (m_drenandoNivel || m_rellenandoNivel) {
            m_drenandoNivel = false;
            m_rellenandoNivel = false;
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
            m_salidaBombaNivel = false;
            emit salidaBombaNivelChanged();
        }
        m_ticksNivelAlto = m_ticksNivelSeguro = m_ticksNivelBajo = m_ticksNivelLleno = 0;
        setAlertaNivel(false);
        return;
    }
    // Confirmación: exigir CONFIRM_NIVEL_N lecturas sostenidas para cruzar cada umbral,
    // así un salto espurio del radar (p.ej. reflejo del soporte/fondo) no dispara ni
    // detiene el drenado en falso.
    if (!m_drenandoNivel) {
        if (m_distanciaNivelMm <= DIST_NIVEL_ALTO_MM) {
            if (++m_ticksNivelAlto >= CONFIRM_NIVEL_N) { m_drenandoNivel = true; m_ticksNivelAlto = 0; }
        } else {
            m_ticksNivelAlto = 0;
        }
    } else {
        if (m_distanciaNivelMm >= DIST_NIVEL_OBJETIVO_MM) {
            if (++m_ticksNivelSeguro >= CONFIRM_NIVEL_N) { m_drenandoNivel = false; m_ticksNivelSeguro = 0; }
        } else {
            m_ticksNivelSeguro = 0;
        }
    }

    // ── Lado BAJO: auto-rellenado si el nivel cayó por debajo del objetivo ─────
    // (vaciado accidental). Solo fuera de la fase de Llenado de preparación (la FSM ya
    // llena ahí) y si NO se está drenando. Rellena CH3/CH4 hasta el objetivo (216 mm):
    //   arranca cuando dist > 216 + margen (más vacío) · para cuando dist ≤ 216.
    // No pelea con el pH: el gate de nivel apaga la dosificación fuera de 145–216 mm.
    // No auto-rellenar durante la fase de Llenado (la FSM ya llena), mientras se drena por
    // sobrellenado, ni durante un vaciado por etapas de extracción (si no, pelearían las bombas).
    const bool rellenoPermitido = (m_estadoPreparacion != 1) && !m_drenandoNivel && (m_vaciadoEtapa == 0);
    if (!rellenoPermitido) {
        m_rellenandoNivel = false; m_ticksNivelBajo = 0; m_ticksNivelLleno = 0;
    } else if (!m_rellenandoNivel) {
        if (m_distanciaNivelMm > DIST_NIVEL_OBJETIVO_MM + LLENADO_MARGEN_MM) {
            if (++m_ticksNivelBajo >= CONFIRM_NIVEL_N) { m_rellenandoNivel = true; m_ticksNivelBajo = 0; }
        } else {
            m_ticksNivelBajo = 0;
        }
    } else {
        if (m_distanciaNivelMm <= DIST_NIVEL_OBJETIVO_MM) {
            if (++m_ticksNivelLleno >= CONFIRM_NIVEL_N) { m_rellenandoNivel = false; m_ticksNivelLleno = 0; }
        } else {
            m_ticksNivelLleno = 0;
        }
    }

    // ── Aplicar salidas (drenar y rellenar son mutuamente excluyentes) ────────
    if (m_drenandoNivel) {
        // Sobrellenado: forzar llenado OFF y drenado ON en cada lectura (robusto ante
        // otros lazos que intenten reactivar las bombas de llenado).
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, true);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, true);
    } else {
        if (anterior) {
            // Transición alto→normal: apagar el drenado.
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
            m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
        }
        if (m_rellenandoNivel) {
            // Nivel bajo: forzar llenado ON en cada lectura hasta llegar al objetivo.
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 100.0);
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 100.0);
        } else if (rellenoAnterior) {
            // Transición objetivo alcanzado → apagar el llenado (devuelve CH3/CH4 al pH).
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
        }
    }

    if (m_drenandoNivel != anterior) {
        m_salidaBombaNivel = m_drenandoNivel;   // reutilizado: true = drenado activo
        emit salidaBombaNivelChanged();
    }

    setAlertaNivel(m_drenandoNivel);   // alarma roja SOLO por sobrellenado (rellenar no alarma)
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer: loop de control (1 s)
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::ejecutarControlLoop()
{
    if (!m_procesoActivo) return;

    // ── Gate de nivel ─────────────────────────────────────────────────────────
    // Temperatura y pH SOLO actúan con agua tocando el sensor: banda
    // 145 mm ≤ dist ≤ 216 mm y sin drenado en curso. Menor distancia = mayor nivel.
    //   dist > 216 → aún sin llenar (sensor descubierto) → controles OFF
    //   dist < 145 → sobrellenado → drenar hasta 216 (evaluarSeguridadNivel) + controles OFF
#ifdef SIMULACION_ACTIVA
    const bool aguaEnContacto = true;   // sin sensor de distancia en simulación
#else
    const bool aguaEnContacto =
            (m_distanciaNivelMm >= DIST_NIVEL_ALTO_MM) &&
            (m_distanciaNivelMm <= DIST_NIVEL_OBJETIVO_MM) &&
            !m_drenandoNivel;
#endif

    // ── Temperatura: PID + Feedforward (modelo FOPDT) → m_salidaCalentador ─────
    // La escritura a CH_CALENTADOR/CH_CALENTADOR_2 la gestiona onCrucePorCero() via
    // burst firing. En simulación (sin ZC) se escribe directamente.
    //   Planta: K=0.6291 °C/%, τ=23088 s, θ=204 s (identificado 2026-07)
    //   u_ff = (SP - T_amb) / K → pre-carga la salida en estado estacionario
    static constexpr double K_PLANTA_TEMP     = 0.6291;   // °C/%
    static constexpr double TAU_PLANTA_TEMP   = 23088.0;  // s
    static constexpr double THETA_PLANTA_TEMP = 204.0;    // s

    // Seguridad: no calentar sin datos frescos de temperatura (sensores RS-485 caídos).
    double nuevoCalentador = 0.0;
    if (aguaEnContacto && !m_alertaSerial) {
        double u_ff  = qBound(0.0, (m_setpointTem - m_tAmbiente) / K_PLANTA_TEMP, 100.0);
        double u_pid = m_pidTemp.calcular(m_setpointTem, m_sensorTem);
        nuevoCalentador = qBound(0.0, u_ff + u_pid, 100.0);
    } else {
        m_pidTemp.reiniciar();   // sin agua o sin datos: no calentar; evitar windup
    }

    // Seguridad: corte DURO por sobre-temperatura (SP + DELTA), independiente del PID.
    // Solo con datos frescos (si el serial está caído, el calentador ya quedó en 0 arriba).
    const bool sobreTemp = !m_alertaSerial && (m_sensorTem > m_setpointTem + DELTA_SOBRETEMP_C);
    if (sobreTemp) { nuevoCalentador = 0.0; m_pidTemp.reiniciar(); }
    setAlertaSobreTemp(sobreTemp);
    if (!qFuzzyCompare(m_salidaCalentador, nuevoCalentador)) {
        m_salidaCalentador = nuevoCalentador;
#ifdef SIMULACION_ACTIVA
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_CALENTADOR,   m_salidaCalentador);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_CALENTADOR_2, m_salidaCalentador);
#endif
        emit salidaCalentadorChanged();
    }

    // DIAG (temporal): estado del calentamiento para depurar "no calienta".
    qInfo().nospace() << "[DIAG-CALOR] proc=" << m_procesoActivo
                      << " estPrep=" << m_estadoPreparacion
                      << " dist=" << m_distanciaNivelMm
                      << " agua=" << aguaEnContacto
                      << " drenando=" << m_drenandoNivel
                      << " alSerial=" << m_alertaSerial
                      << " T=" << m_sensorTem << " SP=" << m_setpointTem
                      << " salidaCal=" << m_salidaCalentador
                      << " zcTotalDebug=" << m_zcDebug
                      << " zcDisp=" << m_zcDisparando
                      << " OE=" << m_pca9685.estadoOE()   // 0=salidas activas, 1=deshabilitadas
                      << " salBombaNivel=" << m_salidaBombaNivel;

    // ── ETA al setpoint de temperatura (modelo FOPDT, solo informativo) ────────
    //   T_ss  = T_amb + K·salida  (temp estacionaria con la salida actual)
    //   t_eta = τ·ln((T_now−T_ss)/(SP−T_ss)) + θ    [válido si T_ss > SP y T_now < SP]
    double eta = -1.0;   // N/A (en SP, enfriando, potencia insuficiente o sin agua)
    if (aguaEnContacto && m_salidaCalentador > 0.5 && m_sensorTem < m_setpointTem - 1.0) {
        double T_ss = m_tAmbiente + K_PLANTA_TEMP * m_salidaCalentador;
        if (T_ss > m_setpointTem) {
            double arg = (m_sensorTem - T_ss) / (m_setpointTem - T_ss);
            if (arg > 0.0)
                eta = qMax(0.0, TAU_PLANTA_TEMP * qLn(arg)) + THETA_PLANTA_TEMP;
        }
    }
    if (qAbs(m_etaCalentamientoSeg - eta) > 0.5) {
        m_etaCalentamientoSeg = eta;
        emit etaCalentamientoSegChanged();
    }

    // ── Fuzzy pH SISO — control por pulso cada Ts = 30 s ─────────────────────
    // Arquitectura:
    //   - El timer de control corre cada 1 s.
    //   - Cada 30 ticks (Ts) se evalúa el controlador difuso → t_pulso [0, 7] s.
    //   - Pre-filtro: error ≤ 0 → no se actúa (hongo acidifica solo).
    //   - Guarda nivel: nivel ≥ 85% → no se actúa (riesgo de desbordamiento).
    //   - Durante el pulso: bomba neutralizadora ON al 100%.
    //   - Fuera del pulso: bomba neutralizadora OFF.
    if (m_fuzzyPHHabilitado) {
        ++m_contadorCicloPH;

        // ── Gestión del pulso activo ─────────────────────────────────────────
        if (m_tPulsoRestante > 0) {
            --m_tPulsoRestante;
            if (!m_pulsoNeutralizador) {
                m_pulsoNeutralizador = true;
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 100.0);
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 100.0);
                emit pulsoNeutralizadorActivoChanged();
            }
            if (m_tPulsoRestante == 0) {
                // Fin del pulso
                m_pulsoNeutralizador = false;
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
                emit pulsoNeutralizadorActivoChanged();
            }
        }

        // ── Evaluación del controlador al completar el ciclo ─────────────────
        if (m_contadorCicloPH >= static_cast<int>(TS_CONTROL_PH_S)) {
            m_contadorCicloPH = 0;

            const double error = m_setpointPH - m_sensorPH;

            // Pre-filtro: error ≤ 0 → esperar al hongo (acidificación natural)
            // Guarda nivel: nivel ≥ 95% (NIVEL_MAX_PCT) → drenado activo, no agregar volumen
            // La banda de histéresis [85 %, 95 %] la gestiona ControladorHisteresis por separado
            const bool accionPermitida = (error > 0.0)
                                      && aguaEnContacto       // solo con agua tocando el sensor (145–216 mm, sin drenar)
                                      && !m_alertaSerial       // no dosificar sin datos frescos del sensor de pH
                                      && (m_sensorNivel < m_nivelMaxPct);

            if (accionPermitida) {
                double tPulso = m_fuzzyPH.calcular(m_setpointPH, m_sensorPH);
                // Redondear al entero más cercano de segundos (resolución del timer)
                m_tPulsoRestante = qBound(0, static_cast<int>(qRound(tPulso)),
                                          static_cast<int>(T_PULSO_MAX_S));
                // Publicar t_pulso calculado para monitoreo/gráficas
                if (!qFuzzyCompare(m_salidaBombaEtanol, tPulso)) {
                    m_salidaBombaEtanol = tPulso;
                    emit salidaBombaEtanolChanged();
                }
            } else {
                m_tPulsoRestante = 0;
                if (m_pulsoNeutralizador) {
                    m_pulsoNeutralizador = false;
                    m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
                    m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
                    emit pulsoNeutralizadorActivoChanged();
                }
            }
        }
    }

    // Nivel → protección de sobrellenado y drenado (CH8/CH10) se gestiona en
    // evaluarSeguridadNivel(), llamado desde leerSensorNivel() con la distancia
    // cruda en mm. Aquí ya no se actúa sobre el nivel.

    // CH_LUZ reasignado a CH_BOMBA_NEUT_A=3 (bomba en serie) — control de luz deshabilitado.
}

// ─────────────────────────────────────────────────────────────────────────────
// Registro histórico de sensores
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::iniciarRegistro(const QString &proyecto, const QString &experimento)
{
    if (m_timerRegistro.isActive()) return;  // guard doble llamada
    m_nombreProyectoRegistro = proyecto;
    m_nombreExpRegistro      = experimento;
    m_lecturas.clear();
    m_tiempoInicioRegistro = QDateTime::currentDateTime();
    connect(&m_timerRegistro, &QTimer::timeout,
            this, &GestorBiorreactor::registrarLectura, Qt::UniqueConnection);
    m_timerRegistro.setInterval(30000);
    m_timerRegistro.start();
    registrarLectura(); // punto t = 0
}

void GestorBiorreactor::detenerRegistro()
{
    if (!m_timerRegistro.isActive()) return;
    m_timerRegistro.stop();
    QString clave = "lecturas_" + sanitizarNombre(m_nombreProyectoRegistro)
                  + "_" + sanitizarNombre(m_nombreExpRegistro);
    QVariantList lista;
    lista.reserve(m_lecturas.size());
    for (const QVariantMap &m : m_lecturas)
        lista.append(m);
    guardarModelo(clave, lista);
    qDebug() << "[Registro] Guardadas" << m_lecturas.size() << "lecturas en" << clave;
}

bool GestorBiorreactor::registroActivo() const
{
    return m_timerRegistro.isActive();
}

int GestorBiorreactor::totalLecturas() const
{
    return m_lecturas.size();
}

void GestorBiorreactor::registrarLectura()
{
    QVariantMap lec;
    lec["hora"]  = QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm:ss");
    lec["temp"]  = m_sensorTem;
    lec["ph"]    = m_sensorPH;
    lec["nivel"] = m_sensorNivel;
    lec["luz"]   = m_sensorLuz;
    lec["do"]    = m_sensorDO;
    m_lecturas.append(lec);
}

void GestorBiorreactor::leerTempHmi()
{
    // Temperatura del sensor interno del RTC DS3231 (≈ ambiente del gabinete de la HMI).
    // El DS3231 está enlazado al kernel (rtc-ds1307) y expone su temperatura por hwmon
    // en millidegrados. Se lee por sysfs (no por I2C: el bus 0x68 lo posee el kernel).
#if defined(Q_OS_LINUX) && !defined(SIMULACION_ACTIVA)
    // Ruta estable por el dispositivo I2C 1-0068; el número de hwmon puede variar por boot.
    static const QStringList basesHwmon = {
        "/sys/bus/i2c/devices/1-0068/hwmon",   // preferida (dispositivo del RTC)
        "/sys/class/hwmon"                     // respaldo: buscar el que se llame "ds3231"
    };
    for (const QString &base : basesHwmon) {
        QDir dir(base);
        if (!dir.exists()) continue;
        const QStringList hwmons = dir.entryList(QStringList() << "hwmon*",
                                                 QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &hw : hwmons) {
            const QString dirHw = base + "/" + hw;
            // En /sys/class/hwmon filtrar por nombre "ds3231"; en la ruta del RTC no hace falta.
            if (base.endsWith("/hwmon")) {
                // ruta del dispositivo RTC: cualquier hwmon aquí es el DS3231
            } else {
                QFile fn(dirHw + "/name");
                if (!fn.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
                if (fn.readAll().trimmed() != "ds3231") continue;
            }
            QFile ft(dirHw + "/temp1_input");
            if (!ft.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
            bool ok = false;
            const double milli = ft.readAll().trimmed().toDouble(&ok);
            if (ok) { setTempHmi(milli / 1000.0); return; }
        }
    }
    // No se encontró el sensor: dejar sin lectura (el indicador se oculta).
    setTempHmi(-1.0);
#elif defined(SIMULACION_ACTIVA)
    // Valor sintético para desarrollo en escritorio.
    setTempHmi(32.0 + 3.0 * qSin(m_tickSim * 0.01));
#else
    setTempHmi(-1.0);
#endif
}

bool GestorBiorreactor::exportarRegistroCSV(const QString &carpetaDestino,
                                             const QString &nombreExp,
                                             const QString &nombreProyecto)
{
    // Copia local para no mutar m_lecturas si se exporta un experimento diferente al activo
    QVector<QVariantMap> lecturas = m_lecturas;

    if (lecturas.isEmpty()) {
        QString clave = "lecturas_" + sanitizarNombre(nombreProyecto)
                      + "_" + sanitizarNombre(nombreExp);
        const QVariantList cargado = cargarModelo(clave);
        for (const QVariant &v : cargado)
            lecturas.append(v.toMap());
    }
    if (lecturas.isEmpty()) {
        qWarning() << "[CSV] Sin lecturas para exportar";
        return false;
    }

    QString carpeta = carpetaDestino.isEmpty()
                    ? basePathStr()
                    : carpetaDestino;

    carpeta += "/" + sanitizarNombre(nombreProyecto) + "/" + sanitizarNombre(nombreExp);
    if (!QDir().mkpath(carpeta)) {
        qWarning() << "[CSV] No se pudo crear carpeta" << carpeta;
        return false;
    }

    QString nombreArchivo = "sensores_" +
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".csv";
    QFile f(carpeta + "/" + nombreArchivo);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "[CSV] No se pudo crear" << f.fileName();
        return false;
    }

    QTextStream out(&f);
    out.setEncoding(QStringConverter::Utf8);

    out << "# Proyecto: "    << nombreProyecto << "\n"
        << "# Experimento: " << nombreExp      << "\n"
        << "# Inicio: "      << m_tiempoInicioRegistro.toString("dd/MM/yyyy HH:mm:ss") << "\n"
        << "# Exportado: "   << QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm:ss") << "\n"
        << "# Lecturas: "    << lecturas.size() << "\n"
        << "#\n"
        << "Fecha y Hora,Temperatura (°C),pH,Nivel (%),Luz (%),DO (mg/L)\n";

    for (const QVariantMap &lec : lecturas) {
        out << lec["hora"].toString() << ","
            << QString::number(lec["temp"].toDouble(),  'f', 2) << ","
            << QString::number(lec["ph"].toDouble(),    'f', 2) << ","
            << QString::number(lec["nivel"].toDouble(), 'f', 1) << ","
            << QString::number(lec["luz"].toDouble(),   'f', 1) << ","
            << QString::number(lec["do"].toDouble(),    'f', 2) << "\n";
    }

    out.flush();
    f.flush();
    f.close();
#ifdef Q_OS_LINUX
    // Volcar los buffers al dispositivo antes de que el usuario retire la memoria.
    ::sync();
#endif

    qDebug() << "[CSV] Registro exportado a" << f.fileName()
             << "(" << lecturas.size() << "lecturas)";
    return true;
}

QString GestorBiorreactor::rutaBaseData() const
{
    return basePathStr();
}

void GestorBiorreactor::eliminarCarpetaExperimento(const QString &nombreProyecto,
                                                    const QString &nombreExp)
{
    QString carpetaExp = basePathStr()
                       + "/" + sanitizarNombre(nombreProyecto)
                       + "/" + sanitizarNombre(nombreExp);
    QDir dirExp(carpetaExp);
    if (dirExp.exists()) {
        dirExp.removeRecursively();
        qDebug() << "[Data] Eliminada carpeta experimento:" << carpetaExp;
    }
    // Si el proyecto quedó vacío, eliminarlo también
    QString carpetaProyecto = basePathStr() + "/" + sanitizarNombre(nombreProyecto);
    QDir dirProyecto(carpetaProyecto);
    if (dirProyecto.exists() && dirProyecto.isEmpty())
        dirProyecto.removeRecursively();
}

// ─────────────────────────────────────────────────────────────────────────────
// Exportación USB
// ─────────────────────────────────────────────────────────────────────────────

QString GestorBiorreactor::detectarUSB()
{
#ifdef Q_OS_LINUX
    // Detección principal: leer /proc/mounts y quedarse con el primer punto de montaje
    // escribible cuyo dispositivo sea removible (/dev/sd* o /dev/mmcblk*p*) y que NO sea
    // la raíz del sistema. Es más fiable que adivinar el directorio del usuario, sobre
    // todo bajo systemd como root (USER = root, no pi).
    QFile mounts("/proc/mounts");
    if (mounts.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&mounts);
        while (!in.atEnd()) {
            const QStringList campos = in.readLine().split(' ', Qt::SkipEmptyParts);
            if (campos.size() < 2) continue;
            const QString dispositivo = campos[0];
            // /proc/mounts escapa los espacios como \040
            QString punto = campos[1];
            punto.replace("\\040", " ");

            const bool esBloqueUSB = dispositivo.startsWith("/dev/sd")
                                  || dispositivo.startsWith("/dev/mmcblk");
            if (!esBloqueUSB) continue;
            // Descartar el sistema de archivos raíz y particiones de arranque/sistema.
            if (punto == "/" || punto == "/boot" || punto.startsWith("/boot/")) continue;
            // Solo puntos de montaje típicos de medios extraíbles.
            if (!(punto.startsWith("/media") || punto.startsWith("/run/media")
                  || punto.startsWith("/mnt"))) continue;

            QFileInfo fi(punto);
            if (fi.exists() && fi.isWritable())
                return punto;
        }
    }

    // Respaldo: recorrer los directorios de montaje habituales.
    const QString usuario = qEnvironmentVariable("USER", "pi");
    const QStringList raices = {
        "/media/pi",
        "/media/" + usuario,
        "/run/media/" + usuario,
        "/media",
        "/mnt"
    };
    for (const QString &raiz : raices) {
        QDir dir(raiz);
        if (!dir.exists()) continue;
        const QStringList subs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &sub : subs) {
            QString ruta = raiz + "/" + sub;
            QFileInfo fi(ruta);
            if (fi.isWritable())
                return ruta;
        }
    }
    return QString();
#elif defined(Q_OS_WIN)
    DWORD drives = GetLogicalDrives();
    for (int i = 2; i < 26; ++i) {   // empezar en C:
        if (!(drives & (1 << i))) continue;
        QString letra = QString("%1:\\").arg(QChar('A' + i));
        if (GetDriveTypeW(reinterpret_cast<LPCWSTR>(letra.utf16())) == DRIVE_REMOVABLE) {
            QFileInfo fi(letra);
            if (fi.isWritable())
                return letra;
        }
    }
    return QString();
#else
    return QString();
#endif
}

QString GestorBiorreactor::montarUSB()
{
    // Si ya hay una USB montada, devolver su ruta directamente.
    const QString yaMontada = detectarUSB();
    if (!yaMontada.isEmpty())
        return yaMontada;

#ifdef Q_OS_LINUX
    // Sin escritorio (kiosko), las memorias no se auto-montan. Buscar la primera
    // partición extraíble no montada y montarla. La app corre como root.
    // /sys/block/<disco>/removable == 1 identifica el disco extraíble.
    QDir sysBlock("/sys/block");
    const QStringList discos = sysBlock.entryList(QStringList() << "sd*",
                                                  QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &disco : discos) {
        QFile rem("/sys/block/" + disco + "/removable");
        if (!rem.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        const bool extraible = rem.readAll().trimmed() == "1";
        rem.close();
        if (!extraible) continue;

        // Buscar la primera partición del disco (sdX1, sdX2, ...); si no hay
        // particiones, intentar el disco completo (sdX).
        QDir dirDisco("/sys/block/" + disco);
        QStringList parts = dirDisco.entryList(QStringList() << (disco + "*"),
                                               QDir::Dirs | QDir::NoDotAndDotDot);
        std::sort(parts.begin(), parts.end());
        if (parts.isEmpty()) parts << disco;

        for (const QString &part : parts) {
            const QString dev = "/dev/" + part;

            // 1) Preferir udisksctl (respeta permisos y monta bajo /media o /run/media).
            QProcess udisks;
            udisks.start("udisksctl", QStringList() << "mount" << "-b" << dev);
            if (udisks.waitForStarted(2000) && udisks.waitForFinished(8000)
                    && udisks.exitCode() == 0) {
                const QString ruta = detectarUSB();
                if (!ruta.isEmpty()) return ruta;
            }

            // 2) Respaldo: mount directo (somos root) en un punto propio.
            const QString punto = "/media/biorreactor_usb";
            QDir().mkpath(punto);
            QProcess mnt;
            mnt.start("mount", QStringList() << dev << punto);
            if (mnt.waitForStarted(2000) && mnt.waitForFinished(8000)
                    && mnt.exitCode() == 0) {
                QFileInfo fi(punto);
                if (fi.exists() && fi.isWritable())
                    return punto;
            }
        }
    }
    return QString();
#else
    return QString();
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
// Watchdogs
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::resetWatchdogSerial()
{
    setAlertaSerial(false);
    if (m_puerto.isOpen() && m_procesoActivo)
        m_timerWatchdogSerial.start();
}

void GestorBiorreactor::onWatchdogSerialTimeout()
{
    qWarning() << "[WD-Serial] Sin datos por 3 s, intentando reconectar...";
    setAlertaSerial(true);
    buscarYConectar(m_puerto.portName());
}

void GestorBiorreactor::onWatchdogI2CTimeout()
{
    qWarning() << "[WD-I2C] XM125 sin respuesta, intentando reiniciar...";
    setAlertaNivel(true);
    m_xm125.cerrar();
    m_xm125.inicializarCaracterizacion(1);   // reinit en el modo del seguidor (reset + 100-2000 mm)
    if (m_xm125.conectado()) {
        setAlertaNivel(false);
        resyncNivel();                        // re-armar el seguidor tras el reinicio del sensor
        m_timerWatchdogI2C.setInterval(2000);
    } else {
        m_timerWatchdogI2C.setInterval(10000);  // backoff: reintentar en 10 s
    }
    m_timerWatchdogI2C.start();
}

// ─────────────────────────────────────────────────────────────────────────────
// Cruce por cero — burst firing para el calentador
//
// callbackZC() corre en el hilo de pigpio. Solo encola el evento al hilo Qt.
// onCrucePorCero() corre en el hilo Qt y accede al PCA9685 de forma segura.
//
// Algoritmo (ventana de 100 semiciclos):
//   - Si salidaCalentador = 60 % → dispara los primeros 60 semiciclos, corta los 40 restantes
//   - Al llegar a 100, la ventana se reinicia
//   - Solo se escribe al PCA9685 cuando el estado (ON/OFF) cambia → mínimo tráfico I2C
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::callbackZC(int gpio, int level, uint32_t tick, void *userdata)
{
    Q_UNUSED(gpio) Q_UNUSED(tick)
    if (level != 1) return;   // solo flanco de subida
    QMetaObject::invokeMethod(
        static_cast<GestorBiorreactor *>(userdata),
        "onCrucePorCero",
        Qt::QueuedConnection);
}

void GestorBiorreactor::onCrucePorCero()
{
    ++m_zcDebug;   // DIAG: contar todos los cruces por cero (incluso sin proceso)
    if (!m_procesoActivo) {
        if (m_zcDisparando) {
            m_zcDisparando = false;
            m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR,   false);
            m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR_2, false);
        }
        m_zcContador = 0;
        m_zcTotal    = 0;
        return;
    }

    if (++m_zcTotal >= 100) {
        m_zcTotal    = 0;
        m_zcContador = 0;
    }

    bool disparar = (m_zcContador++ < static_cast<int>(m_salidaCalentador));

    if (disparar != m_zcDisparando) {
        m_zcDisparando = disparar;
        m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR,   disparar);
        m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR_2, disparar);
        m_zcReafirmar = 0;
    } else if (++m_zcReafirmar >= 30) {
        // Re-afirmar el estado cada ~30 cruces (~0.25 s): sana una escritura I2C perdida
        // que dejaría los canales del calentador desincronizados (apagados) para siempre.
        m_zcReafirmar = 0;
        m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR,   m_zcDisparando);
        m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR_2, m_zcDisparando);
    }
}

void GestorBiorreactor::verificarStaleness()
{
    const qint64 ahora = QDateTime::currentMSecsSinceEpoch();

    // Validez de datos (SIEMPRE, aun sin proceso): la GUI muestra "---" si el sensor
    // no entrega lecturas frescas (desconectado). RS-485 = temp/pH/DO; I2C = nivel.
    const bool serialFresco = m_ultimaLecturaRS485.isValid() &&
        (ahora - m_ultimaLecturaRS485.toMSecsSinceEpoch()) <= UMBRAL_STALENESS_MS;
    const bool nivelFresco  = m_ultimaLecturaI2C.isValid() &&
        (ahora - m_ultimaLecturaI2C.toMSecsSinceEpoch()) <= UMBRAL_STALENESS_MS;
    setSensorSerialValido(serialFresco);
    setSensorNivelValido(nivelFresco);

    // Alertas de proceso (solo con proceso activo) — comportamiento previo
    if (m_procesoActivo && !serialFresco) setAlertaSerial(true);
    if (m_procesoActivo && !nivelFresco)  setAlertaNivel(true);
}
