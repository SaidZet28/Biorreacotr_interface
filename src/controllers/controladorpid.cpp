#include "controladorpid.h"
#include <algorithm>

ControladorPID::ControladorPID(QObject *parent) : QObject(parent) {}

void ControladorPID::configurar(double kp, double ki, double kd, double dt_s,
                                 double salidaMin, double salidaMax)
{
    m_kp = kp; m_ki = ki; m_kd = kd;
    m_dt = dt_s;
    m_salidaMin = salidaMin;
    m_salidaMax = salidaMax;
    reiniciar();
}

double ControladorPID::calcular(double setpoint, double medicion)
{
    double error = setpoint - medicion;

    double p = m_kp * error;

    // Integral con anti-windup por clamping
    m_integral += m_ki * error * m_dt;
    m_integral = std::clamp(m_integral, m_salidaMin, m_salidaMax);

    // Derivativo (desactivado en primer ciclo para evitar spike)
    double d = 0.0;
    if (!m_primerCiclo)
        d = m_kd * (error - m_errorPrevio) / m_dt;

    m_errorPrevio = error;
    m_primerCiclo = false;

    return std::clamp(p + m_integral + d, m_salidaMin, m_salidaMax);
}

void ControladorPID::reiniciar()
{
    m_integral    = 0.0;
    m_errorPrevio = 0.0;
    m_primerCiclo = true;
}
