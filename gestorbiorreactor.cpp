#include "gestorbiorreactor.h"
#include <QSettings>
#include <QCoreApplication>
#include <QtMath>
#include <QSerialPortInfo>
#include <QDebug>

static const QString INI_PATH = QCoreApplication::applicationDirPath() + "/biorreactor.ini";

GestorBiorreactor::GestorBiorreactor(QObject *parent) : QObject(parent)
{
    connect(&m_puerto, &QSerialPort::readyRead, this, &GestorBiorreactor::leerDatosSerial);
    cargarConfiguracion();
}

GestorBiorreactor::~GestorBiorreactor()
{
    if (m_puerto.isOpen())
        m_puerto.close();
    guardarConfiguracion();
}

// ── Sensores ──────────────────────────────────────────────────────────────

double GestorBiorreactor::sensorTem()  const { return m_sensorTem;  }
double GestorBiorreactor::sensorPH()   const { return m_sensorPH;   }
double GestorBiorreactor::sensorAgua() const { return m_sensorAgua; }
double GestorBiorreactor::sensorLuz()  const { return m_sensorLuz;  }
double GestorBiorreactor::sensorCO2()  const { return m_sensorCO2;  }
double GestorBiorreactor::sensorDO()   const { return m_sensorDO;   }

void GestorBiorreactor::setSensorTem(double value) {
    if (qFuzzyCompare(m_sensorTem, value)) return;
    m_sensorTem = value; emit sensorTemChanged();
}
void GestorBiorreactor::setSensorPH(double value) {
    if (qFuzzyCompare(m_sensorPH, value)) return;
    m_sensorPH = value; emit sensorPHChanged();
}
void GestorBiorreactor::setSensorAgua(double value) {
    if (qFuzzyCompare(m_sensorAgua, value)) return;
    m_sensorAgua = value; emit sensorAguaChanged();
}
void GestorBiorreactor::setSensorLuz(double value) {
    if (qFuzzyCompare(m_sensorLuz, value)) return;
    m_sensorLuz = value; emit sensorLuzChanged();
}
void GestorBiorreactor::setSensorCO2(double value) {
    if (qFuzzyCompare(m_sensorCO2, value)) return;
    m_sensorCO2 = value; emit sensorCO2Changed();
}
void GestorBiorreactor::setSensorDO(double value) {
    if (qFuzzyCompare(m_sensorDO, value)) return;
    m_sensorDO = value; emit sensorDOChanged();
}

// ── Setpoints ─────────────────────────────────────────────────────────────

double GestorBiorreactor::setpointTem()  const { return m_setpointTem;  }
double GestorBiorreactor::setpointPH()   const { return m_setpointPH;   }
double GestorBiorreactor::setpointAgua() const { return m_setpointAgua; }
double GestorBiorreactor::setpointLuz()  const { return m_setpointLuz;  }
double GestorBiorreactor::setpointCO2()  const { return m_setpointCO2;  }

