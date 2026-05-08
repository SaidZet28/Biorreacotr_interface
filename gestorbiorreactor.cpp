#include "gestorbiorreactor.h"
#include <QSettings>
#include <QCoreApplication>
#include <QtMath>

static const QString INI_PATH = QCoreApplication::applicationDirPath() + "/biorreactor.ini";

GestorBiorreactor::GestorBiorreactor(QObject *parent) : QObject(parent)
{
    cargarConfiguracion();
}

GestorBiorreactor::~GestorBiorreactor()
{
    guardarConfiguracion();
}

// ── Sensores ──────────────────────────────────────────────────────────────

double GestorBiorreactor::sensorAgua() const { return m_sensorAgua; }
double GestorBiorreactor::sensorLuz()  const { return m_sensorLuz;  }
double GestorBiorreactor::sensorCO2()  const { return m_sensorCO2;  }
double GestorBiorreactor::sensorDO()   const { return m_sensorDO;   }

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
