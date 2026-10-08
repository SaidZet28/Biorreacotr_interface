import QtQuick 2.15
import Prototipo
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

    property bool mostrarPopupVaciado: false
    // Seguridad: al salir de Configuraciones, cierra el vaciado manual (válvulas + OE HIGH)
    // por si quedó algún toggle encendido.
    onVisibleChanged: {
        if (!visible) {
            root.mostrarPopupVaciado = false
            backend.cerrarVaciadoManual()
        }
    }

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
            textoBoton: qsTranslate("Main", "Calibrar tanque")
            onClicado: appWindow.estadoActual = "pantalla_calibracion_tanque"
        }
        BotonAccionVerde {
            textoBoton: qsTranslate("Main", "Caracterizar nivel")
            onClicado: appWindow.estadoActual = "pantalla_caracterizacion_nivel"
        }
        BotonAccionVerde {
            textoBoton: qsTranslate("Main", "Vaciado manual")
            onClicado: root.mostrarPopupVaciado = true
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

    // --- POPUP: VACIADO MANUAL ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupVaciado
        MouseArea { anchors.fill: parent; hoverEnabled: true }   // bloquea toques detrás

        Rectangle {
            width: parent.width * 0.68
            height: parent.height * 0.66
            anchors.centerIn: parent
            color: Qt.rgba(0.90, 0.94, 0.98, 0.97)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.06
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Vaciado manual")
                font.pixelSize: parent.height * 0.085
                font.bold: true
                color: "black"
            }

            // Nota de disponibilidad / seguridad
            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.19
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.86
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: backend.procesoActivo
                      ? qsTranslate("Main", "No disponible: hay un proceso activo. El vaciado manual solo funciona con el equipo en reposo.")
                      : qsTranslate("Main", "Toca cada electroválvula para abrirla o cerrarla. Se cierran todas al salir.")
                font.pixelSize: parent.height * 0.040
                color: backend.procesoActivo ? "#b00000" : "#333333"
            }

            // 3 toggles independientes (EV inferior CH8, EV superior CH10, EV vaciado 3 CH11)
            Column {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.34
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: appWindow.height * 0.028

                Repeater {
                    model: [
                        { etiqueta: qsTranslate("Main", "EV inferior (CH8)"),   idx: 0 },
                        { etiqueta: qsTranslate("Main", "EV superior (CH10)"),  idx: 1 },
                        { etiqueta: qsTranslate("Main", "EV vaciado 3 (CH11)"), idx: 2 }
                    ]
                    Rectangle {
                        property bool encendido: modelData.idx === 0 ? backend.vaciadoManualInf
                                               : modelData.idx === 1 ? backend.vaciadoManualSup
                                                                     : backend.vaciadoManualAux
                        width: appWindow.width * 0.42
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: encendido ? "#2E90AE" : "#cfd8d8"
                        border.color: encendido ? "#1f6f86" : "#9bb3b3"
                        border.width: 2
                        Row {
                            anchors.centerIn: parent
                            spacing: appWindow.width * 0.012
                            Text {
                                text: encendido ? "●" : "○"
                                color: encendido ? "white" : "#667"
                                font.pixelSize: parent.parent.height * 0.44
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.etiqueta
                                color: encendido ? "white" : "#333"
                                font.pixelSize: parent.parent.height * 0.30
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: backend.toggleVaciadoManual(modelData.idx) }
                    }
                }
            }

            // Cerrar (apaga las 3 válvulas + OE HIGH)
            Rectangle {
                width: appWindow.width * 0.18
                height: appWindow.height * 0.09
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.07
                anchors.horizontalCenter: parent.horizontalCenter
                color: areaCerrarVaciado.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Cerrar"); font.pixelSize: parent.height * 0.36; font.bold: true; color: "black" }
                MouseArea {
                    id: areaCerrarVaciado
                    anchors.fill: parent
                    onClicked: {
                        backend.cerrarVaciadoManual()
                        root.mostrarPopupVaciado = false
                    }
                }
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
                        // setpointTem se mantiene SIEMPRE en °C; solo cambia la unidad de display
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
