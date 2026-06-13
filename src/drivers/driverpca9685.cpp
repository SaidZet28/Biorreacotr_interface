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
#include <pigpio.h>
#ifndef I2C_SLAVE
#define I2C_SLAVE 0x0703
#endif
#endif

static constexpr int     PCA9685_ADDR  = 0x40;
static constexpr uint8_t REG_MODE1     = 0x00;
static constexpr uint8_t REG_PRESCALE  = 0xFE;
static constexpr uint8_t REG_LED0_ON_L = 0x06;

// ── ZeroCrossWorker ───────────────────────────────────────────────────────────
// Corre en hilo de alta prioridad. En cada ZC (GPIO27 sube a 1):
//   1. OE → HIGH  (deshabilita salidas PWM brevemente)
//   2. espera 50 µs
//   3. OE → LOW   (re-habilita, ahora alineado con el cruce de AC)
// Esto sincroniza el PWM del PCA9685 con la fase de la red eléctrica.
void ZeroCrossWorker::process()
{
#ifdef Q_OS_LINUX
    while (running) {
        if (gpioRead(GPIO_ZERO_CROSS) == 1) {
            gpioWrite(GPIO_OE_PCA9685, 1);
            gpioDelay(50);
            gpioWrite(GPIO_OE_PCA9685, 0);
        }
        gpioDelay(100);   // muestrear cada 100 µs (semiciclo 60Hz = 8333 µs)
    }
#endif
    emit finished();
}

// ── Constructor / Destructor ──────────────────────────────────────────────────
DriverPCA9685::DriverPCA9685(QObject *parent) : QObject(parent) {}
DriverPCA9685::~DriverPCA9685() { cerrar(); }

// ── inicializar ───────────────────────────────────────────────────────────────
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

    // Inicializar pigpio y configurar pines GPIO
    if (gpioInitialise() < 0) {
        qWarning() << "[PCA9685] pigpio init falló — sin control de OE/ZC";
    } else {
        gpioSetMode(GPIO_OE_PCA9685,  PI_OUTPUT);
        gpioSetMode(GPIO_ZERO_CROSS,  PI_INPUT);
        gpioWrite(GPIO_OE_PCA9685, 1);   // salidas deshabilitadas mientras se configura
    }

    // Configurar PCA9685: sleep → prescaler → despertar
    escribirRegistro(REG_MODE1, 0x10);   // SLEEP
    usleep(500);
    uint8_t prescale = static_cast<uint8_t>(
        std::round(25000000.0 / (4096.0 * frecuenciaHz)) - 1);
    escribirRegistro(REG_PRESCALE, prescale);
    escribirRegistro(REG_MODE1, 0x20);   // AUTO-INCREMENT, salir de SLEEP
    usleep(500);
    escribirRegistro(REG_MODE1, 0xA0);   // RESTART + AUTO-INCREMENT

    gpioWrite(GPIO_OE_PCA9685, 0);       // habilitar salidas PWM
    qDebug() << "[PCA9685] Inicializado en" << dev << "@" << frecuenciaHz
             << "Hz (prescaler=" << prescale << ")";

    // Arrancar hilo de cruce por cero (alta prioridad, mismo ciclo de vida que el driver)
    m_zcWorker = new ZeroCrossWorker();
    m_zcThread = new QThread(this);
    m_zcWorker->moveToThread(m_zcThread);

    connect(m_zcThread, &QThread::started,      m_zcWorker, &ZeroCrossWorker::process);
    connect(m_zcWorker, &ZeroCrossWorker::finished, m_zcWorker, &QObject::deleteLater);
    connect(m_zcWorker, &ZeroCrossWorker::finished, m_zcThread, &QThread::quit);

    m_zcThread->start(QThread::HighestPriority);
    qDebug() << "[PCA9685] Hilo ZC arrancado (GPIO" << GPIO_ZERO_CROSS << ")";
    return true;
#else
    Q_UNUSED(bus) Q_UNUSED(frecuenciaHz)
    qWarning() << "[PCA9685] Hardware I2C solo disponible en Linux (Raspberry Pi)";
    return false;
#endif
}

// ── cerrar ────────────────────────────────────────────────────────────────────
void DriverPCA9685::cerrar()
{
#ifdef Q_OS_LINUX
    if (m_fd < 0) return;

    // Detener hilo ZC ANTES de cerrar pigpio
    if (m_zcWorker) {
        m_zcWorker->stop();
        m_zcThread->quit();
        m_zcThread->wait(2000);
        // m_zcWorker fue eliminado por deleteLater al emitir finished()
        m_zcWorker = nullptr;
        m_zcThread = nullptr;
    }

    gpioWrite(GPIO_OE_PCA9685, 1);          // deshabilitar salidas
    for (int i = 0; i < 16; ++i) escribirCanal(i, 0);
    ::close(m_fd);
    m_fd = -1;
    gpioTerminate();
    qDebug() << "[PCA9685] Cerrado";
#endif
}

// ── habilitarSalidas ──────────────────────────────────────────────────────────
void DriverPCA9685::habilitarSalidas(bool activo)
{
#ifdef Q_OS_LINUX
    gpioWrite(GPIO_OE_PCA9685, activo ? 0 : 1);
#else
    Q_UNUSED(activo)
#endif
}

// ── escribirCanal ─────────────────────────────────────────────────────────────
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

// ── escribirPorcentaje ────────────────────────────────────────────────────────
void DriverPCA9685::escribirPorcentaje(int canal, double porcentaje)
{
    escribirCanal(canal, static_cast<int>(
        std::clamp(porcentaje, 0.0, 100.0) / 100.0 * 4095.0));
}

// ── escribirDigital ───────────────────────────────────────────────────────────
void DriverPCA9685::escribirDigital(int canal, bool activo)
{
    escribirCanal(canal, activo ? 4095 : 0);
}

// ── escribirRegistro (privado) ────────────────────────────────────────────────
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
