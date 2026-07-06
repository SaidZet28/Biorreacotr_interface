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
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#ifdef Q_OS_WIN
#include <windows.h>
#endif
#if defined(Q_OS_LINUX) && !defined(SIMULACION_ACTIVA)
#include <pigpio.h>
#endif

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
    m_xm125.inicializar(1);

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

// ─────────────────────────────────────────────────────────────────────────────
// Getters / Setters — Setpoints
// ─────────────────────────────────────────────────────────────────────────────

double GestorBiorreactor::setpointTem()   const { return m_setpointTem;   }
double GestorBiorreactor::setpointPH()    const { return m_setpointPH;    }
double GestorBiorreactor::nivelLlenadoPct() const { return NIVEL_LLENADO_PCT; }
double GestorBiorreactor::setpointLuz()   const { return m_setpointLuz;   }

void GestorBiorreactor::setSetpointTem(double v) {
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
        m_pca9685.escribirDigital   (DriverPCA9685::CH_BOMBA_VAC1, false);   // drenado off
        m_pca9685.escribirDigital   (DriverPCA9685::CH_BOMBA_VAC2, false);
        m_drenandoNivel = false;

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
    emit setpointTemChanged();
    emit setpointPHChanged();
    emit setpointLuzChanged();
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
        m_salidaBombaEtanol = 0.0;
        m_salidaBombaAgua   = 0.0;
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO,     0.0);
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
        m_salidaBombaNivel = false;
        m_pca9685.escribirDigital(DriverPCA9685::CH_TIRA_LED, false);
        emit salidaBombaNivelChanged();
    }
    emit histeresisNivelHabilitadoChanged();
}

// ─────────────────────────────────────────────────────────────────────────────
// Preparación del tanque — máquina de estados
// ─────────────────────────────────────────────────────────────────────────────

int     GestorBiorreactor::estadoPreparacion()     const { return m_estadoPreparacion; }
double  GestorBiorreactor::progresoPreparacion()   const { return m_progresoPreparacion; }
bool    GestorBiorreactor::preparacionCompletada() const { return m_preparacionCompletada; }
bool    GestorBiorreactor::alertaEscalacion()      const { return m_alertaEscalacion; }
double  GestorBiorreactor::litrosAgua()            const { return m_litrosAgua; }
double  GestorBiorreactor::mlSustanciaB()          const { return m_mlSustanciaB; }

QString GestorBiorreactor::textoTareaPreparacion() const
{
    switch (m_estadoPreparacion) {
    case 0:  return QCoreApplication::translate("Main", "Verificando el sistema...");
    case 1:  return QCoreApplication::translate("Main", "Llenando el tanque con la mezcla calculada...");
    case 2:  return QCoreApplication::translate("Main", "Estabilizando el sensor de pH...");
    case 3:  return QCoreApplication::translate("Main", "Acondicionando el medio de cultivo...");
    case 4:  return QCoreApplication::translate("Main", "Completando el llenado...");
    case 5:  return QCoreApplication::translate("Main", "Verificando estabilidad final...");
    case 6:  return QCoreApplication::translate("Main", "Tanque preparado");
    default: return QCoreApplication::translate("Main", "Iniciando...");
    }
}

QString GestorBiorreactor::textoDetallePreparacion() const
{
    switch (m_estadoPreparacion) {
    case 0:  return QCoreApplication::translate("Main", "Comprobando que las válvulas de drenaje estén cerradas y que todos los sensores estén disponibles.");
    case 1:  return QCoreApplication::translate("Main", "Se añade primero la sustancia B para ajustar el pH base, luego el agua completa el volumen. La temperatura se precalienta al mismo tiempo.");
    case 2:  return QCoreApplication::translate("Main", "El sensor de pH acaba de hacer contacto con el líquido. Se espera a que la lectura se estabilice antes de realizar ajustes de pH.");
    case 3:  return QCoreApplication::translate("Main", "Dosificando reactivos para alcanzar el pH deseado. El sistema de temperatura trabaja al mismo tiempo. Corregir el pH en poco volumen requiere menos reactivo.");
    case 4:  return QCoreApplication::translate("Main", "pH y temperatura en sus valores objetivo. Completando el llenado hasta el volumen de trabajo.");
    case 5:  return QCoreApplication::translate("Main", "Se confirma que las condiciones se mantienen estables antes de introducir el organismo.");
    case 6:  return QCoreApplication::translate("Main", "pH, temperatura y nivel en sus valores objetivo. El tanque está listo para recibir el organismo.");
    default: return QString();
    }
}

