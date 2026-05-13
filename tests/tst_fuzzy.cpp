#include <QtTest>
#include "controladorfuzzy.h"

class TstFuzzy : public QObject {
    Q_OBJECT
private slots:
    void salidas_en_rango_0_100();
    void error_cero_salida_baja();
    void error_positivo_activa_agua();
    void error_negativo_activa_etanol();
    void error_maximo_positivo_agua_maxima();
    void error_maximo_negativo_etanol_maximo();
    void simetria_aproximada();
    void trimf_valor_central();
    void trimf_fuera_de_rango();
    void trapmf_en_meseta();
};

// Todos los outputs deben estar en [0, 100]
void TstFuzzy::salidas_en_rango_0_100()
{
    ControladorFuzzy fuzzy;
    for (double sp = 4.0; sp <= 10.0; sp += 0.5) {
        for (double med = 4.0; med <= 10.0; med += 0.5) {
            auto [etanol, agua] = fuzzy.calcular(sp, med);
            QVERIFY2(etanol >= 0.0 && etanol <= 100.0,
                     qPrintable(QString("etanol fuera de rango: sp=%1 med=%2").arg(sp).arg(med)));
            QVERIFY2(agua   >= 0.0 && agua   <= 100.0,
                     qPrintable(QString("agua fuera de rango: sp=%1 med=%2").arg(sp).arg(med)));
        }
    }
}

// error=0 → zona neutral → ambas bombas baja potencia
void TstFuzzy::error_cero_salida_baja()
{
    ControladorFuzzy fuzzy;
    auto [etanol, agua] = fuzzy.calcular(7.0, 7.0);
    QVERIFY2(etanol < 20.0, qPrintable(QString("etanol demasiado alto: %1").arg(etanol)));
    QVERIFY2(agua   < 20.0, qPrintable(QString("agua demasiado alta: %1").arg(agua)));
}

// error > 0 (pH bajo) → bomba AGUA activa, ETANOL casi inactiva
void TstFuzzy::error_positivo_activa_agua()
{
    ControladorFuzzy fuzzy;
    auto [etanol, agua] = fuzzy.calcular(8.0, 5.0); // error=3
    QVERIFY2(agua > etanol,
             qPrintable(QString("agua(%1) debería > etanol(%2)").arg(agua).arg(etanol)));
    QVERIFY(agua > 10.0);
}

// error < 0 (pH alto) → bomba ETANOL activa, AGUA casi inactiva
void TstFuzzy::error_negativo_activa_etanol()
{
    ControladorFuzzy fuzzy;
    auto [etanol, agua] = fuzzy.calcular(5.0, 8.0); // error=-3
    QVERIFY2(etanol > agua,
             qPrintable(QString("etanol(%1) debería > agua(%2)").arg(etanol).arg(agua)));
    QVERIFY(etanol > 10.0);
}

// error muy positivo (≥ +5) → AB dispara → AGUA a máxima potencia
void TstFuzzy::error_maximo_positivo_agua_maxima()
{
    ControladorFuzzy fuzzy;
    auto [etanol, agua] = fuzzy.calcular(12.0, 7.0); // error clampea a +6 → AB activo
    QVERIFY(agua > 80.0);
    QVERIFY(etanol < 10.0);
}

// error muy negativo (≤ -5) → AA dispara → ETANOL a máxima potencia
void TstFuzzy::error_maximo_negativo_etanol_maximo()
{
    ControladorFuzzy fuzzy;
    auto [etanol, agua] = fuzzy.calcular(2.0, 7.0); // error clampea a -5 → AA activo
    QVERIFY(etanol > 80.0);
    QVERIFY(agua < 10.0);
}

// Simetría: error=+2 → agua≈X;  error=-2 → etanol≈X  (mismo error absoluto)
void TstFuzzy::simetria_aproximada()
{
    ControladorFuzzy fuzzy;
    auto [etanol_neg, agua_neg] = fuzzy.calcular(5.0, 7.0); // error=-2
    auto [etanol_pos, agua_pos] = fuzzy.calcular(9.0, 7.0); // error=+2
    // Las salidas activas deberían ser simétricas (tolerancia 5%)
    QVERIFY(qAbs(etanol_neg - agua_pos) < 5.0);
}

// Pruebas unitarias de FuzzyMath::trimf
void TstFuzzy::trimf_valor_central()
{
    // En el pico (b) el valor es 1.0
    QCOMPARE(FuzzyMath::trimf(0.0, -1.0, 0.0, 1.0), 1.0);
}

void TstFuzzy::trimf_fuera_de_rango()
{
    QCOMPARE(FuzzyMath::trimf(-2.0, -1.0, 0.0, 1.0), 0.0);
    QCOMPARE(FuzzyMath::trimf( 2.0, -1.0, 0.0, 1.0), 0.0);
}

// FuzzyMath::trapmf en la meseta [b,c] debe dar 1.0
void TstFuzzy::trapmf_en_meseta()
{
    QCOMPARE(FuzzyMath::trapmf(5.0, 0.0, 2.0, 8.0, 10.0), 1.0);
}

QTEST_APPLESS_MAIN(TstFuzzy)
#include "tst_fuzzy.moc"
