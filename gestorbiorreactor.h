#ifndef GESTORBIORREACTOR_H
#define GESTORBIORREACTOR_H

#include <QObject>

class GestorBiorreactor : public QObject
{
    Q_OBJECT

    // ── Lecturas de sensores ───────────────────────────────────────────────
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

public:
    explicit GestorBiorreactor(QObject *parent = nullptr);
    ~GestorBiorreactor();

    // Sensores
    double sensorAgua() const;
    double sensorLuz()  const;
    double sensorCO2()  const;
    double sensorDO()   const;

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

    Q_INVOKABLE void cargarConfiguracion();
    Q_INVOKABLE void guardarConfiguracion();

signals:
    void sensorAguaChanged();
    void sensorLuzChanged();
    void sensorCO2Changed();
    void sensorDOChanged();

    void setpointTemChanged();
    void setpointPHChanged();
    void setpointAguaChanged();
    void setpointLuzChanged();
    void setpointCO2Changed();

private:
    // Sensores (valores en tiempo real, no se persisten)
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
};

#endif // GESTORBIORREACTOR_H
