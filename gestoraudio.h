#pragma once

#include <QObject>
#include <QSoundEffect>

// Reproduce efectos de sonido desde archivos WAV embebidos como recursos Qt.
// El volumen final es hardware (perilla física en el módulo amplificador).
class GestorAudio : public QObject
{
    Q_OBJECT
public:
    explicit GestorAudio(QObject *parent = nullptr);

public slots:
    // Tres pulsos agudos — alarma crítica (temperatura, nivel)
    void reproducirAlerta();
    // Dos pitidos cortos — advertencia (serial, escalación)
    void reproducirAdvertencia();
    // Tres tonos ascendentes — operación completada con éxito
    void reproducirExito();
    // Pitido simple — inicio de proceso
    void reproducirInicio();

private:
    QSoundEffect m_alerta;
    QSoundEffect m_advertencia;
    QSoundEffect m_exito;
    QSoundEffect m_inicio;
};
