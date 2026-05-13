#pragma once
#include <QObject>
#include <QPair>
#include <QVector>
#include <QString>
#include <algorithm>

namespace FuzzyMath {
    inline double trimf(double x, double a, double b, double c) {
        if (x <= a || x >= c) return 0.0;
        if (x <= b) return (x - a) / (b - a);
        return (c - x) / (c - b);
    }
    inline double trapmf(double x, double a, double b, double c, double d) {
        if (x <= a || x >= d) return 0.0;
        if (x >= b && x <= c) return 1.0;
        if (x < b) return (x - a) / (b - a);
        return (d - x) / (d - c);
    }
}

struct ConjuntoDifuso {
    QString        nombre;
    QVector<double> params;
    QString        tipo;   // "trimf" o "trapmf"

    double evaluar(double x) const {
        if (tipo == "trimf")  return FuzzyMath::trimf (x, params[0], params[1], params[2]);
        if (tipo == "trapmf") return FuzzyMath::trapmf(x, params[0], params[1], params[2], params[3]);
        return 0.0;
    }
};

struct ReglaFuzzy {
    QString entradaNombre;
    QString salidaNombre;
    QString salida;   // "ETANOL" o "AGUA"
};

class ControladorFuzzy : public QObject {
    Q_OBJECT
public:
    explicit ControladorFuzzy(QObject *parent = nullptr);

    // Devuelve {potenciaEtanol 0-100, potenciaAgua 0-100}
    // Convenio: error = setpointPH - phMedido
    //   error > 0 → pH demasiado bajo → bomba AGUA sube pH
    //   error < 0 → pH demasiado alto → bomba ETANOL baja pH
    QPair<double, double> calcular(double phSetpoint, double phMedido);

private:
    double defuzzificar(double error,
                        const QVector<ConjuntoDifuso> &salida,
                        const QString &target) const;

    QVector<ConjuntoDifuso> m_errorPH;
    QVector<ConjuntoDifuso> m_salidaEtanol;
    QVector<ConjuntoDifuso> m_salidaAgua;
    QVector<ReglaFuzzy>     m_reglas;
};