void GestorBiorreactor::setSetpointTem(double value) {
    if (qFuzzyCompare(m_setpointTem, value)) return;
    m_setpointTem = value; emit setpointTemChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointPH(double value) {
    if (qFuzzyCompare(m_setpointPH, value)) return;
    m_setpointPH = value; emit setpointPHChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointAgua(double value) {
    if (qFuzzyCompare(m_setpointAgua, value)) return;
    m_setpointAgua = value; emit setpointAguaChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointLuz(double value) {
    if (qFuzzyCompare(m_setpointLuz, value)) return;
    m_setpointLuz = value; emit setpointLuzChanged(); guardarConfiguracion();
}
void GestorBiorreactor::setSetpointCO2(double value) {
    if (qFuzzyCompare(m_setpointCO2, value)) return;
    m_setpointCO2 = value; emit setpointCO2Changed(); guardarConfiguracion();
}

// ── Persistencia ──────────────────────────────────────────────────────────

void GestorBiorreactor::cargarConfiguracion()
{
    QSettings settings(INI_PATH, QSettings::IniFormat);
    settings.beginGroup("Setpoints");
    m_setpointTem  = settings.value("temperatura", 0.0).toDouble();
    m_setpointPH   = settings.value("pH",          0.0).toDouble();
    m_setpointAgua = settings.value("agua",        0.0).toDouble();
    m_setpointLuz  = settings.value("luz",         0.0).toDouble();
    m_setpointCO2  = settings.value("CO2",         0.0).toDouble();
    settings.endGroup();
}

void GestorBiorreactor::guardarConfiguracion()
{
    QSettings settings(INI_PATH, QSettings::IniFormat);
    settings.beginGroup("Setpoints");
    settings.setValue("temperatura", m_setpointTem);
    settings.setValue("pH",          m_setpointPH);
    settings.setValue("agua",        m_setpointAgua);
    settings.setValue("luz",         m_setpointLuz);
    settings.setValue("CO2",         m_setpointCO2);
    settings.endGroup();
}

// ── Puerto serial ─────────────────────────────────────────────────────────

bool GestorBiorreactor::puertoConectado() const { return m_puerto.isOpen(); }
QString GestorBiorreactor::nombrePuerto() const { return m_puerto.portName(); }

bool GestorBiorreactor::buscarYConectar(const QString &nombreForzado)
{
    if (m_puerto.isOpen())
        m_puerto.close();

    QString portName;

    if (!nombreForzado.isEmpty()) {
        portName = nombreForzado;
    } else {
        const auto puertos = QSerialPortInfo::availablePorts();
        for (const QSerialPortInfo &info : puertos) {
            if (!info.portName().contains("Bluetooth", Qt::CaseInsensitive)) {
                portName = info.portName();
                break;
            }
        }
    }

    if (portName.isEmpty()) {
        qWarning() << "[Serial] No se encontró ningún puerto disponible";
        emit puertoConectadoChanged();
        emit nombrePuertoChanged();
        return false;
    }

    m_puerto.setPortName(portName);
    m_puerto.setBaudRate(QSerialPort::Baud115200);
    m_puerto.setDataBits(QSerialPort::Data8);
    m_puerto.setParity(QSerialPort::NoParity);
    m_puerto.setStopBits(QSerialPort::OneStop);
    m_puerto.setFlowControl(QSerialPort::NoFlowControl);

    if (!m_puerto.open(QIODevice::ReadWrite)) {
        qWarning() << "[Serial] No se pudo abrir" << portName << ":" << m_puerto.errorString();
        emit puertoConectadoChanged();
        emit nombrePuertoChanged();
        return false;
    }

    m_buffer.clear();
    qDebug() << "[Serial] Conectado a" << portName << "@ 115200";
    emit puertoConectadoChanged();
    emit nombrePuertoChanged();
    return true;
}

void GestorBiorreactor::desconectar()
{
    if (m_puerto.isOpen()) {
        m_puerto.close();
        m_buffer.clear();
        qDebug() << "[Serial] Puerto cerrado";
        emit puertoConectadoChanged();
        emit nombrePuertoChanged();
    }
}

// ── Slot: recepción de datos ──────────────────────────────────────────────

void GestorBiorreactor::leerDatosSerial()
{
    m_buffer += m_puerto.readAll();

    int idx;
    while ((idx = m_buffer.indexOf('\n')) != -1) {
        const QByteArray linea = m_buffer.left(idx).trimmed();
        m_buffer.remove(0, idx + 1);
        if (!linea.isEmpty())
            parsearTrama(linea);
    }
}

// ── Parser  T:24.5,P:7.2,A:85,L:60,C:400,D:8.2 ───────────────────────────

void GestorBiorreactor::parsearTrama(const QByteArray &linea)
{
    const QList<QByteArray> campos = linea.split(',');

    for (const QByteArray &campo : campos) {
        const int sep = campo.indexOf(':');
        if (sep == -1) continue;

        const QByteArray clave = campo.left(sep).trimmed().toUpper();
        bool ok = false;
        const double valor = campo.mid(sep + 1).trimmed().toDouble(&ok);
        if (!ok) continue;

        if      (clave == "T"   || clave == "TEM") setSensorTem(valor);
        else if (clave == "P"   || clave == "PH")  setSensorPH(valor);
        else if (clave == "A"   || clave == "AGUA") setSensorAgua(valor);
        else if (clave == "L"   || clave == "LUZ")  setSensorLuz(valor);
        else if (clave == "C"   || clave == "CO2")  setSensorCO2(valor);
        else if (clave == "D"   || clave == "DO")   setSensorDO(valor);
    }
}
