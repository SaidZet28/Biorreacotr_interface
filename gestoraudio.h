#pragma once

#include <QObject>
#include <QAudioSink>
#include <QBuffer>
#include <QAudioFormat>
#include <QByteArray>
#include <QList>

// Genera y reproduce tonos sinusoidales puros mediante QAudioSink.
// El volumen es hardware (perilla física); esta clase no expone control de volumen.
class GestorAudio : public QObject
{
    Q_OBJECT
public:
    explicit GestorAudio(QObject *parent = nullptr);
    ~GestorAudio();

public slots:
    // Tono intermitente agudo — alarma crítica (temperatura, nivel)
    void reproducirAlerta();
    // Dos pitidos cortos — advertencia (escalación en preparación)
    void reproducirAdvertencia();
    // Tres tonos ascendentes — operación completada con éxito
    void reproducirExito();
    // Pitido simple — inicio de proceso
    void reproducirInicio();

private:
    struct Nota { double frecuencia; int duracionMs; };

    QByteArray generarPCM(const QList<Nota> &secuencia);
    QByteArray generarTono(double frecuencia, int duracionMs);
    QByteArray generarSilencio(int duracionMs);

    void reproducir(const QByteArray &pcm);

    QAudioFormat  m_formato;
    QAudioSink   *m_sink   = nullptr;
    QBuffer       m_buffer;
};
