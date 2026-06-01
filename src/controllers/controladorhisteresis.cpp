#include "controladorhisteresis.h"

ControladorHisteresis::ControladorHisteresis(QObject *parent) : QObject(parent) {}

void ControladorHisteresis::configurar(double delta)
{
    m_delta = delta;
}

bool ControladorHisteresis::calcular(double setpoint, double medicion)
{
    double sp_bajo = setpoint - m_delta / 2.0;
    double sp_alto = setpoint + m_delta / 2.0;

    if      (medicion > sp_alto) m_bombaActiva = true;   // nivel alto → vaciar
    else if (medicion < sp_bajo) m_bombaActiva = false;  // nivel bajo → parar
    // Dentro de la banda: mantiene estado previo (histéresis)

    return m_bombaActiva;
}

void ControladorHisteresis::reiniciar()
{
    m_bombaActiva = false;
}
