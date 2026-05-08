#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "translationmanager.h"
#include "gestorbiorreactor.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    TranslationManager traductorManager(&app, &engine);
    engine.rootContext()->setContextProperty("TraductorC", &traductorManager);

    GestorBiorreactor backend;
    engine.rootContext()->setContextProperty("backend", &backend);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Prototipo", "Main");

    return QCoreApplication::exec();
}
