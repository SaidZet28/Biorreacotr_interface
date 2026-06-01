#pragma once

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QDateTime>

#include "controladorpid.h"
#include "controladorfuzzy.h"
#include "controladorhisteresis.h"
#include "driverpca9685.h"
#include "driverxm125.h"

class GestorBiorreactor : public QObject
{
    Q_OBJECT

    // ── Sensores ─────────────────────────────────────────────────────────────
    Q_PROPERTY(double sensorTem   READ sensorTem   NOTIFY sensorTemChanged   FINAL)
    Q_PROPERTY(double sensorPH    READ sensorPH    NOTIFY sensorPHChanged    FINAL)
    Q_PROPERTY(double sensorNivel READ sensorNivel NOTIFY sensorNivelChanged FINAL)
    Q_PROPERTY(double sensorLuz   READ sensorLuz   NOTIFY sensorLuzChanged   FINAL)
    Q_PROPERTY(double sensorCO2   READ sensorCO2   NOTIFY sensorCO2Changed   FINAL)
    Q_PROPERTY(double sensorDO    READ sensorDO    NOTIFY sensorDOChanged    FINAL)

    // ── Setpoints ─────────────────────────────────────────────────────────────
    Q_PROPERTY(double setpointTem   READ setpointTem   WRITE setSetpointTem   NOTIFY setpointTemChanged   FINAL)
    Q_PROPERTY(double setpointPH    READ setpointPH    WRITE setSetpointPH    NOTIFY setpointPHChanged    FINAL)
    Q_PROPERTY(double setpointNivel READ setpointNivel WRITE setSetpointNivel NOTIFY setpointNivelChanged FINAL)
    Q_PROPERTY(double setpointLuz   READ setpointLuz   WRITE setSetpointLuz   NOTIFY setpointLuzChanged   FINAL)
    Q_PROPERTY(double setpointCO2   READ setpointCO2   WRITE setSetpointCO2   NOTIFY setpointCO2Changed   FINAL)

    // ── Alertas watchdog ──────────────────────────────────────────────────────
    Q_PROPERTY(bool alertaDivergenciaTemp READ alertaDivergenciaTemp NOTIFY alertaDivergenciaTempChanged FINAL)
    Q_PROPERTY(bool alertaSerial          READ alertaSerial          NOTIFY alertaSerialChanged          FINAL)
    Q_PROPERTY(bool alertaNivel           READ alertaNivel           NOTIFY alertaNivelChanged           FINAL)

    // ── Estado del proceso ───────────────────────────────────────────────────
    Q_PROPERTY(bool procesoActivo READ procesoActivo WRITE setProcesoActivo NOTIFY procesoActivoChanged FINAL)

    // ── Salidas de control (para gráficas y monitoreo) ───────────────────────
    Q_PROPERTY(double salidaCalentador   READ salidaCalentador   NOTIFY salidaCalentadorChanged   FINAL)
    Q_PROPERTY(double salidaBombaEtanol  READ salidaBombaEtanol  NOTIFY salidaBombaEtanolChanged  FINAL)
    Q_PROPERTY(double salidaBombaAgua    READ salidaBombaAgua    NOTIFY salidaBombaAguaChanged    FINAL)
    Q_PROPERTY(bool   salidaBombaNivel   READ salidaBombaNivel   NOTIFY salidaBombaNivelChanged   FINAL)

    // ── Puerto serial ────────────────────────────────────────────────────────
    Q_PROPERTY(bool    puertoConectado READ puertoConectado NOTIFY puertoConectadoChanged FINAL)
    Q_PROPERTY(QString nombrePuerto   READ nombrePuerto    NOTIFY nombrePuertoChanged    FINAL)

    // ── Simulación ───────────────────────────────────────────────────────────
    Q_PROPERTY(bool modoSimulacion READ modoSimulacion CONSTANT)

    // ── Habilitación individual de controladores ──────────────────────────────
    Q_PROPERTY(bool fuzzyPHHabilitado         READ fuzzyPHHabilitado         NOTIFY fuzzyPHHabilitadoChanged         FINAL)
    Q_PROPERTY(bool histeresisNivelHabilitado READ histeresisNivelHabilitado NOTIFY histeresisNivelHabilitadoChanged FINAL)

    // ── Preparación del tanque ────────────────────────────────────────────────
    Q_PROPERTY(int     estadoPreparacion       READ estadoPreparacion       NOTIFY estadoPreparacionChanged     FINAL)
    Q_PROPERTY(double  progresoPreparacion     READ progresoPreparacion     NOTIFY progresoPreparacionChanged   FINAL)
    Q_PROPERTY(bool    preparacionCompletada   READ preparacionCompletada   NOTIFY preparacionCompletadaChanged FINAL)
    Q_PROPERTY(bool    alertaEscalacion        READ alertaEscalacion        NOTIFY alertaEscalacionChanged      FINAL)
    Q_PROPERTY(QString textoTareaPreparacion   READ textoTareaPreparacion   NOTIFY estadoPreparacionChanged     FINAL)
    Q_PROPERTY(QString textoDetallePreparacion READ textoDetallePreparacion NOTIFY estadoPreparacionChanged     FINAL)

