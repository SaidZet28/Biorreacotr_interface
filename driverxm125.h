#pragma once
#include <QObject>
#include <cstdint>

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

    // Protocolo SparkFun XM125 (Qwiic Pulsed Radar):
    // write: 2 bytes addr (big-endian) + 4 bytes value (big-endian)
    // read:  2 bytes addr (big-endian), luego lectura de 4 bytes value
    bool escribirRegistro(uint16_t reg, uint32_t valor);
    bool leerRegistro(uint16_t reg, uint32_t &valor);

    // Mapa de registros (SparkFun XM125 I2C, dirección 0x52)
    static constexpr uint16_t REG_PRODUCT_ID    = 0x0000; // Product ID (32-bit, solo lectura)
    static constexpr uint16_t REG_MEASURE_START = 0x000A; // Escribe 0x01 para iniciar medición
    static constexpr uint16_t REG_STATUS        = 0x000B; // bit 0 = listo (medición completa)
    static constexpr uint16_t REG_DISTANCE      = 0x0010; // Distancia en mm (32-bit, big-endian)
};
