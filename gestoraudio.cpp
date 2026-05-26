#include "gestoraudio.h"
#include <QMediaDevices>
#include <QtMath>
#include <QDebug>

static constexpr int    SAMPLE_RATE  = 22050;
static constexpr double AMPLITUD     = 0.55;   // 0–1; la perilla física controla el volumen real

GestorAudio::GestorAudio(QObject *parent) : QObject(parent)
{
    m_formato.setSampleRate(SAMPLE_RATE);
    m_formato.setChannelCount(1);
    m_formato.setSampleFormat(QAudioFormat::Int16);

    const QAudioDevice dispositivo = QMediaDevices::defaultAudioOutput();
    if (!dispositivo.isFormatSupported(m_formato)) {
        qWarning() << "[Audio] Formato PCM Int16 22050 Hz no soportado en este dispositivo";
        return;
    }

    m_sink = new QAudioSink(dispositivo, m_formato, this);
}

GestorAudio::~GestorAudio()
{
    if (m_sink) m_sink->stop();
}

// ── Tonos predefinidos ────────────────────────────────────────────────────────

void GestorAudio::reproducirAlerta()
{
    // Tres pulsos agudos de 880 Hz — señal de alarma crítica
    reproducir(generarPCM({
        {880, 180}, {0, 80},
        {880, 180}, {0, 80},
        {880, 180}
    }));
}

void GestorAudio::reproducirAdvertencia()
{
    // Dos pitidos de tono medio — advertencia no crítica
    reproducir(generarPCM({
        {660, 200}, {0, 120},
        {660, 200}
    }));
}

void GestorAudio::reproducirExito()
{
    // Acorde ascendente Do-Mi-Sol — confirmación de éxito
    reproducir(generarPCM({
        {523, 150}, {0, 40},
        {659, 150}, {0, 40},
        {784, 300}
    }));
}

void GestorAudio::reproducirInicio()
{
    // Pitido único — inicio de proceso
    reproducir(generarPCM({
        {440, 250}
    }));
}

// ── Generación PCM ────────────────────────────────────────────────────────────

QByteArray GestorAudio::generarTono(double frecuencia, int duracionMs)
{
    int muestras = SAMPLE_RATE * duracionMs / 1000;
    QByteArray data;
    data.resize(muestras * sizeof(qint16));
    qint16 *ptr = reinterpret_cast<qint16 *>(data.data());

    // Envolvente ADSR simplificada: ataque 10 ms, decaimiento 10 ms
    int ataqueMuestras = qMin(SAMPLE_RATE * 10 / 1000, muestras / 4);
    int decaimientoMuestras = qMin(SAMPLE_RATE * 10 / 1000, muestras / 4);

    for (int i = 0; i < muestras; ++i) {
        double env = 1.0;
        if (i < ataqueMuestras)
            env = static_cast<double>(i) / ataqueMuestras;
        else if (i > muestras - decaimientoMuestras)
            env = static_cast<double>(muestras - i) / decaimientoMuestras;

        double muestra = AMPLITUD * env * qSin(2.0 * M_PI * frecuencia * i / SAMPLE_RATE);
        ptr[i] = static_cast<qint16>(muestra * 32767.0);
    }
    return data;
}

QByteArray GestorAudio::generarSilencio(int duracionMs)
{
    int muestras = SAMPLE_RATE * duracionMs / 1000;
    return QByteArray(muestras * sizeof(qint16), 0);
}

QByteArray GestorAudio::generarPCM(const QList<Nota> &secuencia)
{
    QByteArray resultado;
    for (const Nota &n : secuencia) {
        if (n.frecuencia <= 0.0)
            resultado += generarSilencio(n.duracionMs);
        else
            resultado += generarTono(n.frecuencia, n.duracionMs);
    }
    return resultado;
}

void GestorAudio::reproducir(const QByteArray &pcm)
{
    if (!m_sink) return;

    m_sink->stop();
    m_buffer.close();
    m_buffer.setData(pcm);
    m_buffer.open(QIODevice::ReadOnly);
    m_sink->start(&m_buffer);
}
