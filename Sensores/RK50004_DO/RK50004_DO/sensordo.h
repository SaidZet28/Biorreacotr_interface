#ifndef SENSORDO_H
#define SENSORDO_H

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QByteArray>

class SensorDO : public QObject {
    Q_OBJECT

    Q_PROPERTY(int    remainingTime READ remainingTime NOTIFY remainingTimeChanged)
    Q_PROPERTY(double valueDO       READ valueDO       NOTIFY valueDOChanged)
    Q_PROPERTY(double saturation    READ saturation    NOTIFY saturationChanged)
    Q_PROPERTY(double temperature   READ temperature   NOTIFY temperatureChanged)

public:
    explicit SensorDO(QObject *parent = nullptr);

    // Lectura continua de DO, saturación y temperatura
    Q_INVOKABLE void requestValue();

    // Calibración en aire (uso normal): esperar 180 s → calibrateNow()
    Q_INVOKABLE void startStabilizationAir();

    // Calibración en cero O₂ (agua anaeróbica / nitrógeno, uso raro)
    Q_INVOKABLE void startStabilizationZero();

    // Envía el comando de calibración al sensor
    Q_INVOKABLE void calibrateNow();

    int    remainingTime() const { return m_remainingTime; }
    double valueDO()       const { return m_valueDO; }
    double saturation()    const { return m_saturation; }
    double temperature()   const { return m_temperature; }

    static quint16 calculateCRC(const QByteArray &data);

signals:
    void logMessage(QString msg);
    void remainingTimeChanged();
    void valueDOChanged();
    void saturationChanged();
    void temperatureChanged();
    void calibrationFinished();

private slots:
    void onReadyRead();
    void onTimerTick();

private:
    static float parseBEFloat(const QByteArray &data, int offset);

    QSerialPort *m_serial;
    QTimer      *m_stabilizationTimer;
    QByteArray   m_rxBuffer;
    QByteArray   m_lastSentFrame;

    int    m_remainingTime = 180;
    bool   m_pendingZeroCal = false; // false = air cal, true = zero cal

    double m_valueDO     = 0.0;
    double m_saturation  = 0.0;
    double m_temperature = 0.0;

    static constexpr quint8  SLAVE_ID      = 0x0A; // ID de fábrica RK500-04
    static constexpr int     FC03_RESP_LEN = 17;   // 1+1+1+12+2
    static constexpr int     FC06_RESP_LEN = 8;    // echo del comando enviado
};

#endif // SENSORDO_H
