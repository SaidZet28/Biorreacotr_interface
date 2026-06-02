#include <QtTest>
#include <cstring>
#include "gestorbiorreactor.h"

// ── Helpers para construir frames Modbus RTU correctos ────────────────────────

static quint16 testCrc(const QByteArray &data)
{
    quint16 crc = 0xFFFF;
    for (quint8 b : data) {
        crc ^= b;
        for (int i = 0; i < 8; ++i) {
            if (crc & 1) crc = (crc >> 1) ^ 0xA001;
            else         crc >>= 1;
        }
    }
    return crc;
}

// Respuesta de lectura: slave(1)+0x03(1)+0x0C(1)+float_be×3(12)+CRC(2) = 17 bytes
static QByteArray buildReadFrame(quint8 slave, float v1, float v2, float v3)
{
    QByteArray frame;
    frame.append(static_cast<char>(slave));
    frame.append(static_cast<char>(0x03));
    frame.append(static_cast<char>(0x0C));
    for (float f : {v1, v2, v3}) {
        quint32 raw;
        memcpy(&raw, &f, 4);
        frame.append(static_cast<char>((raw >> 24) & 0xFF));
        frame.append(static_cast<char>((raw >> 16) & 0xFF));
        frame.append(static_cast<char>((raw >>  8) & 0xFF));
        frame.append(static_cast<char>( raw        & 0xFF));
    }
    quint16 crc = testCrc(frame);
    frame.append(static_cast<char>(crc & 0xFF));
    frame.append(static_cast<char>((crc >> 8) & 0xFF));
    return frame;
}

// ── Test class ────────────────────────────────────────────────────────────────

class TstParsearTrama : public QObject {
    Q_OBJECT
private slots:
    void ph_extrae_valor_ph();
    void ph_extrae_temperatura();
    void do_extrae_valor_do();
    void do_extrae_temperatura();
    void fusion_temperatura_promedio();
    void ph_fuera_rango_ignorado();
    void do_fuera_rango_ignorado();
    void temperatura_fuera_rango_ignorada();
    void frame_corto_ignorado();
    void frame_crc_invalido_ignorado();
    void eco_calibracion_ph4_no_crashea();
    void frames_manuales_verifican_crc();
};

// Frames del manual — sirven también como verificación de que el parser acepta
// frames reales documentados por el fabricante.
// RK500-12 pH: slave=0x03, pH=7.01, internal=-4.3, temp=25.16
// RK500-04 DO: slave=0x0A, DO=7.57, sat=100%, temp=30.17
static const QByteArray FRAME_PH_MANUAL =
    QByteArray::fromHex("03030C40E051ECC089999A41C947AEAECE");
static const QByteArray FRAME_DO_MANUAL =
    QByteArray::fromHex("0A030C40F28D1842C8C2C241F15C29F5E6");

// Eco de calibración pH4 — RK500-12 manual sección 8.2
static const QByteArray FRAME_CAL_PH4 =
    QByteArray::fromHex("03060055000499FB");

// ── Tests ─────────────────────────────────────────────────────────────────────

void TstParsearTrama::ph_extrae_valor_ph()
{
    GestorBiorreactor g;
    g.parsearTrama(FRAME_PH_MANUAL);
    QVERIFY(qAbs(g.sensorPH() - 7.01) < 0.01);
}

void TstParsearTrama::ph_extrae_temperatura()
{
    GestorBiorreactor g;
    g.parsearTrama(FRAME_PH_MANUAL);
    QVERIFY(qAbs(g.sensorTem() - 25.16) < 0.01);
}

void TstParsearTrama::do_extrae_valor_do()
{
    GestorBiorreactor g;
    g.parsearTrama(FRAME_DO_MANUAL);
    QVERIFY(qAbs(g.sensorDO() - 7.57) < 0.01);
}

void TstParsearTrama::do_extrae_temperatura()
{
    GestorBiorreactor g;
    g.parsearTrama(FRAME_DO_MANUAL);
    QVERIFY(qAbs(g.sensorTem() - 30.17) < 0.01);
}

void TstParsearTrama::fusion_temperatura_promedio()
{
    // pH temp=25.16, DO temp=30.17 → fusión = promedio ≈ 27.665
    GestorBiorreactor g;
    g.parsearTrama(FRAME_PH_MANUAL);
    g.parsearTrama(FRAME_DO_MANUAL);
    double esperado = (25.16 + 30.17) / 2.0;
    QVERIFY(qAbs(g.sensorTem() - esperado) < 0.05);
}

void TstParsearTrama::ph_fuera_rango_ignorado()
{
    GestorBiorreactor g;
    double phAntes = g.sensorPH();
    // pH=14.5 > 14.0 → debe ignorarse
    QByteArray frame = buildReadFrame(0x03, 14.5f, 0.0f, 25.0f);
    g.parsearTrama(frame);
    QCOMPARE(g.sensorPH(), phAntes);
}

void TstParsearTrama::do_fuera_rango_ignorado()
{
    GestorBiorreactor g;
    double doAntes = g.sensorDO();
    // DO=21.0 > 20.0 → debe ignorarse
    QByteArray frame = buildReadFrame(0x0A, 21.0f, 100.0f, 25.0f);
    g.parsearTrama(frame);
    QCOMPARE(g.sensorDO(), doAntes);
}

void TstParsearTrama::temperatura_fuera_rango_ignorada()
{
    GestorBiorreactor g;
    double temAntes = g.sensorTem();
    // DO válido (8.0) pero temp=130°C > 120°C → temperatura no actualiza
    QByteArray frame = buildReadFrame(0x0A, 8.0f, 100.0f, 130.0f);
    g.parsearTrama(frame);
    QCOMPARE(g.sensorTem(), temAntes);
    // DO sí debe haber actualizado
    QVERIFY(qAbs(g.sensorDO() - 8.0) < 0.01);
}

void TstParsearTrama::frame_corto_ignorado()
{
    GestorBiorreactor g;
    double phAntes = g.sensorPH();
    g.parsearTrama(QByteArray::fromHex("0303"));
    QCOMPARE(g.sensorPH(), phAntes);
}

void TstParsearTrama::frame_crc_invalido_ignorado()
{
    GestorBiorreactor g;
    double phAntes = g.sensorPH();
    QByteArray corrupto = FRAME_PH_MANUAL;
    corrupto[corrupto.size() - 1] ^= 0xFF;  // corromper último byte del CRC
    g.parsearTrama(corrupto);
    QCOMPARE(g.sensorPH(), phAntes);
}

void TstParsearTrama::eco_calibracion_ph4_no_crashea()
{
    GestorBiorreactor g;
    double phAntes = g.sensorPH();
    g.parsearTrama(FRAME_CAL_PH4);
    QCOMPARE(g.sensorPH(), phAntes);  // eco no cambia sensores
}

void TstParsearTrama::frames_manuales_verifican_crc()
{
    // Verificar que los frames del manual tienen CRC correcto
    // (equivale a confiar en el manual y en nuestra implementación de CRC)
    auto verifyCrc = [](const QByteArray &f) {
        quint16 calc = testCrc(f.left(f.size() - 2));
        quint16 recv = static_cast<quint16>((quint8)f[f.size()-2]) |
                       static_cast<quint16>((quint8)f[f.size()-1] << 8);
        return calc == recv;
    };
    QVERIFY(verifyCrc(FRAME_PH_MANUAL));
    QVERIFY(verifyCrc(FRAME_DO_MANUAL));
    QVERIFY(verifyCrc(FRAME_CAL_PH4));
}

QTEST_GUILESS_MAIN(TstParsearTrama)
#include "tst_parseartrama.moc"
