#pragma once
#include <QObject>
#include <cstdint>

// ── Driver PCF8574 (expansor de E/S I2C de 8 bits) ───────────────────────────
// Se usa para leer el flotador doble de nivel (dos interruptores reed).
// El PCF8574 no tiene registros: escribir un byte fija los 8 pines y leer un byte
// regresa su estado. Un pin escrito en 1 queda como entrada con pull-up débil;
// un contacto cerrado a GND lo lleva a 0.
class DriverPCF8574 : public QObject {
    Q_OBJECT
public:
    explicit DriverPCF8574(QObject *parent = nullptr);
    ~DriverPCF8574();

    // Abre /dev/i2c-{bus} en {direccion} y pone los 8 pines como entrada (0xFF).
    bool inicializar(int bus = 1, int direccion = 0x20);
    void cerrar();

    // Lee los 8 pines. ok = false si falla el I2C.
    uint8_t leerPuerto(bool &ok);

    bool conectado() const { return m_fd >= 0; }

private:
    int m_fd = -1;
};
