#include "gestoraudio.h"
#include <QDebug>

GestorAudio::GestorAudio(QObject *parent) : QObject(parent)
{
    m_alerta.setSource(QUrl("qrc:/audio/alerta.wav"));
    m_advertencia.setSource(QUrl("qrc:/audio/advertencia.wav"));
    m_exito.setSource(QUrl("qrc:/audio/exito.wav"));
    m_inicio.setSource(QUrl("qrc:/audio/inicio.wav"));

    for (QSoundEffect *s : {&m_alerta, &m_advertencia, &m_exito, &m_inicio}) {
        s->setVolume(1.0f);
        QObject::connect(s, &QSoundEffect::statusChanged, [s]() {
            if (s->status() == QSoundEffect::Error)
                qWarning() << "[Audio] Error cargando:" << s->source();
        });
    }
}

void GestorAudio::reproducirAlerta()      { m_alerta.play();      }
void GestorAudio::reproducirAdvertencia() { m_advertencia.play(); }
void GestorAudio::reproducirExito()       { m_exito.play();       }
void GestorAudio::reproducirInicio()      { m_inicio.play();      }
