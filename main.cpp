#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QFont>
#include <QFontDatabase>
#include <QTimer>
#include <csignal>
#ifdef Q_OS_LINUX
#include <execinfo.h>
#include <unistd.h>
#endif
#include "translationmanager.h"
#include "gestorbiorreactor.h"
#include "gestoraudio.h"

// Bandera puesta por el manejador de señales (solo escritura async-signal-safe). Un
// timer en el hilo de Qt la revisa y cierra la app ordenadamente (corre el destructor
// de GestorBiorreactor → estado seguro). Ver más abajo.
namespace { volatile std::sig_atomic_t g_pararSolicitado = 0; }

#ifdef Q_OS_LINUX
// Manejador de crash: al recibir SIGSEGV/SIGABRT/SIGBUS/SIGFPE imprime el backtrace a
// stderr (→ journald) y re-lanza con la acción por defecto para terminar (systemd
// reinicia). backtrace()/backtrace_symbols_fd() no usan malloc → aptos en un handler.
// Requiere que pigpio NO instale sus propios manejadores (ver DriverPCA9685).
static void manejarCrash(int sig)
{
    // Primero el corte físico: OE HIGH deshabilita todos los actuadores aunque el
    // proceso muera con canales encendidos (pigpio no resetea el pin al salir).
    DriverPCA9685::corteEmergencia();
    void *marcos[64];
    int n = backtrace(marcos, 64);
    const char cab[] = "\n=== CRASH appPrototipo: backtrace ===\n";
    ssize_t r = ::write(STDERR_FILENO, cab, sizeof(cab) - 1); (void)r;
    backtrace_symbols_fd(marcos, n, STDERR_FILENO);
    std::signal(sig, SIG_DFL);
    ::raise(sig);
}
#endif

int main(int argc, char *argv[])
{
#ifdef Q_OS_LINUX
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
#endif

    QGuiApplication app(argc, argv);

#ifdef Q_OS_LINUX
    QFontDatabase::addApplicationFont(":/fonts/DejaVuSans.ttf");
    QFontDatabase::addApplicationFont(":/fonts/DejaVuSans-Bold.ttf");
    QGuiApplication::setFont(QFont("DejaVu Sans"));
#endif

    GestorBiorreactor backend;
    GestorAudio       audio;

#ifdef Q_OS_LINUX
    // Instalar el manejador de crash DESPUÉS de construir el backend (que ya inicializó
    // pigpio con PI_CFG_NOSIGHANDLER) para asegurar que nuestro handler quede activo.
    std::signal(SIGSEGV, manejarCrash);
    std::signal(SIGABRT, manejarCrash);
    std::signal(SIGBUS,  manejarCrash);
    std::signal(SIGFPE,  manejarCrash);
#endif

    // ── Conexiones de audio ───────────────────────────────────────────────────
    // Alarmas críticas
    QObject::connect(&backend, &GestorBiorreactor::alertaDivergenciaTempChanged, &audio,
        [&]{ if (backend.alertaDivergenciaTemp()) audio.reproducirAlerta(); });
    QObject::connect(&backend, &GestorBiorreactor::alertaNivelChanged, &audio,
        [&]{ if (backend.alertaNivel()) audio.reproducirAlerta(); });
    QObject::connect(&backend, &GestorBiorreactor::alertaSerialChanged, &audio,
        [&]{ if (backend.alertaSerial()) audio.reproducirAdvertencia(); });
    QObject::connect(&backend, &GestorBiorreactor::alertaSobreTempChanged, &audio,
        [&]{ if (backend.alertaSobreTemp()) audio.reproducirAlerta(); });
    QObject::connect(&backend, &GestorBiorreactor::alertaBombasChanged, &audio,
        [&]{ if (backend.alertaBombas()) audio.reproducirAdvertencia(); });
    QObject::connect(&backend, &GestorBiorreactor::alertaCruceCeroChanged, &audio,
        [&]{ if (backend.alertaCruceCero()) audio.reproducirAlerta(); });
    QObject::connect(&backend, &GestorBiorreactor::sensoresRS485Changed, &audio,
        [&]{ if (backend.procesoActivo() && (!backend.sensorPHValido() || !backend.sensorDOValido()))
                 audio.reproducirAdvertencia(); });

    // Preparación del tanque
    QObject::connect(&backend, &GestorBiorreactor::alertaEscalacionChanged, &audio,
        [&]{ if (backend.alertaEscalacion()) audio.reproducirAdvertencia(); });
    QObject::connect(&backend, &GestorBiorreactor::preparacionCompletadaChanged, &audio,
        [&]{ if (backend.preparacionCompletada()) audio.reproducirExito(); });

    // Inicio y fin de proceso (procesoActivo true→false = proceso detenido; false→true = iniciado)
    QObject::connect(&backend, &GestorBiorreactor::procesoActivoChanged, &audio,
        [&]{ if (backend.procesoActivo()) audio.reproducirInicio(); });

    {
        QQmlApplicationEngine engine;

        TranslationManager traductorManager(&app, &engine);
        engine.rootContext()->setContextProperty("TraductorC", &traductorManager);
        engine.rootContext()->setContextProperty("backend", &backend);
        engine.rootContext()->setContextProperty("audio", &audio);

        QObject::connect(
            &engine,
            &QQmlApplicationEngine::objectCreationFailed,
            &app,
            []() { QCoreApplication::exit(-1); },
            Qt::QueuedConnection);
        engine.loadFromModule("Prototipo", "Main");

        // Apagado limpio ante SIGTERM/SIGINT (systemctl stop/restart). El manejador solo
        // pone la bandera; un timer la revisa y cierra la app → corre el destructor de
        // backend (OE HIGH + cierra serial). Necesario porque pigpio ya NO maneja señales.
        std::signal(SIGTERM, [](int){ g_pararSolicitado = 1; });
        std::signal(SIGINT,  [](int){ g_pararSolicitado = 1; });
        QTimer timerSenales;
        QObject::connect(&timerSenales, &QTimer::timeout, &app, [&]{
            if (g_pararSolicitado) app.quit();
        });
        timerSenales.start(150);

        return QCoreApplication::exec();
    }
}
