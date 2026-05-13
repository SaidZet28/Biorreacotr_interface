#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "SensorPH.h"
#include <QStringConverter> // Habilita los literales de cadena de Qt
using namespace Qt::Literals::StringLiterals; // Permite el uso de _s

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    SensorPH phLogic; // Instancia global de la lógica
    QQmlApplicationEngine engine;

    // "phHandler" es el nombre que usaremos en el archivo QML
    engine.rootContext()->setContextProperty("phHandler", &phLogic);

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/RK50012_pH/main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;

    return app.exec();
}
