#ifndef SENSORPH_H
#define SENSORPH_H

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QByteArray>

class SensorPH : public QObject {
    Q_OBJECT
    // Expone el tiempo restante a QML para mostrar el conteo en pantalla
    Q_PROPERTY(int remainingTime READ remainingTime NOTIFY remainingTimeChanged)

public:
    explicit SensorPH(QObject *parent = nullptr);

    // Funciones que se llaman desde la interfaz QML
    Q_INVOKABLE void requestValue();               // Lectura de pH
    Q_INVOKABLE void startStabilization(int ph);   // Inicia espera de 180s
    Q_INVOKABLE void calibrateNow();               // Envía comando de calibración

    int remainingTime() const { return m_remainingTime; }
    static quint16 calculateCRC(const QByteArray &data);
signals:
    void logMessage(QString msg);      // Para la consola visual
    void remainingTimeChanged();
    void calibrationFinished();        // Avisa que la estabilización terminó

private slots:
    void onReadyRead();                // Procesa respuestas y ecos
    void onTimerTick();                // Actualiza el segundero

private:
    QSerialPort *m_serial;
    QTimer *m_stabilizationTimer;
    QByteArray m_lastSentFrame;        // Para validar el eco
    int m_remainingTime = 180;         // Según manual
    int m_pendingPhPoint = 7;          // Punto seleccionado
    quint8 m_slaveId = 0x03;           // ID por defecto
};

#endif
