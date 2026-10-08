import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_calibracion_tanque"

    // paso: 0=intro, 1=vaciar, 2=llenar, 3=resumen/guardar
    property int    paso: 0
    property bool   corriendo: false        // hay una acción (llenar/drenar) en curso
    property double _t0: 0
    property double elapsedS: 0
    // Resultados medidos
    property double tVaciado: 0
    property double tLlenado: 0
    property double dVacio: -1
    property double dOperacion: -1

    function reset() {
        paso = 0; corriendo = false; elapsedS = 0;
        tVaciado = 0; tLlenado = 0; dVacio = -1; dOperacion = -1;
    }

    onVisibleChanged: {
        if (visible) reset();
        else { backend.calibAccion(0); corriendo = false; }   // seguridad al salir
    }

    Timer {
        interval: 200; running: root.corriendo; repeat: true
        onTriggered: root.elapsedS = (Date.now() - root._t0) / 1000
    }

    function iniciarAccion(accion) {          // 1=llenar, 2=drenar
        root._t0 = Date.now(); root.elapsedS = 0; root.corriendo = true;
        backend.calibAccion(accion);
    }
    function detenerAccion() {
        backend.calibAccion(0); root.corriendo = false;
    }

    // ── Título ────────────────────────────────────────────────────────────────
    Text {
        id: titulo
        text: qsTranslate("Main", "Calibración del tanque")
        font.pixelSize: appWindow.height * 0.06
        font.bold: true
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.16
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // ── Lecturas en vivo (nivel radar + cronómetro) ───────────────────────────
    Row {
        id: lecturas
        anchors.top: titulo.bottom
        anchors.topMargin: appWindow.height * 0.03
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: appWindow.width * 0.06

        Column {
            spacing: 2
            Text { text: qsTranslate("Main", "Nivel (radar)"); font.pixelSize: appWindow.height * 0.024; color: "#666"; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
                text: (backend.distanciaNivelMm >= 0 ? Math.round(backend.distanciaNivelMm) : "---") + " mm"
                font.pixelSize: appWindow.height * 0.05; font.bold: true; color: "#1a5070"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        Column {
            spacing: 2
            Text { text: qsTranslate("Main", "Tiempo"); font.pixelSize: appWindow.height * 0.024; color: "#666"; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
                text: root.elapsedS.toFixed(1) + " s"
                font.pixelSize: appWindow.height * 0.05; font.bold: true; color: root.corriendo ? "#D64545" : "#333"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ── Tarjeta de instrucción del paso actual ────────────────────────────────
    Rectangle {
        id: tarjeta
        anchors.top: lecturas.bottom
        anchors.topMargin: appWindow.height * 0.04
        anchors.horizontalCenter: parent.horizontalCenter
        width: appWindow.width * 0.80
        height: appWindow.height * 0.30
        radius: 16
        color: "#DFF0F8"

        Text {
            anchors.fill: parent
            anchors.margins: appWindow.height * 0.03
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: appWindow.height * 0.030
            color: "#1a3a4a"
            text: root.paso === 0
                  ? qsTranslate("Main", "Esta rutina mide los tiempos de llenado y vaciado y las lecturas de referencia del radar. Ten el tanque listo para vaciar y una fuente de medio para llenar. Presiona Comenzar.")
                  : root.paso === 1
                    ? qsTranslate("Main", "PASO 1 — Vaciado.\nPresiona 'Iniciar vaciado': se abren las electroválvulas. Cuando el tanque quede vacío, presiona 'Tanque vacío'.")
                    : root.paso === 2
                      ? qsTranslate("Main", "PASO 2 — Llenado.\nPresiona 'Iniciar llenado': se bombea el medio. Cuando el agua llegue al NIVEL DE OPERACIÓN del cultivo, presiona 'Nivel alcanzado'.")
                      : qsTranslate("Main", "Listo. Revisa los valores medidos y presiona Guardar.")
        }
    }

    // ── Resumen (paso 3) ──────────────────────────────────────────────────────
    Column {
        anchors.top: tarjeta.bottom
        anchors.topMargin: appWindow.height * 0.03
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: appWindow.height * 0.01
        visible: root.paso === 3

        Text { text: qsTranslate("Main", "Vaciado: %1 s   ·   radar vacío: %2 mm").arg(root.tVaciado.toFixed(1)).arg(root.dVacio >= 0 ? Math.round(root.dVacio) : "---"); font.pixelSize: appWindow.height * 0.028; color: "black"; anchors.horizontalCenter: parent.horizontalCenter }
        Text { text: qsTranslate("Main", "Llenado a operación: %1 s   ·   radar operación: %2 mm").arg(root.tLlenado.toFixed(1)).arg(root.dOperacion >= 0 ? Math.round(root.dOperacion) : "---"); font.pixelSize: appWindow.height * 0.028; color: "black"; anchors.horizontalCenter: parent.horizontalCenter }
    }

    // ── Botones de acción (según el paso) ─────────────────────────────────────
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.06
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: appWindow.width * 0.04

        // Comenzar (paso 0)
        Rectangle {
            visible: root.paso === 0
            width: appWindow.width * 0.24; height: appWindow.height * 0.11; radius: height / 2
            color: maComenzar.pressed ? "#3a7d3a" : "#4CAF50"
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Comenzar"); font.pixelSize: parent.height * 0.30; font.bold: true; color: "white" }
            MouseArea { id: maComenzar; anchors.fill: parent; onClicked: root.paso = 1 }
        }

        // Iniciar vaciado (paso 1, no corriendo)
        Rectangle {
            visible: root.paso === 1 && !root.corriendo
            width: appWindow.width * 0.26; height: appWindow.height * 0.11; radius: height / 2
            color: maIniVac.pressed ? "#a03030" : "#D64545"
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Iniciar vaciado"); font.pixelSize: parent.height * 0.28; font.bold: true; color: "white" }
            MouseArea { id: maIniVac; anchors.fill: parent; onClicked: root.iniciarAccion(2) }
        }
        // Tanque vacío (paso 1, corriendo)
        Rectangle {
            visible: root.paso === 1 && root.corriendo
            width: appWindow.width * 0.26; height: appWindow.height * 0.11; radius: height / 2
            color: maFinVac.pressed ? "#6b42b5" : "#8b5cf6"
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Tanque vacío"); font.pixelSize: parent.height * 0.28; font.bold: true; color: "white" }
            MouseArea {
                id: maFinVac; anchors.fill: parent
                onClicked: {
                    root.tVaciado = root.elapsedS;
                    root.dVacio = backend.distanciaNivelMm;
                    root.detenerAccion();
                    root.paso = 2;
                }
            }
        }

        // Iniciar llenado (paso 2, no corriendo)
        Rectangle {
            visible: root.paso === 2 && !root.corriendo
            width: appWindow.width * 0.26; height: appWindow.height * 0.11; radius: height / 2
            color: maIniLl.pressed ? "#3a7d3a" : "#4CAF50"
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Iniciar llenado"); font.pixelSize: parent.height * 0.28; font.bold: true; color: "white" }
            MouseArea { id: maIniLl; anchors.fill: parent; onClicked: root.iniciarAccion(1) }
        }
        // Nivel alcanzado (paso 2, corriendo)
        Rectangle {
            visible: root.paso === 2 && root.corriendo
            width: appWindow.width * 0.28; height: appWindow.height * 0.11; radius: height / 2
            color: maFinLl.pressed ? "#6b42b5" : "#8b5cf6"
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Nivel alcanzado"); font.pixelSize: parent.height * 0.26; font.bold: true; color: "white" }
            MouseArea {
                id: maFinLl; anchors.fill: parent
                onClicked: {
                    root.tLlenado = root.elapsedS;
                    root.dOperacion = backend.distanciaNivelMm;
                    root.detenerAccion();
                    root.paso = 3;
                }
            }
        }

        // Guardar (paso 3)
        Rectangle {
            visible: root.paso === 3
            width: appWindow.width * 0.26; height: appWindow.height * 0.11; radius: height / 2
            color: maGuardar.pressed ? "#3a7d3a" : "#4CAF50"
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Guardar"); font.pixelSize: parent.height * 0.30; font.bold: true; color: "white" }
            MouseArea {
                id: maGuardar; anchors.fill: parent
                onClicked: {
                    backend.guardarCalibracionTanque(root.tLlenado, root.tVaciado, root.dVacio, root.dOperacion);
                    appWindow.estadoActual = "pantalla_configuraciones";
                }
            }
        }
    }

    // ── Botón salir/atrás (para seguridad, siempre visible) ───────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: appWindow.width * 0.04
        anchors.bottomMargin: appWindow.height * 0.04
        width: appWindow.width * 0.11; height: appWindow.height * 0.10; radius: height / 2
        color: maSalir.pressed ? "#cc1e1e" : "#FF2D2D"
        Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: maSalir; anchors.fill: parent
            onClicked: {
                root.detenerAccion();
                appWindow.estadoActual = "pantalla_configuraciones";
            }
        }
    }
}
