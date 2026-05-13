#include "sensordo.h"
#include <cstring>

SensorDO::SensorDO(QObject *parent) : QObject(parent)
{
    m_serial = new QSerialPort(this);
    m_serial->setPortName("COM3"); // Cambiar a /dev/ttyUSB0 en Raspberry Pi
    m_serial->setBaudRate(QSerialPort::Baud9600);
    m_serial->setDataBits(QSerialPort::Data8);
    m_serial->setParity(QSerialPort::NoParity);
    m_serial->setStopBits(QSerialPort::OneStop);
    m_serial->open(QIODevice::ReadWrite);

    m_stabilizationTimer = new QTimer(this);
    connect(m_stabilizationTimer, &QTimer::timeout, this, &SensorDO::onTimerTick);
    connect(m_serial, &QSerialPort::readyRead, this, &SensorDO::onReadyRead);
}

// ── CRC-16 Modbus RTU ────────────────────────────────────────────────────────

quint16 SensorDO::calculateCRC(const QByteArray &data)
{
    quint16 crc = 0xFFFF;
    for (int i = 0; i < data.size(); ++i) {
        crc ^= static_cast<quint8>(data.at(i));
        for (int j = 0; j < 8; ++j) {
            if (crc & 0x0001) crc = (crc >> 1) ^ 0xA001;
            else              crc >>= 1;
        }
    }
    return crc;
}

// ── Parseo de float IEEE 754 big-endian ──────────────────────────────────────

float SensorDO::parseBEFloat(const QByteArray &data, int offset)
{
    quint32 raw = (static_cast<quint8>(data[offset    ]) << 24) |
                  (static_cast<quint8>(data[offset + 1]) << 16) |
                  (static_cast<quint8>(data[offset + 2]) <<  8) |
                  (static_cast<quint8>(data[offset + 3]));
    float value;
    std::memcpy(&value, &raw, sizeof(float));
    return value;
}

// ── Lectura ──────────────────────────────────────────────────────────────────

void SensorDO::requestValue()
{
    // FC03: leer 6 registros desde 0x0000 → DO, saturación, temperatura
    QByteArray frame;
    frame.append(char(SLAVE_ID));
    frame.append(char(0x03));
    frame.append(char(0x00)); frame.append(char(0x00)); // reg inicio
    frame.append(char(0x00)); frame.append(char(0x06)); // cantidad

    quint16 crc = calculateCRC(frame);
    frame.append(static_cast<char>(crc & 0xFF));
    frame.append(static_cast<char>((crc >> 8) & 0xFF));

    m_serial->write(frame);
    emit logMessage("TX (Leer): " + frame.toHex(' '));
}

// ── Calibración ──────────────────────────────────────────────────────────────

void SensorDO::startStabilizationAir()
{
    m_pendingZeroCal = false;
    m_remainingTime  = 180;
    emit remainingTimeChanged();
    m_stabilizationTimer->start(1000);
    emit logMessage("Exponga el sensor al aire. Estabilizando 180 s...");
}

void SensorDO::startStabilizationZero()
{
    m_pendingZeroCal = true;
    m_remainingTime  = 180;
    emit remainingTimeChanged();
    m_stabilizationTimer->start(1000);
    emit logMessage("Sumerja en solución anaeróbica. Estabilizando 180 s...");
}

void SensorDO::onTimerTick()
{
    if (--m_remainingTime <= 0) {
        m_stabilizationTimer->stop();
        emit calibrationFinished();
        emit logMessage("Estabilización terminada. Puede calibrar.");
    }
    emit remainingTimeChanged();
}

void SensorDO::calibrateNow()
{
    // Air cal → reg 0x001A, valor 0x0001
    // Zero cal → reg 0x001C, valor 0x0001
    const char regHi = 0x00;
    const char regLo = m_pendingZeroCal ? char(0x1C) : char(0x1A);

    QByteArray frame;
    frame.append(char(SLAVE_ID));
    frame.append(char(0x06));       // FC06: write single register
    frame.append(regHi);
    frame.append(regLo);
    frame.append(char(0x00)); frame.append(char(0x01)); // valor

    quint16 crc = calculateCRC(frame);
    frame.append(static_cast<char>(crc & 0xFF));
    frame.append(static_cast<char>((crc >> 8) & 0xFF));

    m_lastSentFrame = frame;
    m_serial->write(frame);

    const QString tipo = m_pendingZeroCal ? "Cero O₂" : "Aire";
    emit logMessage("TX (Cal " + tipo + "): " + frame.toHex(' '));
}

// ── Recepción ────────────────────────────────────────────────────────────────

void SensorDO::onReadyRead()
{
    m_rxBuffer.append(m_serial->readAll());
    emit logMessage("RX: " + m_rxBuffer.toHex(' '));

    // Respuesta FC06: eco del frame enviado → calibración confirmada
    if (!m_lastSentFrame.isEmpty() && m_rxBuffer == m_lastSentFrame) {
        emit logMessage(">>> Calibración Exitosa.");
        m_lastSentFrame.clear();
        m_rxBuffer.clear();
        return;
    }

    // Respuesta FC03: 17 bytes con los 3 floats de medición
    if (m_rxBuffer.size() >= FC03_RESP_LEN) {
        const QByteArray resp = m_rxBuffer.left(FC03_RESP_LEN);

        // Validar encabezado: [slaveId][0x03][0x0C]
        if (static_cast<quint8>(resp[0]) == SLAVE_ID &&
            static_cast<quint8>(resp[1]) == 0x03      &&
            static_cast<quint8>(resp[2]) == 0x0C)
        {
            m_valueDO    = static_cast<double>(parseBEFloat(resp, 3));
            m_saturation = static_cast<double>(parseBEFloat(resp, 7));
            m_temperature= static_cast<double>(parseBEFloat(resp, 11));

            emit valueDOChanged();
            emit saturationChanged();
            emit temperatureChanged();

            emit logMessage(QString("DO: %1 mg/L  Sat: %2%  Temp: %3 °C")
                .arg(m_valueDO,    0, 'f', 2)
                .arg(m_saturation, 0, 'f', 1)
                .arg(m_temperature,0, 'f', 2));
        }

        m_rxBuffer.remove(0, FC03_RESP_LEN);
    }
}
