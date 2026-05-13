#pragma once
#include <QObject>

class DriverXM125 : public QObject {
    Q_OBJECT
public:
    explicit DriverXM125(QObject *parent = nullptr);
    ~DriverXM125();

    // Abre /dev/i2c-{bus}, inicializa el XM125 en modo distancia
    bool inicializar(int bus = 1);
    void cerrar();

    // Lee distancia en mm. Retorna -1.0 si hay error o no está conectado.
    double leerDistanciaMm();

    bool conectado() const { return m_fd >= 0; }

private:
    int m_fd = -1;

    bool escribirRegistro(uint16_t reg, uint32_t valor);
    bool leerRegistro(uint16_t reg, uint32_t &valor);
};
