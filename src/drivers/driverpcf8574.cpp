#include "driverpcf8574.h"
#include <QDebug>

#ifdef Q_OS_LINUX
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#ifndef I2C_SLAVE
#define I2C_SLAVE 0x0703
#endif
#endif

DriverPCF8574::DriverPCF8574(QObject *parent) : QObject(parent) {}
DriverPCF8574::~DriverPCF8574() { cerrar(); }

bool DriverPCF8574::inicializar(int bus, int direccion)
{
#ifdef Q_OS_LINUX
    cerrar();
    QString dev = QString("/dev/i2c-%1").arg(bus);
    m_fd = open(dev.toLocal8Bit().constData(), O_RDWR);
    if (m_fd < 0) {
        qWarning() << "[PCF8574] No se pudo abrir" << dev;
        return false;
    }
    if (ioctl(m_fd, I2C_SLAVE, direccion) < 0) {
        qWarning() << "[PCF8574] ioctl I2C_SLAVE falló";
        ::close(m_fd); m_fd = -1;
        return false;
    }
    // Todos los pines en 1 → entradas con pull-up (cuasi-bidireccional)
    uint8_t todos = 0xFF;
    if (write(m_fd, &todos, 1) != 1) {
        qWarning() << "[PCF8574] No responde en" << Qt::hex << direccion;
        ::close(m_fd); m_fd = -1;
        return false;
    }
    qDebug() << "[PCF8574] Inicializado en" << Qt::hex << direccion;
    return true;
#else
    Q_UNUSED(bus) Q_UNUSED(direccion)
    return false;
#endif
}

void DriverPCF8574::cerrar()
{
#ifdef Q_OS_LINUX
    if (m_fd >= 0) { ::close(m_fd); m_fd = -1; }
#endif
}

uint8_t DriverPCF8574::leerPuerto(bool &ok)
{
    ok = false;
#ifdef Q_OS_LINUX
    if (m_fd < 0) return 0xFF;
    uint8_t valor = 0xFF;
    if (read(m_fd, &valor, 1) != 1) return 0xFF;
    ok = true;
    return valor;
#else
    return 0xFF;
#endif
}
