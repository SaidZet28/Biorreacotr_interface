#include "controladorfuzzy.h"
#include <algorithm>

ControladorFuzzy::ControladorFuzzy(QObject *parent) : QObject(parent)
{
    // ── Conjuntos de ENTRADA: error pH = setpoint − medido ──────────────────
    // Universo de discurso: e ∈ [0, 3.5]  (setpoint ∈ [4.0, 7.5])
    // Diseño asimétrico justificado por caracterización experimental (2026-06):
    //   - Zona intermedia (e ≈ 1.0): ganancia ≈ 0.020 pH/ciclo → conjuntos más finos
    //   - Zona ácida (e > 2.5):      ganancia ≈ 0.006 pH/ciclo → conjuntos más amplios
    m_errorPH = {
        // nombre  params                      tipo
        {"N",  {0.0,  0.0,  0.3         }, "trimf" },   // Neutro        — en setpoint
        {"PE", {0.1,  0.5,  1.0         }, "trimf" },   // Error Pequeño — alta ganancia
        {"ME", {0.7,  1.4,  2.1         }, "trimf" },   // Error Medio
        {"GE", {1.8,  2.5,  3.5         }, "trimf" },   // Error Grande  — ganancia decreciente
        {"MG", {3.0,  3.5,  3.5,  3.5  }, "trapmf"},   // Error Muy Grande — zona muy ácida
    };

    // ── Conjuntos de SALIDA: t_pulso [s] ────────────────────────────────────
    // Universo de discurso: t_pulso ∈ [0, 7] s
    // Q = 39 mL/s  →  volumen bomba neutralizadora por ciclo:
    //   OFF=0 mL · POCO≈55 mL · MEDIO≈137 mL · MUCHO≈218 mL · MAX=275 mL (0.5% × 55 L)
    m_tPulso = {
        {"OFF",   {0.0, 0.0, 0.7          }, "trimf" },   // Sin acción
        {"POCO",  {0.0, 1.4, 2.8          }, "trimf" },   // ~55 mL
        {"MEDIO", {2.1, 3.5, 4.9          }, "trimf" },   // ~137 mL
        {"MUCHO", {4.2, 5.6, 7.0          }, "trimf" },   // ~218 mL
        {"MAX",   {6.3, 7.0, 7.0, 7.0     }, "trapmf"},   // 275 mL — acción máxima
    };

    // ── Base de reglas Mamdani (5 reglas — una por conjunto de entrada) ──────
    // SI  error es <entrada>  ENTONCES  t_pulso es <salida>
    m_reglas = {
        {"N",  "OFF"  },   // Neutro       → sin acción      (evita sobreimpulso)
        {"PE", "POCO" },   // Peq. error   → pulso corto     (zona de alta ganancia)
        {"ME", "MEDIO"},   // Error medio   → pulso medio
        {"GE", "MUCHO"},   // Error grande  → pulso largo     (compensa ganancia baja)
        {"MG", "MAX"  },   // Muy grande    → acción máxima   (zona muy ácida)
    };
}

double ControladorFuzzy::defuzzificar(double error) const
{
    double num = 0.0, den = 0.0;

    // Centro de Gravedad (CoG) con 71 puntos sobre [0, 7 s]
    constexpr int    N_PTS = 71;
    constexpr double X_MIN = 0.0;
    constexpr double X_MAX = 7.0;

    for (int i = 0; i < N_PTS; ++i) {
        double x  = X_MIN + i * (X_MAX - X_MIN) / (N_PTS - 1);
        double mu = 0.0;

        for (const auto &r : m_reglas) {
            double mu_in = 0.0;
            for (const auto &s : m_errorPH)
                if (s.nombre == r.entradaNombre) { mu_in = s.evaluar(error); break; }

            double mu_out = 0.0;
            for (const auto &s : m_tPulso)
                if (s.nombre == r.salidaNombre) { mu_out = s.evaluar(x); break; }

            mu = std::max(mu, std::min(mu_in, mu_out));   // Mamdani: min-inferencia, max-agregación
        }
        num += x * mu;
        den += mu;
    }
    return (den > 0.0) ? num / den : 0.0;
}

double ControladorFuzzy::calcular(double phSetpoint, double phMedido)
{
    // Clamp al universo de discurso; el pre-filtro (error ≤ 0) se aplica en
    // GestorBiorreactor antes de llamar a esta función.
    double error = std::clamp(phSetpoint - phMedido, 0.0, 3.5);
    return defuzzificar(error);
}
