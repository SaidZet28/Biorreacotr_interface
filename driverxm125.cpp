#include "driverxm125.h"
#include <QDebug>

#ifdef Q_OS_LINUX
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#ifndef I2C_SLAVE
#define I2C_SLAVE 0x0703
#endif

// Registro map del XM125 (Acconeer A121, SparkFun Qwiic)
// Referencia: Acconeer XM125 Datasheet / SparkFun_XM125_Arduino_Library
static constexpr int     XM125_ADDR           = 0x52;
static constexpr uint8_t REG_PRODUCT_ID_MSB   = 0x00;
static constexpr uint8_t REG_MEASURE_START     = 0x0A; // escribe 1 para iniciar medición
static constexpr uint8_t REG_STATUS            = 0x0B; // bit 0 = listo
static constexpr uint8_t REG_DISTANCE_MSB      = 0x10; // distancia en mm (big-endian 2 bytes)
static constexpr uint8_t REG_DISTANCE_LSB      = 0x11;
#endif

DriverXM125::DriverXM125(QObject *parent) : QObject(parent) {}

DriverXM125::~DriverXM125() { cerrar(); }

bool DriverXM125::inicializar(int bus)
{
#ifdef Q_OS_LINUX
    QString dev = QString("/dev/i2c-%1").arg(bus);
    m_fd = open(dev.toLocal8Bit().constData(), O_RDWR);
    if (m_fd < 0) {
        qWarning() << "[XM125] No se pudo abrir" << dev;
        return false;
    }
    if (ioctl(m_fd, I2C_SLAVE, XM125_ADDR) < 0) {
        qWarning() << "[XM125] ioctl I2C_SLAVE falló";
        ::close(m_fd); m_fd = -1;
        return false;
    }

    // Verificar producto
    uint8_t id = 0;
    if (write(m_fd, &REG_PRODUCT_ID_MSB, 1) != 1 ||
        read(m_fd,  &id,                 1) != 1) {
        qWarning() << "[XM125] No responde en la dirección 0x52";
        ::close(m_fd); m_fd = -1;
        return false;
    }

    qDebug() << "[XM125] Conectado, ID =" << Qt::hex << id;
    return true;
#else
    Q_UNUSED(bus)
    qWarning() << "[XM125] Hardware I2C solo disponible en Linux (Raspberry Pi)";
    return false;
#endif
}

void DriverXM125::cerrar()
{
#ifdef Q_OS_LINUX
    if (m_fd >= 0) {
        ::close(m_fd);
        m_fd = -1;
        qDebug() << "[XM125] Cerrado";
    }
#endif
}

double DriverXM125::leerDistanciaMm()
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return -1.0;

    // Iniciar medición
    uint8_t cmd[2] = {REG_MEASURE_START, 0x01};
    if (write(m_fd, cmd, 2) != 2) return -1.0;

    // Esperar listo (máx 50 ms, poll cada 2 ms)
    for (int i = 0; i < 25; ++i) {
        usleep(2000);
        uint8_t status = 0;
        if (write(m_fd, &REG_STATUS, 1) == 1 &&
            read (m_fd, &status,     1) == 1 &&
            (status & 0x01)) break;
        if (i == 24) return -1.0;
    }

    // Leer distancia (2 bytes big-endian en mm)
    uint8_t buf[2] = {0, 0};
    if (write(m_fd, &REG_DISTANCE_MSB, 1) != 1) return -1.0;
    if (read (m_fd,  buf,              2) != 2) return -1.0;

    return static_cast<double>((buf[0] << 8) | buf[1]);
#else
    return -1.0;
#endif
}
