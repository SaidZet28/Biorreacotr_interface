#pragma once

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QDateTime>
#include <QMetaObject>

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
    Q_PROPERTY(double sensorDO    READ sensorDO    NOTIFY sensorDOChanged    FINAL)

    // ── Setpoints ─────────────────────────────────────────────────────────────
    Q_PROPERTY(double setpointTem   READ setpointTem   WRITE setSetpointTem   NOTIFY setpointTemChanged   FINAL)
    Q_PROPERTY(double setpointPH    READ setpointPH    WRITE setSetpointPH    NOTIFY setpointPHChanged    FINAL)
    Q_PROPERTY(double nivelLlenadoPct READ nivelLlenadoPct CONSTANT)
    Q_PROPERTY(double setpointLuz   READ setpointLuz   WRITE setSetpointLuz   NOTIFY setpointLuzChanged   FINAL)

    // ── Alertas watchdog ──────────────────────────────────────────────────────
    Q_PROPERTY(bool alertaDivergenciaTemp READ alertaDivergenciaTemp NOTIFY alertaDivergenciaTempChanged FINAL)
    Q_PROPERTY(bool alertaSerial          READ alertaSerial          NOTIFY alertaSerialChanged          FINAL)
    Q_PROPERTY(bool alertaNivel           READ alertaNivel           NOTIFY alertaNivelChanged           FINAL)
    Q_PROPERTY(bool alertaSobreTemp       READ alertaSobreTemp       NOTIFY alertaSobreTempChanged       FINAL)
    Q_PROPERTY(bool alertaBombas          READ alertaBombas          NOTIFY alertaBombasChanged          FINAL)

    // ── Estado del proceso ───────────────────────────────────────────────────
    Q_PROPERTY(bool procesoActivo READ procesoActivo WRITE setProcesoActivo NOTIFY procesoActivoChanged FINAL)

    // ── Salidas de control (para gráficas y monitoreo) ───────────────────────
    Q_PROPERTY(double salidaCalentador      READ salidaCalentador      NOTIFY salidaCalentadorChanged      FINAL)
    // ETA estimado al setpoint de temperatura [s] (modelo FOPDT); <0 = N/A (en SP, enfriando o sin agua)
    Q_PROPERTY(double etaCalentamientoSeg   READ etaCalentamientoSeg   NOTIFY etaCalentamientoSegChanged   FINAL)
    // salidaBombaEtanol repropuesto: ahora es t_pulso [s] de la bomba neutralizadora (SISO)
    Q_PROPERTY(double salidaBombaEtanol     READ salidaBombaEtanol     NOTIFY salidaBombaEtanolChanged     FINAL)
    Q_PROPERTY(double salidaBombaAgua       READ salidaBombaAgua       NOTIFY salidaBombaAguaChanged       FINAL)
    Q_PROPERTY(bool   salidaBombaNivel      READ salidaBombaNivel      NOTIFY salidaBombaNivelChanged      FINAL)
    // Indica si la bomba neutralizadora está en pulso activo en este instante
    Q_PROPERTY(bool   pulsoNeutralizadorActivo READ pulsoNeutralizadorActivo NOTIFY pulsoNeutralizadorActivoChanged FINAL)

    // ── Puerto serial ────────────────────────────────────────────────────────
    Q_PROPERTY(bool    puertoConectado READ puertoConectado NOTIFY puertoConectadoChanged FINAL)
    Q_PROPERTY(QString nombrePuerto   READ nombrePuerto    NOTIFY nombrePuertoChanged    FINAL)

    // ── Simulación ───────────────────────────────────────────────────────────
    Q_PROPERTY(bool modoSimulacion READ modoSimulacion CONSTANT)

    // ── Habilitación individual de controladores ──────────────────────────────
    Q_PROPERTY(bool fuzzyPHHabilitado         READ fuzzyPHHabilitado         NOTIFY fuzzyPHHabilitadoChanged         FINAL)
    Q_PROPERTY(bool histeresisNivelHabilitado READ histeresisNivelHabilitado NOTIFY histeresisNivelHabilitadoChanged FINAL)

    // ── Umbrales de histéresis de nivel (configurables en tiempo de ejecución) ─
    Q_PROPERTY(double nivelMaxPct  READ nivelMaxPct  WRITE setNivelMaxPct  NOTIFY nivelMaxPctChanged  FINAL)
    Q_PROPERTY(double nivelHistPct READ nivelHistPct WRITE setNivelHistPct NOTIFY nivelHistPctChanged FINAL)

    // ── Countdown al próximo ciclo pH [s] ────────────────────────────────────
    Q_PROPERTY(int segundoProximoCiclo READ segundoProximoCiclo NOTIFY segundoProximoCicloChanged FINAL)

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
    double sensorDO()    const;

    double setpointTem()   const;
    double setpointPH()    const;
    double nivelLlenadoPct() const;
    double setpointLuz()   const;

    void setSetpointTem  (double v);
    void setSetpointPH   (double v);
    void setSetpointLuz  (double v);

    bool alertaDivergenciaTemp() const;
    bool alertaSerial()          const;
    bool alertaNivel()           const;
    bool alertaSobreTemp()       const;
    bool alertaBombas()          const;

    bool procesoActivo() const;
    void setProcesoActivo(bool activo);

    double salidaCalentador()          const;
    double etaCalentamientoSeg()       const;
    double salidaBombaEtanol()         const;   // retorna t_pulso calculado [s]
    double salidaBombaAgua()           const;
    bool   salidaBombaNivel()          const;
    bool   pulsoNeutralizadorActivo()  const;

    bool    puertoConectado() const;
    QString nombrePuerto()    const;

    bool modoSimulacion() const;

    bool fuzzyPHHabilitado()         const;
    bool histeresisNivelHabilitado() const;

    double nivelMaxPct()  const;
    double nivelHistPct() const;
    void   setNivelMaxPct (double v);
    void   setNivelHistPct(double v);

    int    segundoProximoCiclo() const;

    int     estadoPreparacion()       const;
    double  progresoPreparacion()     const;
    bool    preparacionCompletada()   const;
    bool    alertaEscalacion()        const;
    QString textoTareaPreparacion()   const;
    QString textoDetallePreparacion() const;

    double litrosAgua()   const;
    double mlSustanciaB() const;

    Q_INVOKABLE void enviarCalibracionPH(double ph4, double ph7, double ph10);
    Q_INVOKABLE void enviarCalibracionDO();

    void parsearTrama(const QByteArray &frame);

    Q_INVOKABLE void iniciarPreparacion();
    Q_INVOKABLE void cancelarPreparacion();
    Q_INVOKABLE void dispararPulsoManual(int segundos);  // prueba bomba CH3+CH4
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

