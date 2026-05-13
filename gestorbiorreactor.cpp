#include "gestorbiorreactor.h"
#include <QSettings>
#include <QCoreApplication>
#include <QSerialPortInfo>
#include <QDebug>
#include <QtMath>
#include <algorithm>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

static QString iniPath() {
    return QCoreApplication::applicationDirPath() + "/biorreactor.ini";
}

// Umbral de staleness: si no hay datos en 5 s, la alerta se activa
static constexpr int UMBRAL_STALENESS_MS = 5000;

// ─────────────────────────────────────────────────────────────────────────────
// Constructor / Destructor
// ─────────────────────────────────────────────────────────────────────────────

GestorBiorreactor::GestorBiorreactor(QObject *parent) : QObject(parent)
{
    // Configurar controladores
    m_pidTemp.configurar(2.0, 0.5, 0.1, 1.0, 0.0, 100.0);
    m_histeresisNivel.configurar(5.0);

    // Serial
    connect(&m_puerto, &QSerialPort::readyRead,
            this, &GestorBiorreactor::leerDatosSerial);

    // Timer RS-485: alterna consulta pH / DO cada 500 ms
    connect(&m_timerRS485, &QTimer::timeout,
            this, &GestorBiorreactor::consultarSensoresRS485);
    m_timerRS485.setInterval(500);
    m_timerRS485.start();

    // Timer loop de control: 1 s
    connect(&m_timerControlLoop, &QTimer::timeout,
            this, &GestorBiorreactor::ejecutarControlLoop);
    m_timerControlLoop.setInterval(1000);
    m_timerControlLoop.start();

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

    // Timer staleness: revisa cada 1 s
    connect(&m_timerStaleness, &QTimer::timeout,
            this, &GestorBiorreactor::verificarStaleness);
    m_timerStaleness.setInterval(1000);
    m_timerStaleness.start();

    // Timer nivel: lee XM125 cada 500 ms
    connect(&m_timerNivel, &QTimer::timeout,
            this, &GestorBiorreactor::leerSensorNivel);
    m_timerNivel.setInterval(500);
    m_timerNivel.start();

    // Inicializar hardware (solo funciona en Linux / RPi)
    m_pca9685.inicializar(1, 50);
    m_xm125.inicializar(1);

    // Cargar setpoints y conectar puerto
    cargarConfiguracion();
    buscarYConectar();
}

GestorBiorreactor::~GestorBiorreactor()
{
    if (m_procesoActivo) {
        // Estado seguro: apagar todos los actuadores
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_CALENTADOR,   0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_ETANOL, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_AGUA,   0.0);
        m_pca9685.escribirDigital   (DriverPCA9685::CH_BOMBA_NIVEL,  false);
    }
    if (m_puerto.isOpen()) m_puerto.close();
    guardarConfiguracion();
}

// ─────────────────────────────────────────────────────────────────────────────
// Getters / Setters — Sensores
// ─────────────────────────────────────────────────────────────────────────────

double GestorBiorreactor::sensorTem()   const { return m_sensorTem;   }
double GestorBiorreactor::sensorPH()    const { return m_sensorPH;    }
double GestorBiorreactor::sensorNivel() const { return m_sensorNivel; }
double GestorBiorreactor::sensorLuz()   const { return m_sensorLuz;   }
double GestorBiorreactor::sensorCO2()   const { return m_sensorCO2;   }
double GestorBiorreactor::sensorDO()    const { return m_sensorDO;    }

