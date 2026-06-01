#include "controladorfuzzy.h"
#include <algorithm>

ControladorFuzzy::ControladorFuzzy(QObject *parent) : QObject(parent)
{
    // Conjuntos de entrada: error pH = setpoint - medido  (rango -6 a +6)
    // Negativos → pH demasiado alto → bomba ETANOL (baja pH)
    // Positivos → pH demasiado bajo → bomba AGUA (sube pH)
    m_errorPH = {
        {"AA", {-6.0, -6.0, -5.5, -4.5}, "trapmf"},
        {"MA", {-6.0, -4.0, -3.0},        "trimf" },
        {"BA", {-4.0, -2.0,  0.0},        "trimf" },
        {"N",  {-0.5,  0.0,  0.5},        "trimf" },
        {"BB", { 0.0,  2.0,  4.0},        "trimf" },
        {"MB", { 3.0,  4.0,  6.0},        "trimf" },
        {"AB", { 4.5,  5.0,  6.0,  6.0},  "trapmf"}
    };

    // Conjuntos de salida: potencia de bomba (0-100 %)
    QVector<ConjuntoDifuso> sets = {
        {"OFF", {  0.0,   0.0,   0.0},        "trimf" },
        {"BP",  {  0.0,  10.0,  40.0},        "trimf" },
        {"MBP", { 30.0,  40.0,  50.0},        "trimf" },
        {"MP",  { 40.0,  50.0,  65.0},        "trimf" },
        {"MAP", { 60.0,  70.0,  90.0},        "trimf" },
        {"AP",  { 80.0,  95.0, 100.0, 100.0}, "trapmf"},
        {"ALL", {100.0, 100.0, 100.0},        "trimf" }
    };
    m_salidaEtanol = sets;
    m_salidaAgua   = sets;

    // Reglas Mamdani (SIMO)
    m_reglas = {
        {"AA", "ALL", "ETANOL"}, {"MA", "MAP", "ETANOL"}, {"BA", "MBP", "ETANOL"},
        {"AB", "OFF", "ETANOL"}, {"MB", "OFF", "ETANOL"}, {"BB", "OFF", "ETANOL"},
        {"N",  "BP",  "ETANOL"},
        {"AA", "OFF", "AGUA"},   {"MA", "OFF", "AGUA"},   {"BA", "OFF", "AGUA"},
        {"AB", "ALL", "AGUA"},   {"BB", "MAP", "AGUA"},   {"MB", "MBP", "AGUA"},
        {"N",  "BP",  "AGUA"}
    };
}

double ControladorFuzzy::defuzzificar(double error,
                                       const QVector<ConjuntoDifuso> &salida,
                                       const QString &target) const
{
    double num = 0.0, den = 0.0;

    // Centro de gravedad con 21 puntos sobre [0, 100]
    for (int i = 0; i <= 20; ++i) {
        double x  = i * 5.0;
        double mu = 0.0;

        for (const auto &r : m_reglas) {
            if (r.salida != target) continue;

            double mu_in = 0.0;
            for (const auto &s : m_errorPH)
                if (s.nombre == r.entradaNombre) { mu_in = s.evaluar(error); break; }

            double mu_out = 0.0;
            for (const auto &s : salida)
                if (s.nombre == r.salidaNombre) { mu_out = s.evaluar(x); break; }

            mu = std::max(mu, std::min(mu_in, mu_out));
        }
        num += x * mu;
        den += mu;
    }
    return (den > 0.0) ? num / den : 0.0;
}

QPair<double, double> ControladorFuzzy::calcular(double phSetpoint, double phMedido)
{
    double error = std::clamp(phSetpoint - phMedido, -6.0, 6.0);
    return {
        defuzzificar(error, m_salidaEtanol, "ETANOL"),
        defuzzificar(error, m_salidaAgua,   "AGUA")
    };
}
