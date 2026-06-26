#include <QtTest>
#include "controladorfuzzy.h"

class TstFuzzy : public QObject {
    Q_OBJECT
private slots:
    // Salida siempre dentro del universo de discurso [0, 7] s
    void salida_en_rango_0_7();
    // error = 0 → conjunto N activo → t_pulso ≈ 0 (sin acción)
    void error_cero_sin_accion();
    // error pequeño → t_pulso bajo
    void error_pequeno_pulso_corto();
    // error grande → t_pulso mayor que error pequeño (monotonicidad)
    void monotonia_creciente();
    // error muy grande (≥ 3.5) → t_pulso cercano al máximo (7 s)
    void error_maximo_pulso_maximo();
    // Pruebas unitarias de FuzzyMath
    void trimf_valor_central();
    void trimf_fuera_de_rango();
    void trapmf_en_meseta();
};

// Salida siempre en [0, 7] para todo error en [0, 3.5]
void TstFuzzy::salida_en_rango_0_7()
{
    ControladorFuzzy fuzzy;
    for (int i = 0; i <= 35; ++i) {
        double sp  = 7.5;
        double med = 7.5 - i * 0.1;   // error varía de 0 a 3.5
        double t   = fuzzy.calcular(sp, med);
        QVERIFY2(t >= 0.0 && t <= 7.0,
                 qPrintable(QString("t_pulso fuera de rango: sp=%1 med=%2 → %3")
                            .arg(sp).arg(med).arg(t)));
    }
}

// error = 0 → t_pulso debe ser casi cero (conjunto N → salida OFF)
void TstFuzzy::error_cero_sin_accion()
{
    ControladorFuzzy fuzzy;
    double t = fuzzy.calcular(7.0, 7.0);
    QVERIFY2(t < 1.0,
             qPrintable(QString("t_pulso con error=0 debería ser < 1 s, fue %1").arg(t)));
}

// error pequeño (~0.5) → pulso corto (conjunto PE → salida POCO ≈ 1.4 s)
void TstFuzzy::error_pequeno_pulso_corto()
{
    ControladorFuzzy fuzzy;
    double t = fuzzy.calcular(7.0, 6.5);   // error = 0.5
    QVERIFY2(t > 0.0 && t < 3.0,
             qPrintable(QString("Error pequeño debería dar pulso corto, fue %1").arg(t)));
}

// Monotonicidad: a mayor error → mayor t_pulso (tolerancia CoG 0.1 s)
void TstFuzzy::monotonia_creciente()
{
    ControladorFuzzy fuzzy;
    double t_prev = fuzzy.calcular(7.5, 7.5);   // error = 0
    for (int i = 1; i <= 7; ++i) {
        double error = i * 0.5;
        double t     = fuzzy.calcular(7.5, 7.5 - error);
        QVERIFY2(t >= t_prev - 0.1,
                 qPrintable(QString("No monótono en error=%1: prev=%2 actual=%3")
                            .arg(error).arg(t_prev).arg(t)));
        t_prev = t;
    }
}

// error máximo (3.5) → t_pulso alto (conjunto MG → salida MAX ≈ 7 s)
void TstFuzzy::error_maximo_pulso_maximo()
{
    ControladorFuzzy fuzzy;
    double t = fuzzy.calcular(7.5, 4.0);   // error = 3.5
    QVERIFY2(t >= 5.5,
             qPrintable(QString("Error máximo debería dar t_pulso alto, fue %1").arg(t)));
}

// FuzzyMath::trimf — en el pico (b) el valor es 1.0
void TstFuzzy::trimf_valor_central()
{
    QCOMPARE(FuzzyMath::trimf(0.0, -1.0, 0.0, 1.0), 1.0);
}

void TstFuzzy::trimf_fuera_de_rango()
{
    QCOMPARE(FuzzyMath::trimf(-2.0, -1.0, 0.0, 1.0), 0.0);
    QCOMPARE(FuzzyMath::trimf( 2.0, -1.0, 0.0, 1.0), 0.0);
}

// FuzzyMath::trapmf — en la meseta [b, c] debe dar 1.0
void TstFuzzy::trapmf_en_meseta()
{
    QCOMPARE(FuzzyMath::trapmf(5.0, 0.0, 2.0, 8.0, 10.0), 1.0);
}

QTEST_APPLESS_MAIN(TstFuzzy)
#include "tst_fuzzy.moc"