void GestorBiorreactor::setSensorTem(double v) {
    if (qFuzzyCompare(m_sensorTem, v)) return;
    m_sensorTem = v; emit sensorTemChanged();
}
void GestorBiorreactor::setSensorPH(double v) {
    if (qFuzzyCompare(m_sensorPH, v)) return;
    m_sensorPH = v; emit sensorPHChanged();
}
void GestorBiorreactor::setSensorNivel(double v) {
    if (qFuzzyCompare(m_sensorNivel, v)) return;
    m_sensorNivel = v; emit sensorNivelChanged();
}
void GestorBiorreactor::setSensorLuz(double v) {
    if (qFuzzyCompare(m_sensorLuz, v)) return;
    m_sensorLuz = v; emit sensorLuzChanged();
}
void GestorBiorreactor::setSensorCO2(double v) {
    if (qFuzzyCompare(m_sensorCO2, v)) return;
    m_sensorCO2 = v; emit sensorCO2Changed();
}
void GestorBiorreactor::setSensorDO(double v) {
    if (qFuzzyCompare(m_sensorDO, v)) return;
    m_sensorDO = v; emit sensorDOChanged();
}

// ─────────────────────────────────────────────────────────────────────────────
// Getters / Setters — Setpoints
// ─────────────────────────────────────────────────────────────────────────────

double GestorBiorreactor::setpointTem()   const { return m_setpointTem;   }
double GestorBiorreactor::setpointPH()    const { return m_setpointPH;    }
double GestorBiorreactor::setpointNivel() const { return m_setpointNivel; }
double GestorBiorreactor::setpointLuz()   const { return m_setpointLuz;   }
double GestorBiorreactor::setpointCO2()   const { return m_setpointCO2;   }