void GestorBiorreactor::setEstadoPreparacion(int estado)
{
    m_estadoPreparacion = estado;
    m_ticksPrep         = 0;
    m_contadorEstabPH   = 0;
    m_contadorEstabFino = 0;

    // Configurar controladores según el estado
    switch (estado) {
    case 1:
        if (!m_procesoActivo) { m_procesoActivo = true; emit procesoActivoChanged(); }
        habilitarFuzzyPH(false);
        habilitarHisteresisNivel(false);
        break;
    case 2:
        habilitarFuzzyPH(false);
        habilitarHisteresisNivel(false);
        break;
    case 3:
        habilitarFuzzyPH(true);
        habilitarHisteresisNivel(false);
        break;
    case 4:
        habilitarFuzzyPH(false);
        habilitarHisteresisNivel(false);
        break;
    case 5:
        habilitarFuzzyPH(true);
        habilitarHisteresisNivel(false);
        break;
    case 6:
        habilitarFuzzyPH(true);
        habilitarHisteresisNivel(true);
        setPreparacionCompletada(true);
        break;
    }

    // Progreso: proporción lineal entre estados (milestones fijos)
    static const double hitos[] = { 0.0, 0.15, 0.32, 0.48, 0.65, 0.82, 1.0 };
    setProgresoPreparacion(hitos[qBound(0, estado, 6)]);

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

void GestorBiorreactor::calcularMezclaOptima()
{
    const double vTotalL = VOLUMEN_TANQUE_L * (NIVEL_LLENADO_PCT / 100.0);
    if (vTotalL < 1e-6) {
        m_mlSustanciaB       = 0.0;
        m_litrosAgua         = 0.0;
        m_ticksDosificacionB = 0;
        emit mezclaCalculadaChanged();
        return;
    }

    if (m_setpointPH >= PH_SUSTANCIA_B)
        qWarning() << "[Mezcla] setpointPH" << m_setpointPH
                   << ">= PH_SUSTANCIA_B" << PH_SUSTANCIA_B
                   << "— pH objetivo inalcanzable con la sustancia configurada; se usará 100% sustancia B";

    // Concentraciones molares de OH⁻ (solución diluida)
    const double ohAgua = std::pow(10.0, PH_AGUA_DEFAULT - 14.0);
    const double ohB    = std::pow(10.0, PH_SUSTANCIA_B  - 14.0);
    const double ohObj  = std::pow(10.0, m_setpointPH    - 14.0);

    double fracB = 0.0;
    if (std::abs(ohB - ohAgua) > 1e-20)
        fracB = qBound(0.0, (ohObj - ohAgua) / (ohB - ohAgua), 1.0);

    m_mlSustanciaB       = vTotalL * fracB * 1000.0;
    m_litrosAgua         = vTotalL - (m_mlSustanciaB / 1000.0);
    m_ticksDosificacionB = static_cast<int>(std::ceil(m_mlSustanciaB / CAUDAL_BOMBA_B_ML_S));

    emit mezclaCalculadaChanged();
}

void GestorBiorreactor::iniciarPreparacion()
{
    // Bloquear solo si hay preparación activa en curso (estados 1-5).
    // Permite reiniciar desde -1 (nuevo experimento) o 6 (ciclo anterior completado).
    if (m_timerPreparacion.isActive() && m_estadoPreparacion > 0 && m_estadoPreparacion < 6) return;

    m_timerPreparacion.stop();
    calcularMezclaOptima();

    m_estadoPreparacion     = 0;
    m_ticksPrep             = 0;
    m_contadorEstabPH       = 0;
    m_contadorEstabFino     = 0;
    m_preparacionCompletada = false;
    m_alertaEscalacion      = false;
    m_progresoPreparacion   = 0.0;

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

void GestorBiorreactor::continuarDesdeEscalacion()
{
    setAlertaEscalacion(false);
    m_ticksPrep = 0;   // reinicia contador para dar otro intervalo completo
}

void GestorBiorreactor::tickPreparacion()
{
    m_ticksPrep++;

    switch (m_estadoPreparacion) {

    case 0: {
        // Verificar que los sensores respondan sin alertas activas
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 2) setEstadoPreparacion(1);
#else
        if (!m_alertaSerial && !m_alertaNivel) setEstadoPreparacion(1);
#endif
        break;
    }

    case 1: {
        // Llenado hasta que el nivel alcanza el sensor de pH
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 5) setEstadoPreparacion(2);
#else
        // Sub-fase A: dosificar sustancia B por tiempo calculado (primero)
        // Sub-fase B: llenar con agua hasta contacto del sensor de pH
        if (m_ticksDosificacionB > 0 && m_ticksPrep <= m_ticksDosificacionB) {
            if (!qFuzzyCompare(m_salidaBombaEtanol, 100.0)) {
                m_salidaBombaEtanol = 100.0;
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 100.0);
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 100.0);
                emit salidaBombaEtanolChanged();
            }
            if (!qFuzzyCompare(m_salidaBombaAgua, 0.0)) {
                m_salidaBombaAgua = 0.0;
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO, 0.0);
                emit salidaBombaAguaChanged();
            }
        } else {
            if (!qFuzzyCompare(m_salidaBombaEtanol, 0.0)) {
                m_salidaBombaEtanol = 0.0;
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
                emit salidaBombaEtanolChanged();
            }
            if (!qFuzzyCompare(m_salidaBombaAgua, 100.0)) {
                m_salidaBombaAgua = 100.0;
                m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO, 100.0);
                emit salidaBombaAguaChanged();
            }
        }
        if (m_sensorNivel >= NIVEL_CONTACTO_PH_PCT) {
            m_salidaBombaEtanol = 0.0;
            m_salidaBombaAgua   = 0.0;
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO,     0.0);
            emit salidaBombaEtanolChanged();
            emit salidaBombaAguaChanged();
            setEstadoPreparacion(2);
        }
