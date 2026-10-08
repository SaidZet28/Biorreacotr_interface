#pragma once

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QDateTime>
#include <QMetaObject>
#include <QVariant>

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
    // Distancia del agua [mm] (<0 = sin lectura). Salida del seguidor de agua (filtro
    // predictivo con compuerta), NO la distancia cruda. Más confiable que el % mientras
    // DIST_VACIO_MM sea placeholder — se usa para el control, la seguridad y el llenado.
    Q_PROPERTY(double distanciaNivelMm READ distanciaNivelMm NOTIFY distanciaNivelMmChanged FINAL)
    // true = el seguidor está enganchado a un pico (siguiendo); false = coasting (sin
    // pico en la banda este ciclo, extrapolando). Indicador de confianza para la GUI.
    Q_PROPERTY(bool seguidorNivelHit READ seguidorNivelHit NOTIFY distanciaNivelMmChanged FINAL)

    // ── Vaciado manual (apartado en Opciones; solo con el equipo en reposo) ────
    // Estado ON/OFF de cada electroválvula de vaciado, para pintar los toggles.
    Q_PROPERTY(bool vaciadoManualInf READ vaciadoManualInf NOTIFY vaciadoManualChanged FINAL) // CH8
    Q_PROPERTY(bool vaciadoManualSup READ vaciadoManualSup NOTIFY vaciadoManualChanged FINAL) // CH10
    Q_PROPERTY(bool vaciadoManualAux READ vaciadoManualAux NOTIFY vaciadoManualChanged FINAL) // CH11

    // Temperatura del gabinete de la HMI (sensor interno del RTC DS3231). Indicador.
    // <0 = sin lectura disponible.
    Q_PROPERTY(double tempHmi     READ tempHmi     NOTIFY tempHmiChanged     FINAL)

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
    // Validez de datos: false = sin lecturas frescas (sensor desconectado) → GUI muestra "---"
    Q_PROPERTY(bool sensorSerialValido    READ sensorSerialValido    NOTIFY sensorSerialValidoChanged    FINAL)
    Q_PROPERTY(bool sensorNivelValido     READ sensorNivelValido     NOTIFY sensorNivelValidoChanged     FINAL)

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

    // ── Calibración del tanque (por tiempo + referencias) ─────────────────────
    Q_PROPERTY(double calibTLlenadoS   READ calibTLlenadoS   NOTIFY calibracionTanqueChanged FINAL)
    Q_PROPERTY(double calibTVaciadoS   READ calibTVaciadoS   NOTIFY calibracionTanqueChanged FINAL)
    Q_PROPERTY(double calibDVacioMm    READ calibDVacioMm    NOTIFY calibracionTanqueChanged FINAL)
    Q_PROPERTY(double calibDOperacionMm READ calibDOperacionMm NOTIFY calibracionTanqueChanged FINAL)

    // ── Preparación del tanque ────────────────────────────────────────────────
    Q_PROPERTY(int     estadoPreparacion       READ estadoPreparacion       NOTIFY estadoPreparacionChanged     FINAL)
    Q_PROPERTY(double  progresoPreparacion     READ progresoPreparacion     NOTIFY progresoPreparacionChanged   FINAL)
    Q_PROPERTY(bool    preparacionCompletada   READ preparacionCompletada   NOTIFY preparacionCompletadaChanged FINAL)
    Q_PROPERTY(bool    alertaEscalacion        READ alertaEscalacion        NOTIFY alertaEscalacionChanged      FINAL)
    Q_PROPERTY(QString textoTareaPreparacion   READ textoTareaPreparacion   NOTIFY estadoPreparacionChanged     FINAL)
    Q_PROPERTY(QString textoDetallePreparacion READ textoDetallePreparacion NOTIFY estadoPreparacionChanged     FINAL)
    // Segundos transcurridos en la fase de preparación en curso (para "tiempo transcurrido →
    // tiempo estimado"). Se refresca cada segundo junto con estadoPreparacionChanged.
    Q_PROPERTY(int     segFasePreparacion      READ segFasePreparacion      NOTIFY estadoPreparacionChanged     FINAL)
    // Etapa de vaciado por distancia (0=ninguna, 1=a EV superior/CH10, 2=a EV inferior/CH8).
    Q_PROPERTY(int     vaciadoEtapa            READ vaciadoEtapa            NOTIFY vaciadoEtapaChanged          FINAL)
    // true tras verificar sensores: la GUI pregunta si el tanque está vacío antes de llenar
    Q_PROPERTY(bool    esperandoConfirmacionVacio READ esperandoConfirmacionVacio NOTIFY esperandoConfirmacionVacioChanged FINAL)

    // ── Caracterización del sensor de nivel (herramienta de diagnóstico) ──────
    // Modo aislado: reinicia el XM125 como xm125_distance.py (reset + 100-2000 mm),
    // muestra TODOS los picos crudos y permite accionar actuadores a mano + grabar CSV.
    Q_PROPERTY(bool         caractActiva      READ caractActiva      NOTIFY caractActivaChanged      FINAL)
    Q_PROPERTY(QVariantList caractPicos       READ caractPicos       NOTIFY caractPicosChanged       FINAL)
    Q_PROPERTY(double       caractTempSensor  READ caractTempSensor  NOTIFY caractPicosChanged       FINAL)
    Q_PROPERTY(bool         caractNearEdge    READ caractNearEdge    NOTIFY caractPicosChanged       FINAL)
    Q_PROPERTY(int          caractNumMuestras READ caractNumMuestras NOTIFY caractPicosChanged       FINAL)
    Q_PROPERTY(bool         caractEV1         READ caractEV1         NOTIFY caractActuadoresChanged  FINAL)
    Q_PROPERTY(bool         caractEV2         READ caractEV2         NOTIFY caractActuadoresChanged  FINAL)
    Q_PROPERTY(bool         caractBurbujeo    READ caractBurbujeo    NOTIFY caractActuadoresChanged  FINAL)
    Q_PROPERTY(bool         caractBombas      READ caractBombas      NOTIFY caractActuadoresChanged  FINAL)
    Q_PROPERTY(bool         caractGrabando    READ caractGrabando    NOTIFY caractGrabandoChanged    FINAL)

