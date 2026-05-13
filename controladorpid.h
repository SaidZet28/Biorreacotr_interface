#pragma once
#include <QObject>

class ControladorPID : public QObject {
    Q_OBJECT
public:
    explicit ControladorPID(QObject *parent = nullptr);

    // kp/ki/kd: ganancias, dt_s: periodo en segundos, salidaMin/Max: límites de salida
    void configurar(double kp, double ki, double kd, double dt_s,
                    double salidaMin, double salidaMax);

    double calcular(double setpoint, double medicion);
    void   reiniciar();

private:
    double m_kp = 1.0, m_ki = 0.0, m_kd = 0.0;
    double m_dt = 1.0;
    double m_salidaMin = 0.0, m_salidaMax = 100.0;
    double m_integral   = 0.0;
    double m_errorPrevio = 0.0;
    bool   m_primerCiclo = true;
};
