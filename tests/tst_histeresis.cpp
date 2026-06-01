#include <QtTest>
#include "controladorhisteresis.h"

class TstHisteresis : public QObject {
    Q_OBJECT
private slots:
    void estadoInicial_apagado();
    void nivel_alto_enciende_bomba();
    void nivel_bajo_para_bomba();
    void dentro_de_banda_conserva_estado_ON();
    void dentro_de_banda_conserva_estado_OFF();
    void reiniciar_apaga_bomba();
    void fronteras_exactas_de_banda();
};

// Estado inicial siempre OFF
void TstHisteresis::estadoInicial_apagado()
{
    ControladorHisteresis h;
    QVERIFY(!h.estadoBomba());
}

// medicion > sp + delta/2  →  ON (vaciar)
void TstHisteresis::nivel_alto_enciende_bomba()
{
    ControladorHisteresis h;
    h.configurar(10.0);               // delta=10: sp_bajo=45, sp_alto=55
    QVERIFY( h.calcular(50.0, 60.0)); // 60 > 55 → ON (vaciar)
    QVERIFY( h.estadoBomba());
}

// medicion < sp - delta/2  →  OFF (parar vaciado)
void TstHisteresis::nivel_bajo_para_bomba()
{
    ControladorHisteresis h;
    h.configurar(10.0);
    h.calcular(50.0, 60.0);            // enciende primero (vaciar)
    QVERIFY(!h.calcular(50.0, 40.0)); // 40 < 45 → OFF
    QVERIFY(!h.estadoBomba());
}

// Dentro de banda con estado previo ON → sigue ON
void TstHisteresis::dentro_de_banda_conserva_estado_ON()
{
    ControladorHisteresis h;
    h.configurar(10.0);
    h.calcular(50.0, 60.0);            // enciende (> 55)
    QVERIFY( h.calcular(50.0, 50.0)); // 45 ≤ 50 ≤ 55 → conserva ON
}

// Dentro de banda con estado previo OFF → sigue OFF
void TstHisteresis::dentro_de_banda_conserva_estado_OFF()
{
    ControladorHisteresis h;
    h.configurar(10.0);
    h.calcular(50.0, 40.0);            // para (< 45)
    QVERIFY(!h.calcular(50.0, 50.0)); // 45 ≤ 50 ≤ 55 → conserva OFF
}

// reiniciar() vuelve a OFF independientemente del estado previo
void TstHisteresis::reiniciar_apaga_bomba()
{
    ControladorHisteresis h;
    h.configurar(10.0);
    h.calcular(50.0, 60.0); // enciende
    QVERIFY(h.estadoBomba());
    h.reiniciar();
    QVERIFY(!h.estadoBomba());
}

// En la frontera exacta (sp±delta/2) NO hay cambio de estado
void TstHisteresis::fronteras_exactas_de_banda()
{
    ControladorHisteresis h;
    h.configurar(10.0);  // sp_bajo=45, sp_alto=55

    // Borde inferior exacto: medicion==45 → ni > 55 ni < 45 → conserva OFF
    QVERIFY(!h.calcular(50.0, 45.0));

    h.calcular(50.0, 60.0);            // enciende (vaciar)
    // Borde superior exacto: medicion==55 → ni > 55 ni < 45 → conserva ON
    QVERIFY( h.calcular(50.0, 55.0));
}

QTEST_APPLESS_MAIN(TstHisteresis)
#include "tst_histeresis.moc"
