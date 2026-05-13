import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_procesos"

    property real progresoSimulado: 0.0
    property bool mostrarPopupPausa: false
    property bool mostrarPopupFinalizado: false
    property bool mostrarPopupConfirmarDetener: false

    PropertyAnimation {
        id: animacionProgreso
        target: root
        property: "progresoSimulado"
        from: 0.0
        to: 1.0
        duration: Math.max(1000, Math.min(Math.floor(appWindow.var_deseada_tiempo_total_horas * 3600000), 2100000000))
        onFinished: {
            if (root.progresoSimulado >= 1.0) {
                root.mostrarPopupFinalizado = true;
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (appWindow.procesoListoParaIniciar) {
                appWindow.procesoListoParaIniciar = false;
                progresoSimulado = 0.0;
                mostrarPopupPausa = false;
                mostrarPopupFinalizado = false;
                mostrarPopupConfirmarDetener = false;
                animacionProgreso.start();
            }
        }
    }

    Rectangle {
        id: cajaGrafica
        width: parent.width * 0.45
        height: parent.height * 0.55
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.05
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.20
        color: "#6E9C9C"
        radius: 20

        MouseArea {
            anchors.fill: parent
            onClicked: appWindow.estadoActual = "pantalla_configuracion_graficas"
        }
        Text {
            text: qsTranslate("Main", "Gráfica de :") + " " + [
                "", qsTranslate("Main", "Temperatura"), qsTranslate("Main", "N. Agua"), "pH", qsTranslate("Main", "Luz")
            ][appWindow.var_seleccion_grafica]
            font.pixelSize: parent.height * 0.08
            font.bold: true
            color: "black"
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.left: parent.left
            anchors.leftMargin: 30
        }
        Rectangle {
            width: 4
            color: "black"
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.top: parent.top
            anchors.topMargin: 70
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
        }
        Rectangle {
            height: 4
            color: "black"
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
        }
    }

    Column {
        id: pildorasProceso
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.05
        anchors.verticalCenter: cajaGrafica.verticalCenter
        width: parent.width * 0.40
        spacing: appWindow.height * 0.025

        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Temp °%1: %2").arg(appWindow.unidadTemperatura).arg((appWindow.unidadTemperatura === "F" ? (backend.sensorTem * 9/5 + 32) : backend.sensorTem).toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Temp °%1: %2").arg(appWindow.unidadTemperatura).arg(backend.setpointTem.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. pH: %1").arg(backend.sensorPH.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. pH: %1").arg(backend.setpointPH.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. Agua: %1%").arg(backend.sensorAgua.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. Agua: %1%").arg(backend.setpointAgua.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. Luz: %1%").arg(backend.sensorLuz.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. Luz: %1%").arg(backend.setpointLuz.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2
            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. CO2: %1 ppm").arg(backend.sensorCO2.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "N. CO2: %1 ppm").arg(backend.setpointCO2.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        }
    }

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
                source: "Engrane.png"
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
            source: "Play_Pause.png"
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
            source: "Hongo_6.png"
            anchors.right: parent.right
            anchors.rightMargin: appWindow.width * 0.03
            anchors.bottom: parent.bottom
            anchors.bottomMargin: appWindow.height * 0.01
            height: parent.height * 0.90
            fillMode: Image.PreserveAspectFit
        }
    }

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
                    onClicked: {
                        root.mostrarPopupConfirmarDetener = true;
                    }
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
                Text {
                    anchors.centerIn: parent
                    text: "↶"
                    font.pixelSize: parent.height * 0.70
                    font.bold: true
                    color: "black"
                }
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
                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Okay")
                    font.pixelSize: parent.height * 0.40
                    font.bold: true
                    color: "black"
                }
                MouseArea {
                    id: areaOkDetener
                    anchors.fill: parent
                    onClicked: {
                        animacionProgreso.stop();
                        let lastIdx = appWindow.registro_experimentos.count - 1;
                        if (lastIdx >= 0) {
                            let e_total = root.progresoSimulado * appWindow.var_deseada_tiempo_total_horas;
                            appWindow.registro_experimentos.setProperty(lastIdx, "tiempo", e_total.toFixed(1) + " / " + appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " hrs");
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
                Text {
                    anchors.centerIn: parent
                    text: "↶"
                    font.pixelSize: parent.height * 0.70
                    font.bold: true
                    color: "black"
                }
                MouseArea {
                    id: areaAtrasDetener
                    anchors.fill: parent
                    onClicked: {
                        root.mostrarPopupConfirmarDetener = false;
                    }
                }
            }
        }
    }

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
                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Okay")
                    font.pixelSize: parent.height * 0.40
                    font.bold: true
                    color: "black"
                }
                MouseArea {
                    id: areaOkFinalizado
                    anchors.fill: parent
                    onClicked: {
                        let lastIdx = appWindow.registro_experimentos.count - 1;
                        if (lastIdx >= 0) {
                            appWindow.registro_experimentos.setProperty(lastIdx, "tiempo", appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " / " + appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " hrs");
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
