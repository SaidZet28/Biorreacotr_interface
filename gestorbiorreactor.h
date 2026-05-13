#ifndef GESTORBIORREACTOR_H
#define GESTORBIORREACTOR_H

#include <QObject>
#include <QSerialPort>

class GestorBiorreactor : public QObject
{
    Q_OBJECT

    // ── Lecturas de sensores ───────────────────────────────────────────────
    Q_PROPERTY(double sensorTem  READ sensorTem  WRITE setSensorTem  NOTIFY sensorTemChanged  FINAL)
    Q_PROPERTY(double sensorPH   READ sensorPH   WRITE setSensorPH   NOTIFY sensorPHChanged   FINAL)
    Q_PROPERTY(double sensorAgua READ sensorAgua WRITE setSensorAgua NOTIFY sensorAguaChanged FINAL)
    Q_PROPERTY(double sensorLuz  READ sensorLuz  WRITE setSensorLuz  NOTIFY sensorLuzChanged  FINAL)
    Q_PROPERTY(double sensorCO2  READ sensorCO2  WRITE setSensorCO2  NOTIFY sensorCO2Changed  FINAL)
    Q_PROPERTY(double sensorDO   READ sensorDO   WRITE setSensorDO   NOTIFY sensorDOChanged   FINAL)

    // ── Setpoints (valores deseados) ──────────────────────────────────────
    Q_PROPERTY(double setpointTem  READ setpointTem  WRITE setSetpointTem  NOTIFY setpointTemChanged  FINAL)
    Q_PROPERTY(double setpointPH   READ setpointPH   WRITE setSetpointPH   NOTIFY setpointPHChanged   FINAL)
    Q_PROPERTY(double setpointAgua READ setpointAgua WRITE setSetpointAgua NOTIFY setpointAguaChanged FINAL)
    Q_PROPERTY(double setpointLuz  READ setpointLuz  WRITE setSetpointLuz  NOTIFY setpointLuzChanged  FINAL)
    Q_PROPERTY(double setpointCO2  READ setpointCO2  WRITE setSetpointCO2  NOTIFY setpointCO2Changed  FINAL)

    // ── Puerto serial ─────────────────────────────────────────────────────
    Q_PROPERTY(bool    puertoConectado READ puertoConectado NOTIFY puertoConectadoChanged FINAL)
    Q_PROPERTY(QString nombrePuerto   READ nombrePuerto    NOTIFY nombrePuertoChanged    FINAL)

public:
    explicit GestorBiorreactor(QObject *parent = nullptr);
    ~GestorBiorreactor();

    // Sensores
    double sensorTem()  const;
    double sensorPH()   const;
    double sensorAgua() const;
    double sensorLuz()  const;
    double sensorCO2()  const;
    double sensorDO()   const;

    void setSensorTem (double value);
    void setSensorPH  (double value);
    void setSensorAgua(double value);
    void setSensorLuz (double value);
    void setSensorCO2 (double value);
    void setSensorDO  (double value);

    // Setpoints
    double setpointTem()  const;
    double setpointPH()   const;
    double setpointAgua() const;
    double setpointLuz()  const;
    double setpointCO2()  const;

    void setSetpointTem (double value);
    void setSetpointPH  (double value);
    void setSetpointAgua(double value);
    void setSetpointLuz (double value);
    void setSetpointCO2 (double value);

    // Puerto serial
    bool    puertoConectado() const;
    QString nombrePuerto()    const;

    Q_INVOKABLE void cargarConfiguracion();
    Q_INVOKABLE void guardarConfiguracion();
    Q_INVOKABLE void resetearSetpoints();
    Q_INVOKABLE bool buscarYConectar(const QString &nombreForzado = QString());
    Q_INVOKABLE void desconectar();

signals:
    void sensorTemChanged();
    void sensorPHChanged();
    void sensorAguaChanged();
    void sensorLuzChanged();
    void sensorCO2Changed();
    void sensorDOChanged();

    void setpointTemChanged();
    void setpointPHChanged();
    void setpointAguaChanged();
    void setpointLuzChanged();
    void setpointCO2Changed();

    void puertoConectadoChanged();
    void nombrePuertoChanged();

private slots:
    void leerDatosSerial();

private:
    void parsearTrama(const QByteArray &linea);

    // Sensores (valores en tiempo real, no se persisten)
    double m_sensorTem  = 24.5;
    double m_sensorPH   = 7.2;
    double m_sensorAgua = 85.0;
    double m_sensorLuz  = 60.0;
    double m_sensorCO2  = 400.0;
    double m_sensorDO   = 8.2;

    // Setpoints (se persisten con QSettings)
    double m_setpointTem  = 0.0;
    double m_setpointPH   = 0.0;
    double m_setpointAgua = 0.0;
    double m_setpointLuz  = 0.0;
    double m_setpointCO2  = 0.0;

    // Puerto serial
    QSerialPort m_puerto;
    QByteArray  m_buffer;
};

#endif // GESTORBIORREACTOR_H
