#pragma once
#include <QObject>
#include <QVector>
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
    //   tick impar → leerResultado()  (returns -1.0 si no listo aún o error I2C)
    //
    // leerResultado() selecciona el pico de MAYOR fuerza de reflexión (no el más
    // cercano) y le aplica el filtro de confirmación antes de devolver la
    // distancia en mm. Mientras un cambio de zona no se confirma, devuelve la
    // última distancia aceptada (el nivel no salta por lecturas espurias).
    bool   iniciarMedicion();
    double leerResultado();

    bool conectado() const { return m_fd >= 0; }

    // ── Modo CARACTERIZACIÓN (portado fiel de xm125_distance.py) ──────────────
    // Herramienta de diagnóstico: NO usa el filtro de confirmación ni elige un
    // solo pico. Devuelve TODOS los picos crudos para poder decidir con datos las
    // reglas de filtrado. No pisa la lógica de producción de arriba.
    struct PicoCrudo {
        double   distMm;     // distancia del pico en mm
        uint32_t fuerzaRaw;  // valor crudo del registro de fuerza (patrón de bits)
    };

    // Inicializa igual que xm125_distance.py: RESET_MODULE + rango 100..2000 mm +
    // APPLY_CONFIG_AND_CALIBRATE. Reabre el fd si hace falta. Bloqueante (~5 s).
    bool inicializarCaracterizacion(int bus = 1);

    // Mide y devuelve TODOS los picos en el ORDEN DEL FIRMWARE (sin ordenar ni
    // filtrar). Llena tempC (°C del chip, bits[31:16] de 0x0010) y resultadoCrudo
    // (registro 0x0010 completo). Devuelve lista vacía si no hay objeto; si hay
    // error de I2C/medición pone ok=false.
    QVector<PicoCrudo> medirPicosCrudos(bool &ok, double &tempC, uint32_t &resultadoCrudo);

private:
    int m_fd = -1;

    // ── Filtro de confirmación (portado de prueba_visual_nivel.py) ────────────
    //   • |nuevo − aceptado| ≤ MARGEN_CONFIRM_MM  → se acepta directo
    //   • fuera del margen → se necesita CONFIRMAR_N lecturas consecutivas en la
    //     zona candidata para reemplazar el valor aceptado
    // Estado persistente entre llamadas a leerResultado(); se reinicia en
    // inicializar()/cerrar(). Sentinela -1.0 = "aún sin valor".
    static constexpr double MARGEN_CONFIRM_MM = 30.0;
    static constexpr int    CONFIRMAR_N       = 3;
    double m_distAceptada = -1.0;   // distancia actualmente válida [mm]
    double m_candidatoVal = -1.0;   // distancia candidata (fuera del margen) [mm]
    int    m_candidatoCnt = 0;      // lecturas consecutivas en la zona candidata
    void   reiniciarFiltro() { m_distAceptada = -1.0; m_candidatoVal = -1.0; m_candidatoCnt = 0; }

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
    static constexpr uint32_t CMD_RECALIBRATE                = 5;
    static constexpr uint32_t CMD_RESET_MODULE               = 0x52535421u; // "RST!"

    // Bits de REG_DISTANCE_RESULT (0x0010)
    static constexpr uint32_t RESULT_NUM_DISTANCES_MASK = 0x0000000Fu;
    static constexpr uint32_t RESULT_CALIBRATION_NEEDED = 0x00000200u;
    static constexpr uint32_t RESULT_MEASURE_ERROR      = 0x00000400u;
};
