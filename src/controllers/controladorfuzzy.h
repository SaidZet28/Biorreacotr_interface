#pragma once
#include <QObject>
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
    QString         nombre;
    QVector<double> params;
    QString         tipo;   // "trimf" o "trapmf"

    double evaluar(double x) const {
        if (tipo == "trimf")  return FuzzyMath::trimf (x, params[0], params[1], params[2]);
        if (tipo == "trapmf") return FuzzyMath::trapmf(x, params[0], params[1], params[2], params[3]);
        return 0.0;
    }
};

struct ReglaFuzzy {
    QString entradaNombre;
    QString salidaNombre;
};

// ─────────────────────────────────────────────────────────────────────────────
//  ControladorFuzzy — SISO Mamdani para control de pH
//
//  Entrada : error = setpointPH − phMedido   →  e ∈ [0, 3.5]
//            Pre-filtro externo: si e ≤ 0 no se llama a calcular()
//  Salida  : t_pulso [s]  ∈ [0, 7]  — tiempo de activación de la bomba
//            neutralizadora al 100% dentro del ciclo de Ts = 30 s
//
//  Conjuntos de entrada (5): N, PE, ME, GE, MG
//  Conjuntos de salida  (5): OFF, POCO, MEDIO, MUCHO, MAX
//  Reglas               (5): una por conjunto de entrada
//
//  Justificación asimétrica: la caracterización experimental mostró que la
//  ganancia del sistema cae a ~0.006 pH/ciclo en la zona muy ácida (e > 2.5),
//  por lo que los conjuntos de error grande y muy grande abarcan rangos más
//  amplios para anticipar la acción correctiva.
// ─────────────────────────────────────────────────────────────────────────────
class ControladorFuzzy : public QObject {
    Q_OBJECT
public:
    explicit ControladorFuzzy(QObject *parent = nullptr);

    // Devuelve t_pulso ∈ [0, 7] s
    // PRECONDICIÓN: llamar solo cuando error > 0 y nivel < 85%
    double calcular(double phSetpoint, double phMedido);

private:
    double defuzzificar(double error) const;

    QVector<ConjuntoDifuso> m_errorPH;   // MFs de entrada
    QVector<ConjuntoDifuso> m_tPulso;    // MFs de salida
    QVector<ReglaFuzzy>     m_reglas;
};
