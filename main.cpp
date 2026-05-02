#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "translationmanager.h" // Ojo: en tu foto está con minúsculas, déjalo como lo tienes

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    TranslationManager traductorManager(&app, &engine);
    engine.rootContext()->setContextProperty("TraductorC", &traductorManager);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Prototipo", "Main");

    return QCoreApplication::exec();
}