    // ── Llenado óptimo ────────────────────────────────────────────────────────
    Q_PROPERTY(double litrosAgua   READ litrosAgua   NOTIFY mezclaCalculadaChanged FINAL)
    Q_PROPERTY(double mlSustanciaB READ mlSustanciaB NOTIFY mezclaCalculadaChanged FINAL)

public:
    explicit GestorBiorreactor(QObject *parent = nullptr);
    ~GestorBiorreactor();

    double sensorTem()   const;
    double sensorPH()    const;
    double sensorNivel() const;
    double sensorLuz()   const;
    double sensorCO2()   const;
    double sensorDO()    const;

    double setpointTem()   const;
    double setpointPH()    const;
    double setpointNivel() const;
    double setpointLuz()   const;
    double setpointCO2()   const;

    void setSetpointTem  (double v);
    void setSetpointPH   (double v);
    void setSetpointNivel(double v);
    void setSetpointLuz  (double v);
    void setSetpointCO2  (double v);

    bool alertaDivergenciaTemp() const;
    bool alertaSerial()          const;
    bool alertaNivel()           const;

    bool procesoActivo() const;
    void setProcesoActivo(bool activo);

    double salidaCalentador()  const;
    double salidaBombaEtanol() const;
    double salidaBombaAgua()   const;
    bool   salidaBombaNivel()  const;

    bool    puertoConectado() const;
    QString nombrePuerto()    const;

    bool modoSimulacion() const;

    bool fuzzyPHHabilitado()         const;
    bool histeresisNivelHabilitado() const;

    int     estadoPreparacion()       const;
    double  progresoPreparacion()     const;
    bool    preparacionCompletada()   const;
    bool    alertaEscalacion()        const;
    QString textoTareaPreparacion()   const;
    QString textoDetallePreparacion() const;

    double litrosAgua()   const;
    double mlSustanciaB() const;

    Q_INVOKABLE void iniciarPreparacion();
    Q_INVOKABLE void cancelarPreparacion();
    Q_INVOKABLE void continuarDesdeEscalacion();
    Q_INVOKABLE void habilitarFuzzyPH(bool v);
    Q_INVOKABLE void habilitarHisteresisNivel(bool v);

    Q_INVOKABLE void cargarConfiguracion();
    Q_INVOKABLE void guardarConfiguracion();
    Q_INVOKABLE void resetearSetpoints();
    Q_INVOKABLE bool buscarYConectar(const QString &nombreForzado = QString());
    Q_INVOKABLE void desconectar();

    Q_INVOKABLE void          guardarModelo(const QString &nombre, const QVariantList &datos);
    Q_INVOKABLE QVariantList  cargarModelo (const QString &nombre);

    Q_INVOKABLE QString detectarUSB();

    Q_INVOKABLE QString rutaBaseData() const;
    Q_INVOKABLE void    eliminarCarpetaExperimento(const QString &nombreProyecto,
                                                    const QString &nombreExp);

    // ── Registro histórico de sensores ───────────────────────────────────────
    Q_INVOKABLE void iniciarRegistro(const QString &proyecto, const QString &experimento);
    Q_INVOKABLE void detenerRegistro();
    Q_INVOKABLE int  totalLecturas() const;
    Q_INVOKABLE bool exportarRegistroCSV(const QString &carpetaDestino,
                                         const QString &nombreExp,
                                         const QString &nombreProyecto);

    void parsearTrama(const QByteArray &linea);

signals:
    void sensorTemChanged();
    void sensorPHChanged();
    void sensorNivelChanged();
    void sensorLuzChanged();
    void sensorCO2Changed();
    void sensorDOChanged();

    void setpointTemChanged();
    void setpointPHChanged();
    void setpointNivelChanged();
    void setpointLuzChanged();
    void setpointCO2Changed();

    void alertaDivergenciaTempChanged();
    void alertaSerialChanged();
    void alertaNivelChanged();

    void procesoActivoChanged();

    void salidaCalentadorChanged();
    void salidaBombaEtanolChanged();
    void salidaBombaAguaChanged();
    void salidaBombaNivelChanged();

    void puertoConectadoChanged();
    void nombrePuertoChanged();

    void fuzzyPHHabilitadoChanged();
    void histeresisNivelHabilitadoChanged();

    void estadoPreparacionChanged();
    void progresoPreparacionChanged();
    void preparacionCompletadaChanged();
    void alertaEscalacionChanged();
    void mezclaCalculadaChanged();
    void preparacionCancelada();

private slots:
    void leerDatosSerial();
    void consultarSensoresRS485();
    void ejecutarControlLoop();
    void onWatchdogSerialTimeout();
    void onWatchdogI2CTimeout();
    void verificarStaleness();
    void leerSensorNivel();
    void tickSimulacion();
    void registrarLectura();
    void tickPreparacion();

private:
    void actualizarTemperaturaFusionada();

