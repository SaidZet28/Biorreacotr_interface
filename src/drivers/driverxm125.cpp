#include "driverxm125.h"
#include <QDebug>
#include <climits>

#ifdef Q_OS_LINUX
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>

static constexpr uint16_t XM125_ADDR = 0x52;
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

    // Verificar presencia leyendo Product ID
    uint32_t productId = 0;
    if (!leerRegistro(REG_PRODUCT_ID, productId)) {
        qWarning() << "[XM125] Sin respuesta en 0x52";
        ::close(m_fd); m_fd = -1;
        return false;
    }
    qDebug() << "[XM125] Conectado en" << dev << "— Product ID =" << Qt::hex << productId;

    // Configurar rango 100..2000 mm
    escribirRegistro(REG_RANGE_START, 100);
    escribirRegistro(REG_RANGE_END,   2000);

    // Aplicar configuración y calibrar (bloqueante, ~1-2 s)
    if (!escribirRegistro(REG_COMMAND, CMD_APPLY_CONFIG_AND_CALIBRATE)) {
        qWarning() << "[XM125] Fallo al enviar APPLY_CONFIG_AND_CALIBRATE";
        ::close(m_fd); m_fd = -1;
        return false;
    }

    // Busy-wait: esperar que bit 31 (BUSY) de DETECTOR_STATUS sea 0
    for (int i = 0; i < 50; ++i) {
        usleep(100'000); // 100 ms
        uint32_t st = 0;
        if (leerRegistro(REG_DETECTOR_STATUS, st) && !(st & 0x80000000u)) {
            qDebug() << "[XM125] Calibración OK, STATUS =" << Qt::hex << st;
            return true;
        }
    }

    qWarning() << "[XM125] Timeout esperando fin de calibración";
    ::close(m_fd); m_fd = -1;
    return false;
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
    // cmd=2 dispara una medición de distancia (modo triggered, no continuo)
    return escribirRegistro(REG_COMMAND, CMD_MEASURE_DISTANCE);
#else
    return false;
#endif
}

double DriverXM125::leerResultado()
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return -1.0;

    // Verificar que el detector ya no está ocupado (bit 31 = BUSY)
    uint32_t status = 0;
    if (!leerRegistro(REG_DETECTOR_STATUS, status)) return -1.0;
    if (status & 0x80000000u) return -1.0; // medición en curso

    // DISTANCE_RESULT: bits[3:0] = num_distances, bits[31:16] = temperatura °C
    uint32_t result = 0;
    if (!leerRegistro(REG_DISTANCE_RESULT, result)) return -1.0;
    const int numDistances = static_cast<int>(result & 0x0Fu);
    if (numDistances <= 0) return -1.0; // sin objeto en rango

    // Los picos vienen ordenados por fuerza de señal, NO por distancia.
    // Para nivel de líquido necesitamos el objeto MÁS CERCANO (menor distancia),
    // que siempre será la superficie del líquido apuntando el sensor hacia abajo.
    uint32_t minDist = UINT32_MAX;
    for (int j = 0; j < numDistances; ++j) {
        uint32_t d = 0;
        if (leerRegistro(static_cast<uint16_t>(REG_PEAK_DIST_BASE + j), d) && d < minDist)
            minDist = d;
    }
    if (minDist == UINT32_MAX) return -1.0;
    return static_cast<double>(minDist);
#else
    return -1.0;
#endif
}

// ─────────────────────────────────────────────────────────────────────────────
// I/O I2C — protocolo XM125 (SparkFun/Acconeer, dir 0x52, big-endian 16-bit addr + 32-bit val)
//   Escritura: 6 bytes  [addr_hi, addr_lo, val_b3, val_b2, val_b1, val_b0]
//   Lectura:   write [addr_hi, addr_lo] con Repeated-Start, luego read [b3..b0]
//   Usa I2C_RDWR (no I2C_SLAVE) para no interferir con otros drivers del bus compartido.
// ─────────────────────────────────────────────────────────────────────────────

bool DriverXM125::escribirRegistro(uint16_t reg, uint32_t valor)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return false;
    uint8_t buf[6] = {
        static_cast<uint8_t>(reg   >>  8),
        static_cast<uint8_t>(reg        ),
        static_cast<uint8_t>(valor >> 24),
        static_cast<uint8_t>(valor >> 16),
        static_cast<uint8_t>(valor >>  8),
        static_cast<uint8_t>(valor      )
    };
    struct i2c_msg msg {};
    msg.addr  = XM125_ADDR;
    msg.flags = 0;
    msg.len   = 6;
    msg.buf   = buf;
    struct i2c_rdwr_ioctl_data xfer {};
    xfer.msgs  = &msg;
    xfer.nmsgs = 1;
    return ioctl(m_fd, I2C_RDWR, &xfer) >= 0;
#else
    Q_UNUSED(reg) Q_UNUSED(valor)
    return false;
#endif
}

bool DriverXM125::leerRegistro(uint16_t reg, uint32_t &valor)
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return false;
    uint8_t addrBuf[2] = { static_cast<uint8_t>(reg >> 8), static_cast<uint8_t>(reg) };
    uint8_t dataBuf[4] = {};
    struct i2c_msg msgs[2] {};
    msgs[0].addr  = XM125_ADDR; msgs[0].flags = 0;        msgs[0].len = 2; msgs[0].buf = addrBuf;
    msgs[1].addr  = XM125_ADDR; msgs[1].flags = I2C_M_RD; msgs[1].len = 4; msgs[1].buf = dataBuf;
    struct i2c_rdwr_ioctl_data xfer {};
    xfer.msgs  = msgs;
    xfer.nmsgs = 2;
    if (ioctl(m_fd, I2C_RDWR, &xfer) < 0) return false;
    valor = (static_cast<uint32_t>(dataBuf[0]) << 24)
          | (static_cast<uint32_t>(dataBuf[1]) << 16)
          | (static_cast<uint32_t>(dataBuf[2]) <<  8)
          |  static_cast<uint32_t>(dataBuf[3]);
    return true;
#else
    Q_UNUSED(reg) Q_UNUSED(valor)
    return false;
#endif
}