#endif
        break;
    }

    case 2: {
#ifdef SIMULACION_ACTIVA
        // En simulación: tiempo fijo, sin depender de valores simulados
        if (m_ticksPrep >= 5) setEstadoPreparacion(3);
#else
        if (m_sensorPH >= 2.0 && m_sensorPH <= 12.0)
            m_contadorEstabPH++;
        else
            m_contadorEstabPH = 0;
        if (m_contadorEstabPH >= 5) setEstadoPreparacion(3);
#endif
        break;
    }

    case 3: {
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 8) setEstadoPreparacion(4);
#else
        bool phOk  = qAbs(m_sensorPH  - m_setpointPH)  <= 0.5;
        bool temOk = qAbs(m_sensorTem - m_setpointTem) <= 1.0;
        if (phOk && temOk) {
            setEstadoPreparacion(4);
        } else if (m_ticksPrep >= 120 && !m_alertaEscalacion) {
            setAlertaEscalacion(true);
        }
#endif
        break;
    }

    case 4: {
        // Llenado final con agua hasta setpointNivel (sustancia B ya fue dosificada en estado 1)
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 8) setEstadoPreparacion(5);
#else
        if (!qFuzzyCompare(m_salidaBombaAgua, 100.0)) {
            m_salidaBombaAgua = 100.0;
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO, 100.0);
            emit salidaBombaAguaChanged();
        }
        if (m_sensorNivel >= NIVEL_LLENADO_PCT) {
            m_salidaBombaAgua = 0.0;
            m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BURBUJEO, 0.0);
            emit salidaBombaAguaChanged();
            setEstadoPreparacion(5);
        }
