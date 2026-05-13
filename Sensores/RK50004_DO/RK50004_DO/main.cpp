#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "sensordo.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    SensorDO doLogic;
    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("doHandler", &doLogic);

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/RK50004_DO/main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;

    return app.exec();
}
