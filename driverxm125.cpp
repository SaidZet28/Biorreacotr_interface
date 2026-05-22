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

static constexpr int XM125_ADDR = 0x52;
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

    // Verificar presencia del sensor leyendo el Product ID (registro 32-bit)
    uint32_t productId = 0;
    if (!leerRegistro(REG_PRODUCT_ID, productId)) {
        qWarning() << "[XM125] No responde en la dirección 0x52";
        ::close(m_fd); m_fd = -1;
        return false;
    }

    qDebug() << "[XM125] Conectado en" << dev << "— Product ID =" << Qt::hex << productId;
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

bool DriverXM125::iniciarMedicion()
{
#ifdef Q_OS_LINUX
    return escribirRegistro(REG_MEASURE_START, 0x01);
#else
    return false;
#endif
}

double DriverXM125::leerResultado()
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return -1.0;
    uint32_t status = 0;
    if (!leerRegistro(REG_STATUS, status) || !(status & 0x01))
        return -1.0;   // medición aún no lista
    uint32_t dist = 0;
    if (!leerRegistro(REG_DISTANCE, dist)) return -1.0;
    return static_cast<double>(dist);
#else
    return -1.0;
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
// Protocolo I2C SparkFun XM125:
//   Escritura: [addr_hi, addr_lo, val_b3, val_b2, val_b1, val_b0]  (6 bytes)
//   Lectura:   write [addr_hi, addr_lo] (2 bytes), luego read [b3,b2,b1,b0] (4 bytes)
// ─────────────────────────────────────────────────────────────────────────────

bool DriverXM125::escribirRegistro(uint16_t reg, uint32_t valor)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return false;
    uint8_t buf[6] = {
        static_cast<uint8_t>(reg   >> 8),
        static_cast<uint8_t>(reg   & 0xFF),
        static_cast<uint8_t>(valor >> 24),
        static_cast<uint8_t>((valor >> 16) & 0xFF),
        static_cast<uint8_t>((valor >>  8) & 0xFF),
        static_cast<uint8_t>( valor        & 0xFF)
    };
    return write(m_fd, buf, 6) == 6;
#else
    Q_UNUSED(reg) Q_UNUSED(valor)
    return false;
#endif
}

bool DriverXM125::leerRegistro(uint16_t reg, uint32_t &valor)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return false;
    uint8_t addr[2] = {
        static_cast<uint8_t>(reg >> 8),
        static_cast<uint8_t>(reg & 0xFF)
    };
    if (write(m_fd, addr, 2) != 2) return false;
    uint8_t data[4] = {0, 0, 0, 0};
    if (read(m_fd, data, 4) != 4) return false;
    valor = (static_cast<uint32_t>(data[0]) << 24)
          | (static_cast<uint32_t>(data[1]) << 16)
          | (static_cast<uint32_t>(data[2]) <<  8)
          |  static_cast<uint32_t>(data[3]);
    return true;
#else
    Q_UNUSED(reg) Q_UNUSED(valor)
    return false;
#endif
}
