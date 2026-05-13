#pragma once
#include <QObject>

class ControladorHisteresis : public QObject {
    Q_OBJECT
public:
    explicit ControladorHisteresis(QObject *parent = nullptr);

    // delta: ancho de banda de histéresis (ej. 5.0 → activa bajo sp-2.5, desactiva sobre sp+2.5)
    void configurar(double delta);

    // Devuelve true = bomba ON, false = bomba OFF
    // Conserva estado entre llamadas (histéresis real)
    bool calcular(double setpoint, double medicion);

    void reiniciar();
    bool estadoBomba() const { return m_bombaActiva; }

private:
    double m_delta       = 5.0;
    bool   m_bombaActiva = false;
};