public:
    explicit GestorBiorreactor(QObject *parent = nullptr);
    ~GestorBiorreactor();

    double sensorTem()   const;
    double sensorPH()    const;
    double sensorNivel() const;
    double sensorLuz()   const;
    double sensorDO()    const;
    double tempHmi()     const;
    double distanciaNivelMm() const;
    bool   seguidorNivelHit() const;

    double setpointTem()   const;
    double setpointPH()    const;
    double nivelLlenadoPct() const;
    double setpointLuz()   const;

    void setSetpointTem  (double v);
    void setSetpointPH   (double v);
    void setSetpointLuz  (double v);
    // Ajuste de la luz en vivo durante el proceso (fija % + escribe PWM a la tira LED al instante).
    Q_INVOKABLE void setLuzProceso(double pct);

    bool alertaDivergenciaTemp() const;
    bool alertaSerial()          const;
    bool alertaNivel()           const;
    bool alertaSobreTemp()       const;
    bool alertaBombas()          const;
    bool sensorSerialValido()    const;
    bool sensorNivelValido()     const;

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
    int     segFasePreparacion()      const;
    double  progresoPreparacion()     const;
    bool    preparacionCompletada()   const;
    bool    alertaEscalacion()        const;
    QString textoTareaPreparacion()   const;
    QString textoDetallePreparacion() const;
    bool    esperandoConfirmacionVacio() const;

    // ── Caracterización del sensor de nivel ───────────────────────────────────
    bool         caractActiva()      const;
    QVariantList caractPicos()       const;
    double       caractTempSensor()  const;
    bool         caractNearEdge()    const;
    int          caractNumMuestras() const;
    bool         caractEV1()         const;
    bool         caractEV2()         const;
    bool         caractBurbujeo()    const;
    bool         caractBombas()      const;
    bool         caractGrabando()    const;

    // Entra/sale del modo caracterización: al entrar pausa el lazo de nivel de
    // producción, reinicia el XM125 (reset + 100-2000 mm) y habilita OE. Al salir
    // apaga los 5 canales + OE HIGH y restaura la config de producción del sensor.
    Q_INVOKABLE void entrarCaracterizacion();
    Q_INVOKABLE void salirCaracterizacion();
    // Toggles manuales de actuadores (solo válidos con caractActiva):
    Q_INVOKABLE void caractToggleEV1();       // CH8  (electroválvula 1)
    Q_INVOKABLE void caractToggleEV2();       // CH10 (electroválvula 2)
    Q_INVOKABLE void caractToggleBurbujeo();  // CH2  (burbujeador)
    Q_INVOKABLE void caractToggleBombas();    // CH3+CH4 (bombas de llenado, en serie)
    // Grabación de datos on/off. Al detener escribe el CSV y devuelve su ruta ("" si nada).
    Q_INVOKABLE void    caractIniciarGrabacion();
    Q_INVOKABLE QString caractDetenerGrabacion();

    Q_INVOKABLE void enviarCalibracionPH(double ph4, double ph7, double ph10);
    Q_INVOKABLE void enviarCalibracionDO();

    void parsearTrama(const QByteArray &frame);

    Q_INVOKABLE void iniciarPreparacion();
    Q_INVOKABLE void cancelarPreparacion();
    // Re-sincroniza el seguidor de agua: lo re-arranca (re-acumula el pico más lejano en
    // rango durante ~4 s) para cuando el arranque se enganchó mal (p. ej. muestra "lleno"
    // con el tanque vacío). Pensado para el botón/popup de la pantalla de llenado.
    Q_INVOKABLE void resyncNivel();
    // Re-sync "en operación" (botón de la pantalla de procesos): re-adquiere el agua en la zona
    // de control SIN re-arrancar desde el vacío. Para cuando el filtro se clava cerca del 100 %.
    Q_INVOKABLE void resyncNivelOperacion();
    // Respuesta del operador a "¿tanque vacío?": arranca el llenado. Si está vacío se
    // usa el llenado ciego de 5 min (evita medir sin líquido); si no, mide de inmediato.
    Q_INVOKABLE void confirmarTanqueVacio(bool vacio);
    // Detiene el proceso de cultivo dejando el equipo en estado seguro (mantas y bombas
    // apagadas, OE HIGH, control y registro detenidos). Usar al Detener/Finalizar.
    Q_INVOKABLE void detenerProceso();
    // Apagado incondicional de TODOS los actuadores (16 canales a 0 + OE HIGH) y del
    // control. Red de seguridad: se llama al entrar a la pantalla de inicio, por si algo
    // quedó energizado (p. ej. tras un crash + reinicio automático de la app).
    Q_INVOKABLE void apagarActuadores();

    // ── Extracción / vaciado manual (pantalla de extracción) ──────────────────
    // nivel 1 → electroválvulas CH8 (VAC1) + CH10 (VAC2). nivel 2 → solo CH8 (VAC1).
    // iniciarVaciado habilita las salidas (OE LOW) y abre las válvulas correspondientes.
    // Vaciado por etapas AUTOMÁTICO por distancia (drena hasta la referencia y se para solo):
    //   nivel 1 → abre SOLO CH10 (EV superior), drena hasta DIST_EV_SUPERIOR_MM.
    //   nivel 2 → abre SOLO CH8  (EV inferior), drena hasta DIST_EV_INFERIOR_MM.
    // Al alcanzar la referencia (confirmación) cierra la válvula y emite vaciadoEtapaCompletada.
    // Con tope de tiempo VACIADO_TIMEOUT_S (emite vaciadoAbortado si se excede).
    Q_INVOKABLE void iniciarVaciado(int nivel);
    Q_INVOKABLE void detenerVaciado();     // paro de emergencia: cierra válvulas + cancela la etapa
    Q_INVOKABLE void finalizarVaciado();   // cierra válvulas + OE HIGH (estado seguro)
    int  vaciadoEtapa() const;

    // ── Vaciado manual (apartado en Opciones) — 3 toggles independientes ──────
    // cual: 0 = EV inferior (CH8), 1 = EV superior (CH10), 2 = EV vaciado 3 (CH11).
    // Solo actúa con el equipo en reposo (sin proceso ni caracterización activos).
    // El primer encendido habilita las salidas (OE LOW); cerrarVaciadoManual apaga
    // las 3 + OE HIGH (estado seguro) al salir del apartado.
    bool vaciadoManualInf() const;
    bool vaciadoManualSup() const;
    bool vaciadoManualAux() const;
    Q_INVOKABLE void toggleVaciadoManual(int cual);
    Q_INVOKABLE void cerrarVaciadoManual();

    // ── Calibración del tanque (menú en Ajustes) ──────────────────────────────
    // accion: 0=parar seguro, 1=llenar (CH3/CH4), 2=drenar (CH8+CH10). Habilita OE.
    Q_INVOKABLE void calibAccion(int accion);
    // Guarda los parámetros medidos: tiempo de llenado al nivel de operación [s], tiempo
    // de vaciado [s], y lecturas de radar de referencia en vacío y en operación [mm].
    Q_INVOKABLE void guardarCalibracionTanque(double tLlenadoS, double tVaciadoS,
                                              double dVacioMm, double dOperacionMm);
    double calibTLlenadoS()   const;
    double calibTVaciadoS()   const;
    double calibDVacioMm()    const;
    double calibDOperacionMm() const;
    Q_INVOKABLE void apagarSistema();   // paro seguro (canales 0 + OE HIGH) y apaga la RP
    // Modo reposo: apaga/enciende el backlight de la pantalla. NO toca actuadores ni el
    // proceso — solo la pantalla. El apagado total del equipo lo hace el botón físico.
    Q_INVOKABLE void pantallaReposo(bool dormir);
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
    Q_INVOKABLE QString montarUSB();   // intenta montar una USB no auto-montada (kiosko)

    Q_INVOKABLE QString rutaBaseData() const;
    Q_INVOKABLE void    eliminarCarpetaExperimento(const QString &nombreProyecto,
                                                    const QString &nombreExp);

    // ── Registro histórico de sensores ───────────────────────────────────────
    Q_INVOKABLE void iniciarRegistro(const QString &proyecto, const QString &experimento);
    Q_INVOKABLE void detenerRegistro();
    Q_INVOKABLE bool registroActivo() const;   // true si se están guardando lecturas
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
    void tempHmiChanged();
    void distanciaNivelMmChanged();

    void setpointTemChanged();
    void setpointPHChanged();
    void setpointLuzChanged();

    void alertaDivergenciaTempChanged();
    void alertaSerialChanged();
    void alertaNivelChanged();
    void alertaSobreTempChanged();
    void alertaBombasChanged();
    void sensorSerialValidoChanged();
    void sensorNivelValidoChanged();

    void procesoActivoChanged();

    void salidaCalentadorChanged();
    void etaCalentamientoSegChanged();
    void salidaBombaEtanolChanged();
    void salidaBombaAguaChanged();
    void salidaBombaNivelChanged();
    void pulsoNeutralizadorActivoChanged();
    void vaciadoManualChanged();
    void vaciadoEtapaChanged();
    void vaciadoEtapaCompletada(int etapa);   // la etapa llegó a su referencia y se detuvo sola
    void vaciadoAbortado(const QString &motivo); // tope de tiempo u otro paro del vaciado

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
    void esperandoConfirmacionVacioChanged();
    void calibracionTanqueChanged();
    void preparacionCancelada();

    void caractActivaChanged();
    void caractPicosChanged();
    void caractActuadoresChanged();
    void caractGrabandoChanged();

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
    void leerTempHmi();   // temperatura del RTC DS3231 (gabinete HMI) vía hwmon sysfs
    void tickCaracterizacion();   // mide picos crudos del XM125 en modo diagnóstico