signals:
    void sensorTemChanged();
    void sensorPHChanged();
    void sensorNivelChanged();
    void sensorLuzChanged();
    void sensorDOChanged();

    void setpointTemChanged();
    void setpointPHChanged();
    void setpointLuzChanged();

    void alertaDivergenciaTempChanged();
    void alertaSerialChanged();
    void alertaNivelChanged();
    void alertaSobreTempChanged();
    void alertaBombasChanged();

    void procesoActivoChanged();

    void salidaCalentadorChanged();
    void etaCalentamientoSegChanged();
    void salidaBombaEtanolChanged();
    void salidaBombaAguaChanged();
    void salidaBombaNivelChanged();
    void pulsoNeutralizadorActivoChanged();

    void puertoConectadoChanged();
    void nombrePuertoChanged();

    void fuzzyPHHabilitadoChanged();
    void histeresisNivelHabilitadoChanged();
    void nivelMaxPctChanged();
    void nivelHistPctChanged();
    void segundoProximoCicloChanged();

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
    void onCrucePorCero();

private:
    void actualizarTemperaturaFusionada();
    void procesarBufferModbus();
    void evaluarSeguridadNivel();   // protección de sobrellenado en mm + drenado

    void setSensorTem  (double v);
    void setSensorPH   (double v);
    void setSensorNivel(double v);
    void setSetpointNivel(double) {} // stub vacío — nivel ya no es configurable por usuario
    void setSensorLuz  (double v);
    void setSensorDO   (double v);

    void setAlertaDivergenciaTemp(bool v);
    void setAlertaSerial(bool v);
    void setAlertaNivel (bool v);
    void setAlertaSobreTemp(bool v);
    void setAlertaBombas(bool v);
    void resetWatchdogSerial();

    void setEstadoPreparacion(int estado);
    void setProgresoPreparacion(double v);
    void setPreparacionCompletada(bool v);
    void setAlertaEscalacion(bool v);
    void calcularMezclaOptima();

    // ── Valores de sensores ───────────────────────────────────────────────────
    double m_sensorTem   = 24.5;
    double m_tAmbiente   = 24.5;   // Temperatura ambiente capturada al arrancar el proceso
    double m_sensorPH    = 7.2;
    double m_sensorNivel = 85.0;
    double m_sensorLuz   = 60.0;
    double m_sensorDO    = 8.2;

    // Temperaturas internas para fusión (una por cada sensor RS-485)
    double m_tempPH = 24.5;
    double m_tempDO = 24.5;
    bool   m_tempPHValida = false;
    bool   m_tempDOValida = false;

    // ── Setpoints ─────────────────────────────────────────────────────────────
    double m_setpointTem   = 0.0;
    double m_setpointPH    = 0.0;
    double m_setpointLuz   = 0.0;

    // ── Alertas ───────────────────────────────────────────────────────────────
    bool m_alertaDivergenciaTemp = false;
    bool m_alertaSerial          = false;
    bool m_alertaNivel           = false;
    bool m_alertaSobreTemp       = false;
    bool m_alertaBombas          = false;
    // Watchdog de bombas: detecta bombas activas (llenado o drenado) sin cambio de nivel
    double m_distRefBomba        = -1.0;   // distancia mm de referencia
    int    m_ticksBombaSinCambio = 0;      // s con bombas activas y nivel estancado

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
    // Timer de escalación basado en ETA de calentamiento (estado 3)
    double m_etaInicialSeg         = -1.0;  // ETA_inicial fijado [s]; <0 = aún no fijado
    int    m_etaLockCnt            = 0;      // lecturas consecutivas de ETA estable
    int    m_etaLockPrevMin        = -1;     // último ETA en minutos (para comparar)
    int    m_segDesdeBloqueoEta    = 0;      // s transcurridos desde que se fijó ETA_inicial

    // Llenado óptimo
    double m_litrosAgua        = 0.0;
    double m_mlSustanciaB      = 0.0;
    int    m_ticksDosificacionB = 0;
    double m_salidaCalentador  = 0.0;
    double m_etaCalentamientoSeg = -1.0;   // ETA al setpoint de temperatura [s]; <0 = N/A
    double m_salidaBombaEtanol = 0.0;   // t_pulso calculado [s] — solo para monitoreo
    double m_salidaBombaAgua   = 0.0;
    bool   m_salidaBombaNivel  = false;

    // ── Control pH SISO — lazo de 30 s con pulso ─────────────────────────────
    int    m_contadorCicloPH      = 0;   // cuenta ticks de 1 s hasta TS_CONTROL_PH_S (30)
    int    m_tPulsoRestante       = 0;   // segundos restantes del pulso activo
    bool   m_pulsoNeutralizador   = false; // true: bomba neutralizadora ON en este tick

    // ── Umbrales de histéresis (configurables desde QML) ──────────────────────
    double m_nivelMaxPct  = 100.0;  // umbral superior [%] — 55 L, deshabilitar pH + drenar
    double m_nivelHistPct =  95.0;  // umbral inferior [%] — 50 L, rehabilitar pH

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

    // ── Cruce por cero — burst firing para calentador ────────────────────────────
    // El callback (GPIO27) cuenta semiciclos AC; onCrucePorCero() dispara ambas mantas
    // (CH_CALENTADOR + CH_CALENTADOR_2, en sincronía) según la potencia calculada por el
    // PID (0-100 en ventana de 100 semiciclos).
    int  m_zcContador   = 0;
    int  m_zcTotal      = 0;
    bool m_zcDisparando = false;
    static void callbackZC(int gpio, int level, uint32_t tick, void *userdata);

    double m_tickSim  = 0.0;
    int    m_nivelPaso  = 0;   // 0 = iniciar medición XM125, 1 = leer resultado
    int    m_fallosNivel = 0;

    // ── Protección de sobrellenado (histéresis en mm) ─────────────────────────
    double m_distanciaNivelMm = -1.0;   // última distancia aceptada [mm] (-1 = sin lectura)
    bool   m_drenandoNivel     = false;  // true: nivel alto → llenado off + drenado on

    QString m_nombreProyectoRegistro;
    QString m_nombreExpRegistro;
    QVector<QVariantMap> m_lecturas;
};
