#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QFont>
#include <QFontDatabase>
#include "translationmanager.h"
#include "gestorbiorreactor.h"
#include "gestoraudio.h"

int main(int argc, char *argv[])
{
#ifdef Q_OS_LINUX
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
#endif

    QGuiApplication app(argc, argv);

#ifdef Q_OS_LINUX
    QFontDatabase::addApplicationFont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
    QFontDatabase::addApplicationFont("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf");
    QFont defaultFont("DejaVu Sans");
    QGuiApplication::setFont(defaultFont);
#endif

    GestorBiorreactor backend;
    GestorAudio       audio;

    // ── Conexiones de audio ───────────────────────────────────────────────────
    // Alarmas críticas
    QObject::connect(&backend, &GestorBiorreactor::alertaDivergenciaTempChanged, &audio,
        [&]{ if (backend.alertaDivergenciaTemp()) audio.reproducirAlerta(); });
    QObject::connect(&backend, &GestorBiorreactor::alertaNivelChanged, &audio,
        [&]{ if (backend.alertaNivel()) audio.reproducirAlerta(); });
    QObject::connect(&backend, &GestorBiorreactor::alertaSerialChanged, &audio,
        [&]{ if (backend.alertaSerial()) audio.reproducirAdvertencia(); });

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

        return QCoreApplication::exec();
    }
}
