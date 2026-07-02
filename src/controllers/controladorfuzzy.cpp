#include "controladorfuzzy.h"
#include <algorithm>

// ── Parámetros calibrados (2026-06) ─────────────────────────────────────────
static constexpr double E_SAT        = 0.8;   // error de saturación [pH] — acción directa al máximo
static constexpr double BANDA_MUERTA = 0.1;   // banda muerta [pH] — sin acción de neutralizador
static constexpr double K_SALIDA     = 2.0;   // factor de escala sobre salida fuzzy (CoG → t_pulso real)
static constexpr double TP_MAX_S     = 20.0;  // pulso máximo [s] — debe coincidir con T_PULSO_MAX_S

ControladorFuzzy::ControladorFuzzy(QObject *parent) : QObject(parent)
{
    // ── Conjuntos de ENTRADA: error pH = setpoint − medido ──────────────────
    // Universo de discurso: e ∈ [0, 0.8]
    // Calibrado para ΔpH ≈ 0.019/pulso @ tp_max en 50 L (caracterización 2026-06).
    // Para e ≥ E_SAT=0.8 la zona de saturación evita el razonamiento difuso.
    m_errorPH = {
        // nombre  params                              tipo
        {"N",  {0.00, 0.00, 0.06            }, "trimf" },   // Neutro        — cubierto por banda muerta
        {"PE", {0.04, 0.15, 0.28            }, "trimf" },   // Error Pequeño
        {"ME", {0.22, 0.35, 0.50            }, "trimf" },   // Error Medio
        {"GE", {0.42, 0.58, 0.75            }, "trimf" },   // Error Grande
        {"MG", {0.65, 0.80, 0.80,  0.80    }, "trapmf"},   // Muy Grande    — zona de saturación
    };

    // ── Conjuntos de SALIDA: t_pulso fuzzy [s] ──────────────────────────────
    // Universo de discurso: [0, 10] s
    // La salida real es t_pulso = CoG × K_SALIDA → [0, 20] s
    m_tPulso = {
        {"OFF",   {0.0, 0.0,  1.5           }, "trimf" },
        {"POCO",  {3.0, 5.0,  7.0           }, "trimf" },
        {"MEDIO", {5.5, 7.0,  9.0           }, "trimf" },
        {"MUCHO", {7.5, 9.0, 10.0           }, "trimf" },
        {"MAX",   {9.5, 10.0, 10.0, 10.0   }, "trapmf"},
    };

    // ── Base de reglas Mamdani (5 reglas — una por conjunto de entrada) ──────
    // SI  error es <entrada>  ENTONCES  t_pulso es <salida>
    m_reglas = {
        {"N",  "OFF"  },   // Neutro       → sin acción
        {"PE", "POCO" },   // Peq. error   → pulso corto
        {"ME", "MEDIO"},   // Error medio  → pulso medio
        {"GE", "MUCHO"},   // Error grande → pulso largo
        {"MG", "MAX"  },   // Muy grande   → acción máxima
    };
}

double ControladorFuzzy::defuzzificar(double error) const
{
    double num = 0.0, den = 0.0;

    // Centro de Gravedad (CoG) con 71 puntos sobre [0, 10 s]
    constexpr int    N_PTS = 71;
    constexpr double X_MIN = 0.0;
    constexpr double X_MAX = 10.0;

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
    double error = phSetpoint - phMedido;

    // Banda muerta: evita ciclado innecesario de la bomba en zona de equilibrio
    if (error <= BANDA_MUERTA)
        return 0.0;

    // Zona de saturación: error ≥ e_sat → acción directa al máximo sin razonamiento difuso
    if (error >= E_SAT)
        return TP_MAX_S;

    // Zona difusa: clamp al universo de discurso, defuzzificar y escalar
    error = std::clamp(error, 0.0, E_SAT);
    double tp_fuzzy = defuzzificar(error);
    return std::clamp(tp_fuzzy * K_SALIDA, 0.0, TP_MAX_S);
}
