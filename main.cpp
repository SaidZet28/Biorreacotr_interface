#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "translationmanager.h"
#include "gestorbiorreactor.h"

int main(int argc, char *argv[])
{
    // En Qt 6, el backend gráfico por defecto en Windows es D3D11 (no OpenGL ni ANGLE).
    // AA_UseDesktopOpenGL forzaba OpenGL, lo cual causa crash con MinGW al inicializar
    // QtCharts en Windows. Se elimina para usar D3D11 por defecto.

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
