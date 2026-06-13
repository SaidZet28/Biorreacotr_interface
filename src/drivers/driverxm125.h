#pragma once
#include <QObject>
#include <cstdint>

class DriverXM125 : public QObject {
    Q_OBJECT
public:
    explicit DriverXM125(QObject *parent = nullptr);
    ~DriverXM125();

    // Abre /dev/i2c-{bus}, calibra el detector (bloqueante ~1-2 s al inicio)
    bool inicializar(int bus = 1);
    void cerrar();

    // API no bloqueante (usar en timers del event loop):
    //   tick par  → iniciarMedicion()
    //   tick impar → leerResultado()  (returns -1.0 si no listo aún o error)
    bool   iniciarMedicion();
    double leerResultado();

    bool conectado() const { return m_fd >= 0; }

private:
    int m_fd = -1;

    // Protocolo XM125 (SparkFun/Acconeer Qwiic I2C, dir 0x52):
    //   write: [addr_hi, addr_lo, val_b3, val_b2, val_b1, val_b0]  big-endian
    //   read : write [addr_hi, addr_lo], luego read 4 bytes big-endian
    bool escribirRegistro(uint16_t reg, uint32_t valor);
    bool leerRegistro(uint16_t reg, uint32_t &valor);

    // Mapa de registros validado con sfDevXM125Distance.h de SparkFun
    static constexpr uint16_t REG_PRODUCT_ID       = 0x0000;
    static constexpr uint16_t REG_DETECTOR_STATUS  = 0x0003; // bit31=BUSY, bits[9:0]=OK flags
    static constexpr uint16_t REG_DISTANCE_RESULT  = 0x0010; // bits[3:0]=num_distances, bits[31:16]=temp
    static constexpr uint16_t REG_PEAK_DIST_BASE   = 0x0011; // 0x0011..0x001A: distancia pico 0..9 en mm
    static constexpr uint16_t REG_PEAK_STR_BASE    = 0x001B; // 0x001B..0x0024: fuerza pico 0..9 (int32)
    static constexpr uint16_t REG_RANGE_START      = 0x0040; // default 250 mm
    static constexpr uint16_t REG_RANGE_END        = 0x0041; // default 3000 mm
    static constexpr uint16_t REG_COMMAND          = 0x0100;

    // Comandos para REG_COMMAND
    static constexpr uint32_t CMD_APPLY_CONFIG_AND_CALIBRATE = 1;
    static constexpr uint32_t CMD_MEASURE_DISTANCE           = 2;
};