#endif
        break;
    }

    case 5: {
#ifdef SIMULACION_ACTIVA
        if (m_ticksPrep >= 10) setEstadoPreparacion(6);
#else
        bool phOk  = qAbs(m_sensorPH  - m_setpointPH)  <= 0.5;
        bool temOk = qAbs(m_sensorTem - m_setpointTem) <= 1.0;
        if (phOk && temOk)
            m_contadorEstabFino++;
        else
            m_contadorEstabFino = 0;
        if (m_contadorEstabFino >= 30) setEstadoPreparacion(6);
#endif
        break;
    }

    case 6:
        // Esperando que el operador confirme la introducción del organismo
        break;
    }
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
        setAlertaDivergenciaTemp(qAbs(m_tempPH - m_tempDO) > 1.0);
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

    // Tick par: arrancar medición (no bloquea)
    if (m_nivelPaso == 0) {
        m_xm125.iniciarMedicion();
        m_nivelPaso = 1;
        return;
    }

    // Tick impar: leer resultado (no bloquea; -1 si aún no listo)
    m_nivelPaso = 0;
    double distMm = m_xm125.leerResultado();
    if (distMm < 0.0) {
        if (++m_fallosNivel >= 5) setAlertaNivel(true);
        return;
    }
    m_fallosNivel = 0;

    m_ultimaLecturaI2C = QDateTime::currentDateTime();
    m_timerWatchdogI2C.setInterval(2000);
    m_timerWatchdogI2C.start();

    m_distanciaNivelMm = distMm;   // guardar distancia cruda para la protección en mm

    double nivel = (DIST_VACIO_MM - distMm) / (DIST_VACIO_MM - DIST_LLENO_MM) * 100.0;
    nivel = std::clamp(nivel, 0.0, 100.0);
    setSensorNivel(nivel);

    // Protección de sobrellenado + alarma (histéresis en mm). También decide el
    // estado de alertaNivel en una lectura buena (alto = drenando, si no false).
    evaluarSeguridadNivel();
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

    const bool anterior = m_drenandoNivel;
    if (!m_drenandoNivel && m_distanciaNivelMm <= DIST_NIVEL_ALTO_MM)
        m_drenandoNivel = true;                                   // tanque lleno
    else if (m_drenandoNivel && m_distanciaNivelMm >= DIST_NIVEL_OBJETIVO_MM)
        m_drenandoNivel = false;                                  // drenado suficiente

    if (m_drenandoNivel) {
        // Mientras dure la alarma: forzar llenado OFF y drenado ON en cada lectura
        // (robusto ante otros lazos que intenten reactivar las bombas de llenado).
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_A, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_NEUT_B, 0.0);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, true);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, true);
    } else if (anterior) {
        // Transición alto→normal: apagar el drenado.
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC1, false);
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_VAC2, false);
    }

    if (m_drenandoNivel != anterior) {
        m_salidaBombaNivel = m_drenandoNivel;   // reutilizado: true = drenado activo
        emit salidaBombaNivelChanged();
    }

    setAlertaNivel(m_drenandoNivel);   // alarma de nivel alto (rojo en la GUI)
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer: loop de control (1 s)
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::ejecutarControlLoop()
{
    if (!m_procesoActivo) return;

    // PID + Feedforward — Temperatura → m_salidaCalentador (0-100 %)
    // La escritura al PCA9685 CH_CALENTADOR la gestiona onCrucePorCero() via burst firing.
    // En modo simulación (sin ZC), se escribe directamente al no haber callback.
    //
    // Feedforward: estimación de potencia de mantenimiento basada en modelo FOPDT
    //   Planta: K=0.6291 °C/%, τ=23088 s, θ=204 s (identificado 2026-07, sin burbujeo)
    //   u_ff = (SP - T_amb) / K  →  pre-carga la salida en estado estacionario
    static constexpr double K_PLANTA_TEMP = 0.6291;  // °C/%
    double u_ff  = qBound(0.0, (m_setpointTem - m_tAmbiente) / K_PLANTA_TEMP, 100.0);
    double u_pid = m_pidTemp.calcular(m_setpointTem, m_sensorTem);
    double nuevoCalentador = qBound(0.0, u_ff + u_pid, 100.0);
    if (!qFuzzyCompare(m_salidaCalentador, nuevoCalentador)) {
        m_salidaCalentador = nuevoCalentador;
#ifdef SIMULACION_ACTIVA
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_CALENTADOR, m_salidaCalentador);
#endif
        emit salidaCalentadorChanged();
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
                                      && (m_sensorNivel < m_nivelMaxPct)
                                      && !m_drenandoNivel;   // no dosificar mientras se drena

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
    // Raspberry Pi OS
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
    m_xm125.inicializar(1);
    if (m_xm125.conectado()) {
        setAlertaNivel(false);
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
    if (!m_procesoActivo) {
        if (m_zcDisparando) {
            m_zcDisparando = false;
            m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR, false);
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
        m_pca9685.escribirDigital(DriverPCA9685::CH_CALENTADOR, disparar);
    }
}

void GestorBiorreactor::verificarStaleness()
{
    const qint64 ahora = QDateTime::currentMSecsSinceEpoch();

    // Si los datos RS-485 son viejos y hay proceso activo, activar alerta serial
    if (m_procesoActivo && m_ultimaLecturaRS485.isValid()) {
        qint64 edadRS485 = ahora - m_ultimaLecturaRS485.toMSecsSinceEpoch();
        if (edadRS485 > UMBRAL_STALENESS_MS)
            setAlertaSerial(true);
    }

    // Si los datos I2C son viejos y hay proceso activo, activar alerta nivel
    if (m_procesoActivo && m_ultimaLecturaI2C.isValid()) {
        qint64 edadI2C = ahora - m_ultimaLecturaI2C.toMSecsSinceEpoch();
        if (edadI2C > UMBRAL_STALENESS_MS)
            setAlertaNivel(true);
    }
}
