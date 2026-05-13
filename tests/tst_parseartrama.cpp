#include <QtTest>
#include "gestorbiorreactor.h"

class TstParsearTrama : public QObject {
    Q_OBJECT
private slots:
    void prefijo_ph_actualiza_sensorPH();
    void prefijo_ph_actualiza_temperatura();
    void prefijo_do_actualiza_sensorDO();
    void prefijo_do_actualiza_temperatura();
    void fusion_temperatura_promedio();
    void formato_legacy_luz();
    void formato_legacy_co2();
    void prefijo_minusculas_aceptado();
    void clave_abreviada_p_aceptada();
    void clave_abreviada_d_aceptada();
    void valor_invalido_ignorado();
    void campo_sin_separador_ignorado();
};

// "PH:PH:6.50" → sensorPH = 6.5
void TstParsearTrama::prefijo_ph_actualiza_sensorPH()
{
    GestorBiorreactor g;
    g.parsearTrama("PH:PH:6.50");
    QCOMPARE(g.sensorPH(), 6.5);
}

// "PH:T:25.0" → temperatura interna PH → sensorTem = 25.0 (solo PH válido)
void TstParsearTrama::prefijo_ph_actualiza_temperatura()
{
    GestorBiorreactor g;
    g.parsearTrama("PH:T:25.0");
    QCOMPARE(g.sensorTem(), 25.0);
}

// "DO:D:8.20" → sensorDO = 8.2
void TstParsearTrama::prefijo_do_actualiza_sensorDO()
{
    GestorBiorreactor g;
    g.parsearTrama("DO:D:8.20");
    QCOMPARE(g.sensorDO(), 8.2);
}

// "DO:T:24.5" → temperatura interna DO → sensorTem = 24.5 (solo DO válido)
void TstParsearTrama::prefijo_do_actualiza_temperatura()
{
    GestorBiorreactor g;
    g.parsearTrama("DO:T:24.5");
    QCOMPARE(g.sensorTem(), 24.5);
}

// PH:T:26.0 + DO:T:24.0 → fusión → sensorTem = 25.0
void TstParsearTrama::fusion_temperatura_promedio()
{
    GestorBiorreactor g;
    g.parsearTrama("PH:T:26.0");
    g.parsearTrama("DO:T:24.0");
    QCOMPARE(g.sensorTem(), 25.0);
}

// Formato legacy sin prefijo: "L:75.0" → sensorLuz = 75.0
void TstParsearTrama::formato_legacy_luz()
{
    GestorBiorreactor g;
    g.parsearTrama("L:75.0");
    QCOMPARE(g.sensorLuz(), 75.0);
}

// Formato legacy: "C:450.0" → sensorCO2 = 450.0
void TstParsearTrama::formato_legacy_co2()
{
    GestorBiorreactor g;
    g.parsearTrama("C:450.0");
    QCOMPARE(g.sensorCO2(), 450.0);
}

// Prefijo en minúsculas: "ph:PH:7.0" → mismo resultado que "PH:PH:7.0"
void TstParsearTrama::prefijo_minusculas_aceptado()
{
    GestorBiorreactor g;
    g.parsearTrama("ph:PH:7.0");
    QCOMPARE(g.sensorPH(), 7.0);
}

// Clave abreviada "P" → setSensorPH igual que "PH"
void TstParsearTrama::clave_abreviada_p_aceptada()
{
    GestorBiorreactor g;
    g.parsearTrama("PH:P:5.5");
    QCOMPARE(g.sensorPH(), 5.5);
}

// Clave abreviada "D" → setSensorDO igual que "DO"
void TstParsearTrama::clave_abreviada_d_aceptada()
{
    GestorBiorreactor g;
    g.parsearTrama("DO:D:9.1");
    QCOMPARE(g.sensorDO(), 9.1);
}

// Valor no numérico → campo ignorado, sensor NO cambia
void TstParsearTrama::valor_invalido_ignorado()
{
    GestorBiorreactor g;
    double phAntes = g.sensorPH();
    g.parsearTrama("PH:PH:abc");
    QCOMPARE(g.sensorPH(), phAntes); // sin cambio
}

// Campo sin ':' → ignorado silenciosamente
void TstParsearTrama::campo_sin_separador_ignorado()
{
    GestorBiorreactor g;
    double phAntes = g.sensorPH();
    g.parsearTrama("PH:BASURA");      // payload="BASURA", sin ':'  → no parse
    QCOMPARE(g.sensorPH(), phAntes);
}

QTEST_GUILESS_MAIN(TstParsearTrama)
#include "tst_parseartrama.moc"
