#include "translationmanager.h"
#include <QDebug> // Para ver errores en consola si no encuentra el archivo

TranslationManager::TranslationManager(QGuiApplication *app, QQmlApplicationEngine *engine, QObject *parent)
    : QObject(parent), m_app(app), m_engine(engine)
{
}

void TranslationManager::cambiarIdioma(QString idioma)
{
    // Si es Español, quitamos el traductor porque es el idioma base de la app
    if (idioma == "es") {
        m_app->removeTranslator(&m_translator);
        m_engine->retranslate();
    }
    // Para cualquier otro idioma (en, de, fr, zh, ja)
    else {
        // Armamos el nombre del archivo mágicamente (ej. ":/i18n/appPrototipo_de.qm")
        QString archivoIdioma = ":/i18n/appPrototipo_" + idioma + ".qm";

        if (m_translator.load(archivoIdioma)) {
            m_app->installTranslator(&m_translator);
            m_engine->retranslate(); // Esto actualiza todo QML al instante
        } else {
            qDebug() << "❌ ¡Error! No se pudo cargar el archivo de traducción:" << archivoIdioma;
        }
    }
}