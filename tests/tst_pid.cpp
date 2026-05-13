#include <QtTest>
#include "controladorpid.h"

class TstPID : public QObject {
    Q_OBJECT
private slots:
    void solo_proporcional();
    void integral_acumula_entre_ciclos();
    void antiwindup_clamp_integral();
    void derivativo_cero_en_primer_ciclo();
    void derivativo_activo_en_segundo_ciclo();
    void salida_clampeada_al_maximo();
    void salida_clampeada_al_minimo();
    void reiniciar_limpia_estado();
};

static constexpr double EPS = 1e-9;

void TstPID::solo_proporcional()
{
    ControladorPID pid;
    pid.configurar(2.0, 0.0, 0.0, 1.0, 0.0, 100.0);
    // error=5, p=10, i=0, d=0 (primer ciclo) → 10
    QCOMPARE(pid.calcular(10.0, 5.0), 10.0);
}

void TstPID::integral_acumula_entre_ciclos()
{
    ControladorPID pid;
    pid.configurar(0.0, 1.0, 0.0, 1.0, 0.0, 1000.0);
    // Ki=1, dt=1, error=5 cada ciclo → integral = 5, 10, 15
    double r1 = pid.calcular(10.0, 5.0);  // i=5
    double r2 = pid.calcular(10.0, 5.0);  // i=10
    double r3 = pid.calcular(10.0, 5.0);  // i=15
    QVERIFY(qAbs(r1 -  5.0) < EPS);
    QVERIFY(qAbs(r2 - 10.0) < EPS);
    QVERIFY(qAbs(r3 - 15.0) < EPS);
}

void TstPID::antiwindup_clamp_integral()
{
    ControladorPID pid;
    pid.configurar(0.0, 1.0, 0.0, 1.0, 0.0, 20.0); // max=20
    // error=100 por ciclo → integral quedaría en 100, pero se clampea a 20
    pid.calcular(100.0, 0.0);
    double r2 = pid.calcular(100.0, 0.0);
    QCOMPARE(r2, 20.0); // integral clampeada, output = salidaMax
}

void TstPID::derivativo_cero_en_primer_ciclo()
{
    ControladorPID pid;
    pid.configurar(0.0, 0.0, 5.0, 1.0, -1000.0, 1000.0);
    // kd=5, pero primer ciclo → d=0 → output=0
    QCOMPARE(pid.calcular(10.0, 5.0), 0.0);
}

void TstPID::derivativo_activo_en_segundo_ciclo()
{
    ControladorPID pid;
    pid.configurar(0.0, 0.0, 2.0, 1.0, -1000.0, 1000.0);
    pid.calcular(10.0, 5.0);              // error=5, d=0 (primer ciclo)
    double r = pid.calcular(10.0, 7.0);  // error=3, d=2*(3-5)/1 = -4
    QVERIFY(qAbs(r - (-4.0)) < EPS);
}

void TstPID::salida_clampeada_al_maximo()
{
    ControladorPID pid;
    pid.configurar(1.0, 0.0, 0.0, 1.0, 0.0, 10.0);
    // error=100, p=100, pero max=10
    QCOMPARE(pid.calcular(100.0, 0.0), 10.0);
}

void TstPID::salida_clampeada_al_minimo()
{
    ControladorPID pid;
    pid.configurar(1.0, 0.0, 0.0, 1.0, -10.0, 100.0);
    // error=-100, p=-100, pero min=-10
    QCOMPARE(pid.calcular(0.0, 100.0), -10.0);
}

void TstPID::reiniciar_limpia_estado()
{
    ControladorPID pid;
    pid.configurar(0.0, 1.0, 0.0, 1.0, 0.0, 1000.0);
    pid.calcular(10.0, 5.0); // integral=5
    pid.calcular(10.0, 5.0); // integral=10
    pid.reiniciar();

    // Integral reseteada a 0: primer ciclo tras reiniciar → i=5, output=5
    // Sin reiniciar habría dado 15 (10+5). Probar que realmente volvió a 0.
    double r = pid.calcular(10.0, 5.0);
    QVERIFY(qAbs(r - 5.0) < EPS);
}

QTEST_APPLESS_MAIN(TstPID)
#include "tst_pid.moc"