private:
    void actualizarTemperaturaFusionada();
    void procesarBufferModbus();
    void evaluarSeguridadNivel();   // protección de sobrellenado en mm + drenado

    // Vaciado por etapas: monitorea la distancia y corta al llegar a la referencia.
    // Se llama desde leerSensorNivel() con cada lectura fresca del nivel.
    void   procesarVaciadoAuto();

    // ── Seguidor de agua (filtro predictivo con compuerta, portado del banco) ──
    // Elige, de TODOS los picos crudos del XM125, el que corresponde al agua por su
    // MOVIMIENTO (no por ser el más fuerte). Alimenta m_distanciaNivelMm.
    void   actualizarSeguidorNivel(const QVector<double> &dists);
    double baseBandaNivel(double x) const;   // banda base por zona (mm)
    int    direccionNivel() const;           // -1 llenando, +1 drenando, 0 estático

    void setSensorTem  (double v);
    void setSensorPH   (double v);
    void setSensorNivel(double v);
    void setSetpointNivel(double) {} // stub vacío — nivel ya no es configurable por usuario
    void setSensorLuz  (double v);
    void setSensorDO   (double v);
    void setTempHmi    (double v);

    void setAlertaDivergenciaTemp(bool v);
    void setAlertaSerial(bool v);
    void setAlertaNivel (bool v);
    void setAlertaSobreTemp(bool v);
    void setAlertaBombas(bool v);
    void setSensorSerialValido(bool v);
    void setSensorNivelValido(bool v);
    void resetWatchdogSerial();

    void setEstadoPreparacion(int estado);
    void setProgresoPreparacion(double v);
    void setPreparacionCompletada(bool v);
    void setAlertaEscalacion(bool v);

    // ── Valores de sensores ───────────────────────────────────────────────────
    double m_sensorTem   = 24.5;
    double m_tAmbiente   = 24.5;   // Temperatura ambiente capturada al arrancar el proceso
    double m_sensorPH    = 7.2;
    double m_sensorNivel = 85.0;
    double m_sensorLuz   = 60.0;
    double m_sensorDO    = 8.2;
    double m_tempHmi     = -1.0;   // temperatura del RTC DS3231 (gabinete); <0 = sin lectura

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
    bool m_sensorSerialValido    = true;   // hay datos RS-485 frescos (temp/pH/DO)
    bool m_sensorNivelValido     = true;   // hay datos I2C frescos (nivel)
    // Watchdog de bombas: detecta bombas activas (llenado o drenado) sin cambio de nivel
    double m_distRefBomba        = -1.0;   // distancia mm de referencia
    int    m_ticksBombaSinCambio = 0;      // s con bombas activas y nivel estancado
    int    m_ticksNivelAlto      = 0;      // confirmación de cruce del umbral alto (histéresis)
    int    m_ticksNivelSeguro    = 0;      // confirmación de cruce del umbral seguro (histéresis)
    // Auto-rellenado (lado bajo de la histéresis): si el nivel cae bajo el objetivo por un
    // vaciado accidental, rellena (CH3/CH4) de vuelta a 216. Activo con proceso y fuera del
    // Llenado de preparación. Confirmación para no reaccionar a un salto espurio del radar.
    bool   m_rellenandoNivel     = false;  // true: nivel bajo → llenado on hasta el objetivo
    int    m_ticksNivelBajo      = 0;      // confirmación de cruce del umbral bajo (empezar a rellenar)
    int    m_ticksNivelLleno     = 0;      // confirmación de llegada al objetivo (parar de rellenar)

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
    int    m_ticksNivelObjetivo    = 0;   // lecturas consecutivas en objetivo (confirmación)
    int    m_accionLlenado         = -99; // acción actual del llenado: 1=llenar, -1=drenar, 0=parar
    bool   m_radarConfiable        = false; // el radar ya lee confiable (agua ≥ referencia)
    int    m_ticksRadarConf        = 0;     // confirmación de radar confiable durante llenado ciego
    int    m_tGuiadoInicio         = 0;     // m_ticksPrep al empezar el tramo guiado de llenado
    double m_distInicioGuiado      = -1.0;  // distancia al empezar el tramo guiado (para plausibilidad)
    bool   m_esperandoConfirmacionVacio = false;  // esperando respuesta de "¿tanque vacío?"
    bool   m_tanqueVacio           = true;        // respuesta del operador (afecta llenado ciego)

    // Calibración del tanque (por tiempo + referencias; persistida en QSettings)
    double m_calibTLlenadoS    = 0.0;   // s de llenado de vacío al nivel de operación
    double m_calibTVaciadoS    = 0.0;   // s de vaciado
    double m_calibDVacioMm     = -1.0;  // lectura de radar de referencia en vacío
    double m_calibDOperacionMm = -1.0;  // lectura de radar de referencia en operación
    // Timer de escalación basado en ETA de calentamiento (estado 3)
    double m_etaInicialSeg         = -1.0;  // ETA_inicial fijado [s]; <0 = aún no fijado
    int    m_etaLockCnt            = 0;      // lecturas consecutivas de ETA estable
    int    m_etaLockPrevMin        = -1;     // último ETA en minutos (para comparar)
    int    m_segDesdeBloqueoEta    = 0;      // s transcurridos desde que se fijó ETA_inicial

    double m_salidaCalentador  = 0.0;
    double m_etaCalentamientoSeg = -1.0;   // ETA al setpoint de temperatura [s]; <0 = N/A
    double m_salidaBombaEtanol = 0.0;   // t_pulso calculado [s] — solo para monitoreo
    double m_salidaBombaAgua   = 0.0;   // indicador de llenado con el medio (0/100)
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
    QTimer m_timerTempHmi;        // 5000 ms — lee la temperatura del RTC DS3231 (gabinete)

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
    long m_zcDebug      = 0;   // DIAG: cuenta total de cruces por cero (¿el ZC dispara?)
    int  m_zcReafirmar  = 0;   // re-afirma los canales del calentador cada N cruces (anti escritura perdida)
    static void callbackZC(int gpio, int level, uint32_t tick, void *userdata);

    double m_tickSim  = 0.0;
    int    m_nivelPaso  = 0;   // 0 = iniciar medición XM125, 1 = leer resultado
    int    m_fallosNivel = 0;

    // ── Protección de sobrellenado (histéresis en mm) ─────────────────────────
    double m_distanciaNivelMm = -1.0;   // nivel del agua [mm] (salida del seguidor; -1 = sin lectura)
    bool   m_drenandoNivel     = false;  // true: nivel alto → llenado off + drenado on

    // ── Estado del seguidor de agua (mini α-β predictivo con compuerta) ───────
    // Vaciado manual (apartado en Opciones): estado ON/OFF de cada EV (CH8/CH10/CH11)
    bool m_vaciadoManualInf = false;   // CH8
    bool m_vaciadoManualSup = false;   // CH10
    bool m_vaciadoManualAux = false;   // CH11

    // Vaciado por etapas automático (pantalla de extracción): 0=ninguna, 1=EV superior (CH10),
    // 2=EV inferior (CH8). Corta al llegar a la referencia (confirmación) o por tope de tiempo.
    int       m_vaciadoEtapa        = 0;
    int       m_ticksVaciadoConfirm = 0;   // lecturas consecutivas en/pasada la referencia
    QDateTime m_vaciadoDeadline;           // tope de tiempo de la etapa en curso

    double m_nivelFiltrado  = -1.0;   // nivel filtrado [mm] (valor reportado; espejo de m_distanciaNivelMm)
    double m_anchorNivel    = -1.0;   // último valor CONFIRMADO (ancla anti-fuga)
    double m_velNivel       = 0.0;    // velocidad estimada [mm/s] (negativa al llenar)
    int    m_trackMissNivel = 0;      // frames consecutivos sin pico en la banda
    bool   m_trackInitNivel = false;  // el seguidor ya arrancó
    bool   m_seguidorHit    = false;  // último frame: true=siguió un pico, false=coasting
    qint64 m_trackPrevMsNivel   = 0;    // timestamp del último update (ms)
    int    m_stuckFramesNivel   = 0;    // frames sin avanzar en la dirección esperada
    double m_ultimoAnchorMovido = -1.0; // último ancla que sí avanzó (checkpoint de escape)
    // Re-adquisición en estático (zona de control): candidato consistente y bandera de re-sync manual.
    double m_reacqCand          = -1.0; // candidato de re-adquisición en curso
    int    m_reacqCount         = 0;    // cuadros consecutivos con el candidato
    bool   m_forzarReacqNivel   = false;// botón "Re-sync" de la pantalla de procesos (salto inmediato)
    int    m_initSamplesNivel   = 0;    // frames acumulados para el arranque robusto
    double m_initMaxFarNivel    = -1.0; // pico más lejano visto durante el arranque
    double m_tasaVaciadoNivel   = 3.0;  // mm/s esperado al drenar (empuja la predicción)

    QString m_nombreProyectoRegistro;
    QString m_nombreExpRegistro;
    QVector<QVariantMap> m_lecturas;

    // ── Caracterización del sensor de nivel (herramienta de diagnóstico) ──────
    void    caractRegistrarEvento(const QString &actuador, bool estado);
    QString caractEscribirCSV();

    QTimer  m_timerCaracterizacion;          // ~500 ms — mide picos crudos
    bool    m_caractActiva     = false;
    bool    m_caractEV1        = false;      // CH8
    bool    m_caractEV2        = false;      // CH10
    bool    m_caractBurbujeo   = false;      // CH2
    bool    m_caractBombas     = false;      // CH3+CH4
    bool    m_caractGrabando   = false;
    bool    m_caractNearEdge   = false;
    double  m_caractTempSensor = 0.0;
    QVariantList m_caractPicos;              // última tabla de picos [{dist,raw,q16,db}]
    QDateTime m_caractInicioGrab;
    QVector<QVariantMap> m_caractMuestras;   // timeline: muestras ("M") + eventos ("E")
};