    void setSensorTem  (double v);
    void setSensorPH   (double v);
    void setSensorNivel(double v);
    void setSensorLuz  (double v);
    void setSensorCO2  (double v);
    void setSensorDO   (double v);

    void setAlertaDivergenciaTemp(bool v);
    void setAlertaSerial(bool v);
    void setAlertaNivel (bool v);
    void resetWatchdogSerial();

    void setEstadoPreparacion(int estado);
    void setProgresoPreparacion(double v);
    void setPreparacionCompletada(bool v);
    void setAlertaEscalacion(bool v);
    void calcularMezclaOptima();

    // ── Valores de sensores ───────────────────────────────────────────────────
    double m_sensorTem   = 24.5;
    double m_sensorPH    = 7.2;
    double m_sensorNivel = 85.0;
    double m_sensorLuz   = 60.0;
    double m_sensorCO2   = 400.0;
    double m_sensorDO    = 8.2;

    // Temperaturas internas para fusión (una por cada sensor RS-485)
    double m_tempPH = 24.5;
    double m_tempDO = 24.5;
    bool   m_tempPHValida = false;
    bool   m_tempDOValida = false;

    // ── Setpoints ─────────────────────────────────────────────────────────────
    double m_setpointTem   = 0.0;
    double m_setpointPH    = 0.0;
    double m_setpointNivel = 0.0;
    double m_setpointLuz   = 0.0;
    double m_setpointCO2   = 0.0;

    // ── Alertas ───────────────────────────────────────────────────────────────
    bool m_alertaDivergenciaTemp = false;
    bool m_alertaSerial          = false;
    bool m_alertaNivel           = false;

    // ── Proceso y salidas ─────────────────────────────────────────────────────
    bool   m_procesoActivo              = false;
    bool   m_fuzzyPHHabilitado          = false;
    bool   m_histeresisNivelHabilitado  = false;

    // ── Preparación del tanque ────────────────────────────────────────────────
    int    m_estadoPreparacion     = -1;
    double m_progresoPreparacion   = 0.0;
    bool   m_preparacionCompletada = false;
    bool   m_alertaEscalacion      = false;
    int    m_ticksPrep             = 0;
    int    m_contadorEstabPH       = 0;
    int    m_contadorEstabFino     = 0;

    // Llenado óptimo
    double m_litrosAgua        = 0.0;
    double m_mlSustanciaB      = 0.0;
    int    m_ticksDosificacionB = 0;
    double m_salidaCalentador  = 0.0;
    double m_salidaBombaEtanol = 0.0;
    double m_salidaBombaAgua   = 0.0;
    bool   m_salidaBombaNivel  = false;

    // ── Comunicación serial ───────────────────────────────────────────────────
    QSerialPort m_puerto;
    QByteArray  m_buffer;
    int         m_turnoRS485 = 0;   // 0 = consultar pH, 1 = consultar DO

    // ── Controladores ─────────────────────────────────────────────────────────
    ControladorPID        m_pidTemp;
    ControladorFuzzy      m_fuzzyPH;
    ControladorHisteresis m_histeresisNivel;

    // ── Drivers de hardware ───────────────────────────────────────────────────
    DriverPCA9685 m_pca9685;
    DriverXM125   m_xm125;

    // ── Timers ────────────────────────────────────────────────────────────────
    QTimer m_timerRS485;          // 500 ms  — query a sensores RS-485
    QTimer m_timerControlLoop;    // 1000 ms — ejecuta algoritmos de control
    QTimer m_timerWatchdogSerial; // 3000 ms one-shot — timeout sin datos serial
    QTimer m_timerWatchdogI2C;    // 2000 ms one-shot — timeout sin datos I2C
    QTimer m_timerStaleness;      // 1000 ms — revisa freshness de sensores
    QTimer m_timerNivel;          // 500 ms  — lee XM125
    QTimer m_timerSimulacion;     // 1000 ms — genera datos sintéticos (solo SIMULACION_ACTIVA)
    QTimer m_timerRegistro;       // muestreo periódico de sensores durante el proceso
    QTimer m_timerPreparacion;    // 1000 ms — máquina de estados de preparación del tanque

    QDateTime m_ultimaLecturaRS485;
    QDateTime m_ultimaLecturaI2C;
    QDateTime m_tiempoInicioRegistro;

    double m_tickSim  = 0.0;
    int    m_nivelPaso  = 0;   // 0 = iniciar medición XM125, 1 = leer resultado
    int    m_fallosNivel = 0;

    QString m_nombreProyectoRegistro;
    QString m_nombreExpRegistro;
    QVector<QVariantMap> m_lecturas;
};
