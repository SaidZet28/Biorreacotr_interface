#ifndef TRANSLATIONMANAGER_H
#define TRANSLATIONMANAGER_H

#include <QObject>
#include <QTranslator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

class TranslationManager : public QObject
{
    Q_OBJECT
public:
    explicit TranslationManager(QGuiApplication *app, QQmlApplicationEngine *engine, QObject *parent = nullptr);

    // Esta función la vamos a llamar desde QML
    Q_INVOKABLE void cambiarIdioma(QString idioma);

private:
    QTranslator m_translator;
    QGuiApplication *m_app;
    QQmlApplicationEngine *m_engine;
};

#endif // TRANSLATIONMANAGER_H