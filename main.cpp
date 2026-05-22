#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include "translationmanager.h"
#include "gestorbiorreactor.h"

int main(int argc, char *argv[])
{
    // En Linux (Raspberry Pi) forzamos OpenGL para que QtCharts funcione correctamente.
    // En Windows el backend D3D11 por defecto causa crash con MinGW + QtCharts,
    // por eso la gráfica queda desactivada en Windows (condición en PantallaProcesos.qml).
#ifdef Q_OS_LINUX
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
#endif

    QGuiApplication app(argc, argv);

    GestorBiorreactor backend;  // outer scope → destroyed AFTER engine

    {
        QQmlApplicationEngine engine;

        TranslationManager traductorManager(&app, &engine);
        engine.rootContext()->setContextProperty("TraductorC", &traductorManager);
        engine.rootContext()->setContextProperty("backend", &backend);

        QObject::connect(
            &engine,
            &QQmlApplicationEngine::objectCreationFailed,
            &app,
            []() { QCoreApplication::exit(-1); },
            Qt::QueuedConnection);
        engine.loadFromModule("Prototipo", "Main");

        return QCoreApplication::exec();
        // engine + traductorManager destroyed here (scope unwinds before return)
    }
}