void GestorBiorreactor::setSetpointTem(double v) {
    if (qFuzzyCompare(m_setpointTem, v)) return;
    m_setpointTem = v; emit setpointTemChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointPH(double v) {
    if (qFuzzyCompare(m_setpointPH, v)) return;
    m_setpointPH = v; emit setpointPHChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointNivel(double v) {
    if (qFuzzyCompare(m_setpointNivel, v)) return;
    m_setpointNivel = v; emit setpointNivelChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointLuz(double v) {
    if (qFuzzyCompare(m_setpointLuz, v)) return;
    m_setpointLuz = v; emit setpointLuzChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointCO2(double v) {
    if (qFuzzyCompare(m_setpointCO2, v)) return;
    m_setpointCO2 = v; emit setpointCO2Changed(); guardarConfiguracion();
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

    if (!activo) {
        // Estado seguro al detener: apagar actuadores y reiniciar controladores
        m_pidTemp.reiniciar();
        m_histeresisNivel.reiniciar();
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_CALENTADOR,   0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_ETANOL, 0.0);
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_AGUA,   0.0);
        m_pca9685.escribirDigital   (DriverPCA9685::CH_BOMBA_NIVEL,  false);
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

double GestorBiorreactor::salidaCalentador()  const { return m_salidaCalentador;  }
double GestorBiorreactor::salidaBombaEtanol() const { return m_salidaBombaEtanol; }
double GestorBiorreactor::salidaBombaAgua()   const { return m_salidaBombaAgua;   }
bool   GestorBiorreactor::salidaBombaNivel()  const { return m_salidaBombaNivel;  }

// ─────────────────────────────────────────────────────────────────────────────
// Persistencia
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::cargarConfiguracion()
{
    QSettings s(iniPath(), QSettings::IniFormat);
    s.beginGroup("Setpoints");
    m_setpointTem   = s.value("temperatura", 0.0).toDouble();
    m_setpointPH    = s.value("pH",          0.0).toDouble();
    m_setpointNivel = s.value("nivel",       0.0).toDouble();
    m_setpointLuz   = s.value("luz",         0.0).toDouble();
    m_setpointCO2   = s.value("CO2",         0.0).toDouble();
    s.endGroup();
}

void GestorBiorreactor::guardarConfiguracion()
{
    QSettings s(iniPath(), QSettings::IniFormat);
    s.beginGroup("Setpoints");
    s.setValue("temperatura", m_setpointTem);
    s.setValue("pH",          m_setpointPH);
    s.setValue("nivel",       m_setpointNivel);
    s.setValue("luz",         m_setpointLuz);
    s.setValue("CO2",         m_setpointCO2);
    s.endGroup();
}

// ─────────────────────────────────────────────────────────────────────────────
// Persistencia JSON de modelos QML
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::guardarModelo(const QString &nombre, const QVariantList &datos)
{
    QJsonArray arr;
    for (const QVariant &v : datos)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    QFile f(QCoreApplication::applicationDirPath() + "/" + nombre + ".json");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

QVariantList GestorBiorreactor::cargarModelo(const QString &nombre)
{
    QFile f(QCoreApplication::applicationDirPath() + "/" + nombre + ".json");
    if (!f.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    QVariantList result;
    for (const QJsonValue &v : doc.array())
        result.append(v.toObject().toVariantMap());
    return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Puerto serial
// ─────────────────────────────────────────────────────────────────────────────

bool GestorBiorreactor::puertoConectado() const { return m_puerto.isOpen(); }
QString GestorBiorreactor::nombrePuerto() const { return m_puerto.portName(); }

bool GestorBiorreactor::buscarYConectar(const QString &nombreForzado)
{
    if (m_puerto.isOpen()) m_puerto.close();

    QString portName = nombreForzado;
    if (portName.isEmpty()) {
        for (const QSerialPortInfo &info : QSerialPortInfo::availablePorts()) {
            if (!info.portName().contains("Bluetooth", Qt::CaseInsensitive)) {
                portName = info.portName();
                break;
            }
        }
    }
    if (portName.isEmpty()) {
        qWarning() << "[Serial] Sin puertos disponibles";
        emit puertoConectadoChanged(); emit nombrePuertoChanged();
        return false;
    }

    m_puerto.setPortName(portName);
    m_puerto.setBaudRate(QSerialPort::Baud115200);
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
    resetWatchdogSerial();

    int idx;
    while ((idx = m_buffer.indexOf('\n')) != -1) {
        QByteArray linea = m_buffer.left(idx).trimmed();
        m_buffer.remove(0, idx + 1);
        if (!linea.isEmpty())
            parsearTrama(linea);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parser — soporta:
//   Formato antiguo:  T:24.5,P:7.2,L:60,C:400  (sin prefijo)
//   Sensor pH RS-485: PH:T:24.5,P:7.2           (prefijo PH:)
//   Sensor DO RS-485: DO:T:24.8,D:8.5           (prefijo DO:)
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::parsearTrama(const QByteArray &linea)
{
    const QByteArray upper = linea.toUpper();

    // Determinar fuente
    QByteArray payload = linea;
    bool esPH = false, esDO = false;

    if (upper.startsWith("PH:")) {
        payload = linea.mid(3);
        esPH = true;
        m_ultimaLecturaRS485 = QDateTime::currentDateTime();
    } else if (upper.startsWith("DO:")) {
        payload = linea.mid(3);
        esDO = true;
        m_ultimaLecturaRS485 = QDateTime::currentDateTime();
    } else {
        m_ultimaLecturaRS485 = QDateTime::currentDateTime();
    }

    for (const QByteArray &campo : payload.split(',')) {
        const int sep = campo.indexOf(':');
        if (sep == -1) continue;

        const QByteArray clave = campo.left(sep).trimmed().toUpper();
        bool ok = false;
        const double valor = campo.mid(sep + 1).trimmed().toDouble(&ok);
        if (!ok) continue;

        if (esPH) {
            if (clave == "T") { m_tempPH = valor; m_tempPHValida = true; actualizarTemperaturaFusionada(); }
            else if (clave == "P" || clave == "PH") setSensorPH(valor);
        } else if (esDO) {
            if (clave == "T") { m_tempDO = valor; m_tempDOValida = true; actualizarTemperaturaFusionada(); }
            else if (clave == "D" || clave == "DO") setSensorDO(valor);
        } else {
            // Formato legacy: Luz, CO2 (temperatura ya no viene aquí)
            if      (clave == "L" || clave == "LUZ") setSensorLuz(valor);
            else if (clave == "C" || clave == "CO2") setSensorCO2(valor);
        }
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
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::consultarSensoresRS485()
{
    if (!m_puerto.isOpen()) return;

    if (m_turnoRS485 == 0)
        m_puerto.write("PH:?\n");
    else
        m_puerto.write("DO:?\n");

    m_turnoRS485 = (m_turnoRS485 + 1) % 2;
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer: leer sensor de nivel XM125 vía I2C
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::leerSensorNivel()
{
    if (!m_xm125.conectado()) return;

    double distMm = m_xm125.leerDistanciaMm();
    if (distMm < 0.0) return;

    m_ultimaLecturaI2C = QDateTime::currentDateTime();
    m_timerWatchdogI2C.start();   // reinicia el watchdog

    // Convertir distancia (mm) a porcentaje de nivel.
    // Ajustar DIST_VACIO y DIST_LLENO según geometría del biorreactor.
    constexpr double DIST_VACIO  = 400.0;  // mm cuando está vacío
    constexpr double DIST_LLENO  = 50.0;   // mm cuando está lleno
    double nivel = (DIST_VACIO - distMm) / (DIST_VACIO - DIST_LLENO) * 100.0;
    nivel = std::clamp(nivel, 0.0, 100.0);

    setSensorNivel(nivel);
    setAlertaNivel(false);
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer: loop de control (1 s)
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::ejecutarControlLoop()
{
    if (!m_procesoActivo) return;

    // PID — Temperatura → calentador
    double nuevoCalentador = m_pidTemp.calcular(m_setpointTem, m_sensorTem);
    if (!qFuzzyCompare(m_salidaCalentador, nuevoCalentador)) {
        m_salidaCalentador = nuevoCalentador;
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_CALENTADOR, m_salidaCalentador);
        emit salidaCalentadorChanged();
    }

    // Fuzzy — pH → bomba etanol + bomba agua
    auto [pEtanol, pAgua] = m_fuzzyPH.calcular(m_setpointPH, m_sensorPH);
    if (!qFuzzyCompare(m_salidaBombaEtanol, pEtanol)) {
        m_salidaBombaEtanol = pEtanol;
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_ETANOL, pEtanol);
        emit salidaBombaEtanolChanged();
    }
    if (!qFuzzyCompare(m_salidaBombaAgua, pAgua)) {
        m_salidaBombaAgua = pAgua;
        m_pca9685.escribirPorcentaje(DriverPCA9685::CH_BOMBA_AGUA, pAgua);
        emit salidaBombaAguaChanged();
    }

    // Histéresis — Nivel → bomba de nivel
    bool nuevoNivel = m_histeresisNivel.calcular(m_setpointNivel, m_sensorNivel);
    if (m_salidaBombaNivel != nuevoNivel) {
        m_salidaBombaNivel = nuevoNivel;
        m_pca9685.escribirDigital(DriverPCA9685::CH_BOMBA_NIVEL, nuevoNivel);
        emit salidaBombaNivelChanged();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Watchdogs
// ─────────────────────────────────────────────────────────────────────────────

void GestorBiorreactor::resetWatchdogSerial()
{
    setAlertaSerial(false);
    if (m_puerto.isOpen())
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
    qWarning() << "[WD-I2C] XM125 sin respuesta por 2 s, intentando reiniciar...";
    setAlertaNivel(true);
    m_xm125.cerrar();
    m_xm125.inicializar(1);
    if (m_xm125.conectado()) {
        setAlertaNivel(false);
        m_timerWatchdogI2C.start();
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

    // Si los datos I2C son viejos, activar alerta nivel
    if (m_ultimaLecturaI2C.isValid()) {
        qint64 edadI2C = ahora - m_ultimaLecturaI2C.toMSecsSinceEpoch();
        if (edadI2C > UMBRAL_STALENESS_MS)
            setAlertaNivel(true);
    }
}
