#pragma once
#include <QObject>
#include <cstdint>

class DriverPCA9685 : public QObject {
    Q_OBJECT
public:
    // Asignación de canales (ajustar si cambia el cableado)
    static constexpr int CH_CALENTADOR    = 0;
    static constexpr int CH_BOMBA_ETANOL  = 1;
    static constexpr int CH_BOMBA_AGUA    = 2;
    static constexpr int CH_RECIRCULACION = 3;
    static constexpr int CH_AIRLIFT       = 4;
    static constexpr int CH_BOMBA_NIVEL   = 5;

    explicit DriverPCA9685(QObject *parent = nullptr);
    ~DriverPCA9685();

    // Abre /dev/i2c-{bus} y configura el PCA9685 a {frecuenciaHz} Hz
    bool inicializar(int bus = 1, int frecuenciaHz = 50);
    void cerrar();

    // valor: 0-4095
    void escribirCanal(int canal, int valor);

    // porcentaje: 0.0-100.0 → convierte a 0-4095
    void escribirPorcentaje(int canal, double porcentaje);

    // Digital: 0 o 4095
    void escribirDigital(int canal, bool activo);

    bool conectado() const { return m_fd >= 0; }

private:
    void escribirRegistro(uint8_t reg, uint8_t valor);

    int m_fd = -1;
};
