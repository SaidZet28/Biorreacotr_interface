import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_procesos"

    property real progresoSimulado: 0.0
    property bool mostrarPopupPausa: false
    property bool mostrarPopupFinalizado: false
    property bool mostrarPopupConfirmarDetener: false

    // true once the screen has been shown at least once; keeps Loader alive
    property bool chartaActivada: false

    PropertyAnimation {
        id: animacionProgreso
        target: root
        property: "progresoSimulado"
        from: 0.0
        to: 1.0
        duration: Math.max(1000, Math.floor(appWindow.var_deseada_tiempo_total_horas * 3600000))
        onFinished: {
            if (root.progresoSimulado >= 1.0) {
                root.mostrarPopupFinalizado = true;
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            chartaActivada = true
            if (progresoSimulado === 0.0 && !mostrarPopupFinalizado) {
                mostrarPopupPausa = false;
                mostrarPopupFinalizado = false;
                mostrarPopupConfirmarDetener = false;
                chartLoader.resetear()
                animacionProgreso.start();
                backend.iniciarRegistro(appWindow.var_nombre_proyecto, appWindow.var_nombre_experimento);
            }
        }
    }

    // -- Gráfica en tiempo real ------------------------------------------------
    // Activa solo en Linux (RPi con OpenGL). En Windows D3D11 + MinGW causa crash
    // con QtCharts; se muestra un fondo decorativo como placeholder.
    Rectangle {
        id: chartBackground
        width: parent.width * 0.45
        height: parent.height * 0.55
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.05
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.20
        color: "#6E9C9C"
        radius: 10
        visible: root.chartaActivada
    }

    Loader {
        id: chartLoader
        width: chartBackground.width
        height: chartBackground.height
        anchors.left: chartBackground.left
        anchors.top: chartBackground.top
        active: root.chartaActivada && Qt.platform.os === "linux"
        // Se usa el tipo registrado (no una ruta relativa que en la RPi no resuelve)
        // y se le pasan las propiedades que la gráfica necesita.
        sourceComponent: graficaComp
        function resetear() { if (chartLoader.item && chartLoader.item.resetear) chartLoader.item.resetear() }
    }

    Component {
        id: graficaComp
        GraficaChart {
            appWindow:  root.appWindow
            pausado:    root.mostrarPopupPausa
            finalizado: root.mostrarPopupFinalizado
        }
    }

    // -- Pildoras de sensor/setpoint ---------------------------------------
    Column {
        id: pildorasProceso
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.05
        anchors.verticalCenter: chartLoader.verticalCenter
        width: parent.width * 0.40
        spacing: appWindow.height * 0.025

        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: (backend.alertaDivergenciaTemp || backend.alertaSobreTemp) ? "#FF4444" : "#8DBB5A"
            radius: height / 2
            Behavior on color { ColorAnimation { duration: 400 } }
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Temp °%1: %2").arg(appWindow.unidadTemperatura).arg(backend.sensorTem.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Temp °%1: %2").arg(appWindow.unidadTemperatura).arg(backend.setpointTem.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: backend.alertaSerial ? "#AAAAAA" : "#8DBB5A"
            radius: height / 2
            opacity: backend.alertaSerial ? 0.7 : 1.0
            Behavior on color { ColorAnimation { duration: 400 } }
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. pH: %1").arg(backend.sensorPH.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. pH: %1").arg(backend.setpointPH.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: backend.alertaNivel ? "#FF4444" : (backend.alertaSerial ? "#AAAAAA" : "#8DBB5A")
            radius: height / 2
            opacity: backend.alertaSerial ? 0.7 : 1.0
            Behavior on color { ColorAnimation { duration: 400 } }
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nivel: %1%").arg(backend.sensorNivel.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Objetivo: %1%").arg(backend.nivelLlenadoPct.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: backend.alertaSerial ? "#AAAAAA" : "#8DBB5A"
            radius: height / 2
            opacity: backend.alertaSerial ? 0.7 : 1.0
            Behavior on color { ColorAnimation { duration: 400 } }
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "N. Luz: %1 %").arg(backend.setpointLuz.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: backend.alertaSerial ? "#AAAAAA" : "#8DBB5A"
            radius: height / 2
            opacity: backend.alertaSerial ? 0.7 : 1.0
            Behavior on color { ColorAnimation { duration: 400 } }
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "OD: %1 mg/L").arg(backend.sensorDO.toFixed(2)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
    }

    // -- Barra de progreso y controles -------------------------------------
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.height * 0.15

        Rectangle {
            id: botonAjustes8
            anchors.left: parent.left
            anchors.leftMargin: appWindow.width * 0.05
            anchors.verticalCenter: parent.verticalCenter
            width: appWindow.width * 0.08
            height: appWindow.height * 0.10
            radius: width * 0.35
            color: areaMouseEngrane8.pressed ? "#9ca3af" : "#B3B3B3"
            Image {
                source: "../../Engrane.png"
                anchors.centerIn: parent
                width: parent.width * 0.65
                height: parent.height * 0.65
                fillMode: Image.PreserveAspectFit
            }
            MouseArea {
                id: areaMouseEngrane8
                anchors.fill: parent
                onClicked: {
                    appWindow.estadoPrevioAjustes = "pantalla_procesos"
                    appWindow.estadoActual = "pantalla_configuraciones"
                }
            }
        }

        Item {
            anchors.left: botonAjustes8.right
            anchors.leftMargin: appWindow.width * 0.03
            anchors.right: btnPlayPausa.left
            anchors.rightMargin: appWindow.width * 0.03
            anchors.verticalCenter: parent.verticalCenter
            height: appWindow.height * 0.08

            Rectangle {
                id: fondoBarraProgreso
                anchors.top: parent.top
                width: parent.width
                height: appWindow.height * 0.04
                color: "#A0A0A0"
                radius: height / 2
                Rectangle {
                    width: parent.width * root.progresoSimulado
                    height: parent.height
                    color: "#5a8282"
                    radius: parent.radius
                }
            }

            Item {
                anchors.top: fondoBarraProgreso.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    property int t_h: Math.floor(appWindow.var_deseada_tiempo_total_horas)
                    property int t_m: Math.round((appWindow.var_deseada_tiempo_total_horas - t_h) * 60)
                    text: qsTranslate("Main", "Tiempo total: %1 h %2 min").arg(t_h).arg(t_m)
                    font.pixelSize: parent.height * 0.55
                    font.bold: true
                    color: "black"
                }
                Text {
                    anchors.centerIn: parent
                    text: Math.floor(root.progresoSimulado * 100) + "%"
                    font.pixelSize: parent.height * 0.55
                    font.bold: true
                    color: "black"
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    property real e_total: root.progresoSimulado * appWindow.var_deseada_tiempo_total_horas
                    property int e_h: Math.floor(e_total)
                    property int e_m: Math.round((e_total - e_h) * 60)
                    text: qsTranslate("Main", "Tiempo transcurrido: %1 h %2 min").arg(e_h).arg(e_m)
                    font.pixelSize: parent.height * 0.55
                    font.bold: true
                    color: "black"
                }
            }
        }

        Image {
            id: btnPlayPausa
            source: "../../Play_Pause.png"
            anchors.right: imgHongoOculto.left
            anchors.rightMargin: appWindow.width * 0.02
            anchors.verticalCenter: parent.verticalCenter
            height: appWindow.height * 0.06
            fillMode: Image.PreserveAspectFit
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    animacionProgreso.pause();
                    root.mostrarPopupPausa = true;
                }
            }
        }

        Image {
            id: imgHongoOculto
            source: "../../Hongo_6.png"
            anchors.right: parent.right
            anchors.rightMargin: appWindow.width * 0.03
            anchors.bottom: parent.bottom
            anchors.bottomMargin: appWindow.height * 0.01
            height: parent.height * 0.90
            fillMode: Image.PreserveAspectFit
        }
    }

    // -- Popup Pausa -------------------------------------------------------
    Item {
        id: overlayPausa
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupPausa && !root.mostrarPopupConfirmarDetener
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.9)
            radius: 20

            Rectangle {
                width: parent.width * 0.55
                height: parent.height * 0.50
                anchors.centerIn: parent
                color: areaDetenerProceso.pressed ? "#404040" : "#555555"
                radius: 20
                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Detener\nproceso")
                    font.pixelSize: parent.height * 0.20
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                    id: areaDetenerProceso
                    anchors.fill: parent
                    onClicked: root.mostrarPopupConfirmarDetener = true
                }
            }

            Rectangle {
                width: appWindow.width * 0.12
                height: appWindow.height * 0.10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.10
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.05
                color: areaAtrasPausa.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea {
                    id: areaAtrasPausa
                    anchors.fill: parent
                    onClicked: {
                        root.mostrarPopupPausa = false;
                        animacionProgreso.resume();
                    }
                }
            }
        }
    }

    // -- Popup Confirmar Detener -------------------------------------------
    Item {
        id: overlayConfirmarParo
        anchors.fill: parent
        z: 250
        visible: root.mostrarPopupConfirmarDetener
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.60
            height: parent.height * 0.40
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.15
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "¿Seguro que deseas detener el proceso?")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.10
                color: areaOkDetener.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkDetener
                    anchors.fill: parent
                    onClicked: {
                        animacionProgreso.stop();
                        backend.detenerRegistro();
                        let lastIdx = appWindow.registro_experimentos.count - 1;
                        if (lastIdx >= 0) {
                            let e_total = root.progresoSimulado * appWindow.var_deseada_tiempo_total_horas;
                            appWindow.registro_experimentos.setProperty(lastIdx, "tiempo", e_total.toFixed(1) + " / " + appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " hrs");
                            let lects = backend.totalLecturas();
                            let kb = Math.ceil(lects * 55 / 1024);
                            appWindow.registro_experimentos.setProperty(lastIdx, "peso", lects + " lect. (~" + kb + " KB)");
                            appWindow.salvarRegistroExperimentos()
                        }
                        root.mostrarPopupConfirmarDetener = false;
                        root.mostrarPopupPausa = false;
                        root.progresoSimulado = 0.0;
                        appWindow.estadoActual = "pantalla_11";
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.10
                color: areaAtrasDetener.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea {
                    id: areaAtrasDetener
                    anchors.fill: parent
                    onClicked: root.mostrarPopupConfirmarDetener = false
                }
            }
        }
    }

    // -- Popup Finalizado --------------------------------------------------
    Item {
        id: overlayFinalizado
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupFinalizado
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.9)
            radius: 20

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.10
                text: qsTranslate("Main", "Proceso\nfinalizado")
                font.pixelSize: parent.height * 0.20
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: appWindow.width * 0.20
                height: appWindow.height * 0.10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.10
                anchors.horizontalCenter: parent.horizontalCenter
                color: areaOkFinalizado.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkFinalizado
                    anchors.fill: parent
                    onClicked: {
                        backend.detenerRegistro();
                        let lastIdx = appWindow.registro_experimentos.count - 1;
                        if (lastIdx >= 0) {
                            appWindow.registro_experimentos.setProperty(lastIdx, "tiempo", appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " / " + appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " hrs");
                            let lects = backend.totalLecturas();
                            let kb = Math.ceil(lects * 55 / 1024);
                            appWindow.registro_experimentos.setProperty(lastIdx, "peso", lects + " lect. (~" + kb + " KB)");
                            appWindow.salvarRegistroExperimentos()
                        }
                        root.progresoSimulado = 0.0;
                        root.mostrarPopupFinalizado = false;
                        appWindow.estadoActual = "pantalla_11";
                    }
                }
            }
        }
    }
}
