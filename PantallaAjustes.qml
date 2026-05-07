import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_configuraciones"

    property bool mostrarPopupIdioma: false
    property string tempIdioma: appWindow.idiomaActual

    property bool mostrarPopupUnidades: false
    property string tempUnidades: appWindow.unidadTemperatura

    property bool mostrarPopupCreditos: false

    Text {
        text: qsTranslate("Main", "Configuraciones")
        font.pixelSize: appWindow.height * 0.08
        font.bold: true
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.15
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: appWindow.height * 0.05
        spacing: appWindow.height * 0.05

        BotonAccionVerde {
            textoBoton: qsTranslate("Main", "Idioma: %1").arg(qsTranslate("Main", appWindow.idiomaActual))
            onClicado: {
                root.tempIdioma = appWindow.idiomaActual;
                root.mostrarPopupIdioma = true;
            }
        }
        BotonAccionVerde {
            textoBoton: qsTranslate("Main", "Unidades: °%1").arg(appWindow.unidadTemperatura)
            onClicado: {
                root.tempUnidades = appWindow.unidadTemperatura;
                root.mostrarPopupUnidades = true;
            }
        }
        BotonAccionVerde {
            textoBoton: qsTranslate("Main", "Créditos")
            onClicado: root.mostrarPopupCreditos = true
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: parent.width * 0.05
        width: parent.width * 0.12
        height: parent.height * 0.10
        color: areaAtrasAjustes.pressed ? "#cc1e1e" : "#FF2D2D"
        radius: height / 2

        Text {
            anchors.centerIn: parent
            text: "↶"
            color: "black"
            font.pixelSize: parent.height * 0.70
            font.bold: true
        }
        MouseArea {
            id: areaAtrasAjustes
            anchors.fill: parent
            onClicked: appWindow.estadoActual = appWindow.estadoPrevioAjustes
        }
    }

    // --- POPUP: IDIOMA ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupIdioma
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.65
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.08
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Seleccione el Idioma")
                font.pixelSize: parent.height * 0.08
                font.bold: true
                color: "black"
            }

            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: appWindow.width * 0.05
                rowSpacing: appWindow.height * 0.03

                Repeater {
                    model: [
                        { original: "Español", traducido: qsTranslate("Main", "Español") },
                        { original: "Inglés", traducido: qsTranslate("Main", "Inglés") },
                        { original: "Alemán", traducido: qsTranslate("Main", "Alemán") },
                        { original: "Francés", traducido: qsTranslate("Main", "Francés") },
                        { original: "Chino", traducido: qsTranslate("Main", "Chino") },
                        { original: "Japonés", traducido: qsTranslate("Main", "Japonés") }
                    ]
                    Rectangle {
                        width: appWindow.width * 0.22
                        height: appWindow.height * 0.08
                        radius: height / 2
                        color: root.tempIdioma === modelData.original ? "#A5D6A7" : "white"
                        border.color: "black"
                        border.width: root.tempIdioma === modelData.original ? 3 : 1
                        Text {
                            anchors.centerIn: parent
                            text: modelData.traducido
                            font.pixelSize: parent.height * 0.45
                            font.bold: true
                            color: "black"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.tempIdioma = modelData.original
                        }
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.08
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.15
                color: areaOkIdioma.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkIdioma
                    anchors.fill: parent
                    onClicked: {
                        appWindow.idiomaActual = root.tempIdioma;

                        if (appWindow.idiomaActual === "Inglés") {
                            TraductorC.cambiarIdioma("en");
                        } else if (appWindow.idiomaActual === "Alemán") {
                            TraductorC.cambiarIdioma("de");
                        } else if (appWindow.idiomaActual === "Francés") {
                            TraductorC.cambiarIdioma("fr");
                        } else if (appWindow.idiomaActual === "Chino") {
                            TraductorC.cambiarIdioma("zh");
                        } else if (appWindow.idiomaActual === "Japonés") {
                            TraductorC.cambiarIdioma("ja");
                        } else {
                            TraductorC.cambiarIdioma("es");
                        }

                        root.mostrarPopupIdioma = false;
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.08
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.15
                color: areaAtrasIdioma.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasIdioma; anchors.fill: parent; onClicked: root.mostrarPopupIdioma = false }
            }
        }
    }

    // --- POPUP: UNIDADES ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupUnidades
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Unidades de Temperatura")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
            }

            Row {
                anchors.centerIn: parent
                spacing: appWindow.width * 0.05

                Repeater {
                    model: ["C", "F"]
                    Rectangle {
                        width: appWindow.width * 0.20
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: root.tempUnidades === modelData ? "#A5D6A7" : "white"
                        border.color: "black"
                        border.width: root.tempUnidades === modelData ? 3 : 1
                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Grados °%1").arg(modelData)
                            font.pixelSize: parent.height * 0.40
                            font.bold: true
                            color: "black"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.tempUnidades = modelData
                        }
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.10
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.15
                color: areaOkUnidades.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkUnidades
                    anchors.fill: parent
                    onClicked: {
                        if (appWindow.unidadTemperatura === "C" && root.tempUnidades === "F") {
                            appWindow.var_deseada_Tem = (appWindow.var_deseada_Tem * 9/5) + 32;
                            appWindow.var_sensor_Tem = (appWindow.var_sensor_Tem * 9/5) + 32;
                        } else if (appWindow.unidadTemperatura === "F" && root.tempUnidades === "C") {
                            appWindow.var_deseada_Tem = (appWindow.var_deseada_Tem - 32) * 5/9;
                            appWindow.var_sensor_Tem = (appWindow.var_sensor_Tem - 32) * 5/9;
                        }
                        appWindow.unidadTemperatura = root.tempUnidades;
                        root.mostrarPopupUnidades = false;
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.10
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.15
                color: areaAtrasUnidades.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasUnidades; anchors.fill: parent; onClicked: root.mostrarPopupUnidades = false }
            }
        }
    }

    // --- POPUP: CRÉDITOS ---
    Item {
        id: popupCreditosRoot
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupCreditos
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            id: cajaCreditos
            width: parent.width * 0.75
            height: parent.height * 0.75
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Text {
                id: tituloCreditos
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.08
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Créditos del Proyecto")
                font.pixelSize: parent.height * 0.08
                font.bold: true
                color: "black"
            }

            Text {
                anchors.top: tituloCreditos.bottom
                anchors.topMargin: parent.height * 0.06
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.RichText
                horizontalAlignment: Text.AlignHCenter
                text: "<div align='center'><b>" + qsTranslate("Main", "Hecho por:") + "</b><br>" +
                      "Huang Sánchez Jet Ming Adrián<br>" +
                      "Júnez Huerta María Jimena<br>" +
                      "Zesati Márquez Jesús Said<br><br>" +
                      "<b>" + qsTranslate("Main", "Asesores:") + "</b><br>" +
                      "M. en I. Hernández González Umanel Azazael<br>" +
                      "M. en C. Mirelez Delgado Flabio Dario<br>" +
                      "M. en P. y M. Talavera Otero Jorge</div>"
                font.pixelSize: parent.height * 0.045
                color: "black"
            }

            Rectangle {
                width: appWindow.width * 0.20
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.05
                anchors.horizontalCenter: parent.horizontalCenter
                color: areaOkCreditos.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Cerrar"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkCreditos
                    anchors.fill: parent
                    onClicked: root.mostrarPopupCreditos = false
                }
            }
        }
    }
}
