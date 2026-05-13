#include "SensorPH.h"

SensorPH::SensorPH(QObject *parent) : QObject(parent) {
    m_serial = new QSerialPort(this);
    m_serial->setPortName("COM3"); //Cambiar a dev para raspberry
    m_serial->setBaudRate(QSerialPort::Baud9600);
    m_serial->setDataBits(QSerialPort::Data8);
    m_serial->setParity(QSerialPort::NoParity);
    m_serial->setStopBits(QSerialPort::OneStop);
    m_serial->open(QIODevice::ReadWrite);

    m_stabilizationTimer = new QTimer(this);
    connect(m_stabilizationTimer, &QTimer::timeout, this, &SensorPH::onTimerTick);
    connect(m_serial, &QSerialPort::readyRead, this, &SensorPH::onReadyRead);
}

quint16 SensorPH::calculateCRC(const QByteArray &data) {
    quint16 crc = 0xFFFF;
    for (int i = 0; i < data.size(); ++i) {
        crc ^= static_cast<quint8>(data.at(i));
        for (int j = 0; j < 8; ++j) {
            if (crc & 0x0001) crc = (crc >> 1) ^ 0xA001;
            else crc >>= 1;
        }
    }
    return crc;
}

void SensorPH::startStabilization(int ph) {
    m_pendingPhPoint = ph;
    m_remainingTime = 180; // Requisito del manual
    emit remainingTimeChanged();
    m_stabilizationTimer->start(1000);
    emit logMessage(QString("Sumerja en pH %1. Estabilizando...").arg(ph));
}

void SensorPH::onTimerTick() {
    if (--m_remainingTime <= 0) {
        m_stabilizationTimer->stop();
        emit calibrationFinished();
        emit logMessage("Estabilización terminada. Puede calibrar.");
    }
    emit remainingTimeChanged();
}

void SensorPH::calibrateNow() {
    QByteArray frame;
    frame.append(char(m_slaveId));
    frame.append(char(0x06));      // Función de escritura
    frame.append(char(0x00)); frame.append(char(0x55)); // Registro
    frame.append(char(0x00));

    if(m_pendingPhPoint == 4) frame.append(char(0x04));
    else if(m_pendingPhPoint == 7) frame.append(char(0x07));
    else if(m_pendingPhPoint == 10) frame.append(char(0x0A));

    quint16 crc = calculateCRC(frame); //
    frame.append(static_cast<char>(crc & 0xFF));
    frame.append(static_cast<char>((crc >> 8) & 0xFF));

    m_lastSentFrame = frame; //
    m_serial->write(frame);
    emit logMessage("TX: " + frame.toHex(' '));
}

void SensorPH::onReadyRead() {
    QByteArray response = m_serial->readAll();
    emit logMessage("RX: " + response.toHex(' '));

    // Validación de eco para confirmar éxito de calibración
    if (response == m_lastSentFrame && !m_lastSentFrame.isEmpty()) {
        emit logMessage(">>> Calibración Exitosa.");
        m_lastSentFrame.clear();
    }
}

void SensorPH::requestValue() {
    QByteArray frame;
    frame.append(char(m_slaveId));
    frame.append(char(0x03)); // Función lectura
    frame.append(char(0x00)); frame.append(char(0x00));
    frame.append(char(0x00)); frame.append(char(0x06));

    quint16 crc = calculateCRC(frame);
    frame.append(static_cast<char>(crc & 0xFF));
    frame.append(static_cast<char>((crc >> 8) & 0xFF));

    m_serial->write(frame);
    emit logMessage("TX (Leer): " + frame.toHex(' '));
}
