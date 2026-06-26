#pragma once
#include <QObject>
#include <QThread>
#include <atomic>
#include <cstdint>

// ── Hilo de cruce por cero ────────────────────────────────────────────────────
// En cada ZC (GPIO27): deshabilita OE 50 µs y lo re-habilita, sincronizando
// el PWM del PCA9685 con la fase de la red AC (60 Hz, México).
class ZeroCrossWorker : public QObject {
    Q_OBJECT
public:
    std::atomic<bool> running{true};
    void stop() { running = false; }
public slots:
    void process();
signals:
    void finished();
};

// ── Driver PCA9685 ────────────────────────────────────────────────────────────
class DriverPCA9685 : public QObject {
    Q_OBJECT
public:
    // Asignación de canales (verificada con RPWM3 — ajustar si cambia el cableado)
    static constexpr int CH_CALENTADOR     = 0;
    static constexpr int CH_BOMBA_ETANOL   = 1;   // legacy — no usar para bomba neutr.
    static constexpr int CH_BOMBA_AGUA     = 2;
    static constexpr int CH_BOMBA_NEUT_DIR = 3;   // Bomba Neutralizador — señal dirección
    static constexpr int CH_BOMBA_NEUT_ENA = 4;   // Bomba Neutralizador — señal enable
    static constexpr int CH_BOMBA_NIVEL    = 5;

    explicit DriverPCA9685(QObject *parent = nullptr);
    ~DriverPCA9685();

    // Abre /dev/i2c-{bus}, configura PCA9685 a {frecuenciaHz} Hz y arranca el hilo ZC
    bool inicializar(int bus = 1, int frecuenciaHz = 60);
    void cerrar();

    // valor: 0–4095
    void escribirCanal(int canal, int valor);

    // porcentaje: 0.0–100.0  →  convierte a 0–4095
    void escribirPorcentaje(int canal, double porcentaje);

    // Digital: false=0, true=4095
    void escribirDigital(int canal, bool activo);

    // OE pin (GPIO17): LOW = salidas activas, HIGH = todos los canales deshabilitados
    void habilitarSalidas(bool activo);

    bool conectado() const { return m_fd >= 0; }

private:
    void escribirRegistro(uint8_t reg, uint8_t valor);

    int m_fd = -1;

    QThread         *m_zcThread = nullptr;
    ZeroCrossWorker *m_zcWorker = nullptr;
};
