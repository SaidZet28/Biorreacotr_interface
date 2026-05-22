#include "driverpca9685.h"
#include "raspberrypi_config.h"
#include <QDebug>
#include <algorithm>

#ifdef Q_OS_LINUX
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#include <cmath>
#ifndef I2C_SLAVE
#define I2C_SLAVE 0x0703
#endif
#endif

static constexpr int     PCA9685_ADDR   = 0x40;
static constexpr uint8_t REG_MODE1      = 0x00;
static constexpr uint8_t REG_PRESCALE   = 0xFE;
static constexpr uint8_t REG_LED0_ON_L  = 0x06;

DriverPCA9685::DriverPCA9685(QObject *parent) : QObject(parent) {}

DriverPCA9685::~DriverPCA9685() { cerrar(); }

bool DriverPCA9685::inicializar(int bus, int frecuenciaHz)
{
#ifdef Q_OS_LINUX
    QString dev = QString("/dev/i2c-%1").arg(bus);
    m_fd = open(dev.toLocal8Bit().constData(), O_RDWR);
    if (m_fd < 0) {
        qWarning() << "[PCA9685] No se pudo abrir" << dev;
        return false;
    }
    if (ioctl(m_fd, I2C_SLAVE, PCA9685_ADDR) < 0) {
        qWarning() << "[PCA9685] ioctl I2C_SLAVE falló";
        ::close(m_fd); m_fd = -1;
        return false;
    }

    // Sleep para configurar prescaler (datasheet: esperar ≥500 µs antes de escribir PRESCALE)
    escribirRegistro(REG_MODE1, 0x10);
    usleep(500);

    uint8_t prescale = static_cast<uint8_t>(
        std::round(25000000.0 / (4096.0 * frecuenciaHz)) - 1);
    escribirRegistro(REG_PRESCALE, prescale);

    // Auto-increment + salir de sleep
    escribirRegistro(REG_MODE1, 0x20);
    usleep(500);
    escribirRegistro(REG_MODE1, 0xA0);

    qDebug() << "[PCA9685] Inicializado en" << dev << "— I2C bus" << PCA9685_I2C_BUS << "@" << frecuenciaHz << "Hz";
    return true;
#else
    Q_UNUSED(bus) Q_UNUSED(frecuenciaHz)
    qWarning() << "[PCA9685] Hardware I2C solo disponible en Linux (Raspberry Pi)";
    return false;
#endif
}

void DriverPCA9685::cerrar()
{
#ifdef Q_OS_LINUX
    if (m_fd >= 0) {
        for (int i = 0; i < 16; ++i) escribirCanal(i, 0);
        ::close(m_fd);
        m_fd = -1;
        qDebug() << "[PCA9685] Cerrado";
    }
#endif
}

void DriverPCA9685::escribirCanal(int canal, int valor)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return;
    canal = std::clamp(canal, 0, 15);
    valor = std::clamp(valor, 0, 4095);

    uint8_t reg = static_cast<uint8_t>(REG_LED0_ON_L + canal * 4);
    uint8_t buf[5] = {
        reg, 0x00, 0x00,
        static_cast<uint8_t>(valor & 0xFF),
        static_cast<uint8_t>(valor >> 8)
    };
    if (write(m_fd, buf, 5) != 5)
        qWarning() << "[PCA9685] Error escribiendo canal" << canal;
#else
    Q_UNUSED(canal) Q_UNUSED(valor)
#endif
}

void DriverPCA9685::escribirPorcentaje(int canal, double porcentaje)
{
    escribirCanal(canal, static_cast<int>(
        std::clamp(porcentaje, 0.0, 100.0) / 100.0 * 4095.0));
}

void DriverPCA9685::escribirDigital(int canal, bool activo)
{
    escribirCanal(canal, activo ? 4095 : 0);
}

void DriverPCA9685::escribirRegistro(uint8_t reg, uint8_t valor)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return;
    uint8_t buf[2] = {reg, valor};
    if (write(m_fd, buf, 2) != 2)
        qWarning() << "[PCA9685] Error escribiendo registro" << Qt::hex << (int)reg;
#else
    Q_UNUSED(reg) Q_UNUSED(valor)
#endif
}
