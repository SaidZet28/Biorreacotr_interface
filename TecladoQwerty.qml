import QtQuick 2.15

Rectangle {
    id: teclado
    color: "#E0E0E0"
    radius: 10

    // Señales — el componente no accede a ningún TextInput externo
    signal teclaPresionada(string texto)
    signal borrarPresionado()
    signal introPresionado()
    signal cerrarPresionado()

    property string modoActual: "lowercase"

    // Dimensiones internas de teclas, calculadas sobre el tamaño del componente
    property real anchoTecla: (width  - (8 * 12)) / 11
    property real altoTecla:  (height - (8 *  6)) /  5

    // Bloquea clics que atravesarían hacia abajo
    MouseArea { anchors.fill: parent }

    Column {
        anchors.centerIn: parent
        spacing: 8
        width: parent.width * 0.98
        height: parent.height * 0.95

        // ── Fila 1: números + Del ─────────────────────────────────────────
        Row {
            spacing: 8
            height: teclado.altoTecla
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: ["1","2","3","4","5","6","7","8","9","0"]
                Rectangle {
                    width: teclado.anchoTecla; height: parent.height; color: "white"; radius: 5
                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: parent.height * 0.60
                        color: "black"
                        text: teclado.modoActual === "symbols"
                              ? ["!","\"","#","$","%","&","/","(",")","="][index]
                              : modelData
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: teclado.teclaPresionada(parent.children[0].text)
                    }
                }
            }
            Rectangle {
                width: teclado.anchoTecla; height: parent.height; color: "#A0A0A0"; radius: 5
                Text { anchors.centerIn: parent; font.pixelSize: parent.height * 0.50; color: "black"; text: "Del" }
                MouseArea { anchors.fill: parent; onClicked: teclado.borrarPresionado() }
            }
        }

        // ── Fila 2: QWERTYUIOP + ⌫ ───────────────────────────────────────
        Row {
            spacing: 8
            height: teclado.altoTecla
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: ["Q","W","E","R","T","Y","U","I","O","P"]
                Rectangle {
                    width: teclado.anchoTecla; height: parent.height; color: "white"; radius: 5
                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: parent.height * 0.60
                        color: "black"
                        text: teclado.modoActual === "symbols"
                              ? ["+","-","*",":",";","_","¿","?","¡","'"][index]
                              : (teclado.modoActual === "uppercase" ? modelData : modelData.toLowerCase())
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: teclado.teclaPresionada(parent.children[0].text)
                    }
                }
            }
            Rectangle {
                width: teclado.anchoTecla; height: parent.height; color: "#A0A0A0"; radius: 5
                Text { anchors.centerIn: parent; font.pixelSize: parent.height * 0.50; color: "black"; text: "⌫" }
                MouseArea { anchors.fill: parent; onClicked: teclado.borrarPresionado() }
            }
        }

        // ── Fila 3: ASDFGHJKLÑ + Intro ───────────────────────────────────
        Row {
            spacing: 8
            height: teclado.altoTecla
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: ["A","S","D","F","G","H","J","K","L","Ñ"]
                Rectangle {
                    width: teclado.anchoTecla; height: parent.height; color: "white"; radius: 5
                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: parent.height * 0.60
                        color: "black"
                        text: teclado.modoActual === "symbols"
                              ? ["<",">","{","}","[","]","@","\\","|","~"][index]
                              : (teclado.modoActual === "uppercase" ? modelData : modelData.toLowerCase())
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: teclado.teclaPresionada(parent.children[0].text)
                    }
                }
            }
            Rectangle {
                width: teclado.anchoTecla; height: parent.height; color: "#8b5cf6"; radius: 5
                Text { anchors.centerIn: parent; font.pixelSize: parent.height * 0.40; color: "white"; font.bold: true; text: qsTr("Intro") }
                MouseArea { anchors.fill: parent; onClicked: teclado.introPresionado() }
            }
        }

        // ── Fila 4: Shift + ZXCVBNM + , . + Shift ────────────────────────
        Row {
            spacing: 8
            height: teclado.altoTecla
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: teclado.anchoTecla; height: parent.height; radius: 5
                color: teclado.modoActual === "symbols" ? "#D0D0D0" : "#A0A0A0"
                Text { anchors.centerIn: parent; text: "↑"; font.pixelSize: parent.height * 0.60; color: teclado.modoActual === "symbols" ? "gray" : "black" }
                MouseArea {
                    anchors.fill: parent
                    enabled: teclado.modoActual !== "symbols"
                    onClicked: teclado.modoActual = (teclado.modoActual === "lowercase") ? "uppercase" : "lowercase"
                }
            }
            Repeater {
                model: ["Z","X","C","V","B","N","M"]
                Rectangle {
                    width: teclado.anchoTecla; height: parent.height; color: "white"; radius: 5
                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: parent.height * 0.60
                        color: "black"
                        text: teclado.modoActual === "symbols"
                              ? ["^","`","€","£","¥","©","®"][index]
                              : (teclado.modoActual === "uppercase" ? modelData : modelData.toLowerCase())
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: teclado.teclaPresionada(parent.children[0].text)
                    }
                }
            }
            Rectangle {
                width: teclado.anchoTecla; height: parent.height; color: "white"; radius: 5
                Text { anchors.centerIn: parent; text: ","; font.pixelSize: parent.height * 0.60; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: teclado.teclaPresionada(",") }
            }
            Rectangle {
                width: teclado.anchoTecla; height: parent.height; color: "white"; radius: 5
                Text { anchors.centerIn: parent; text: "."; font.pixelSize: parent.height * 0.60; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: teclado.teclaPresionada(".") }
            }
            Rectangle {
                width: teclado.anchoTecla; height: parent.height; radius: 5
                color: teclado.modoActual === "symbols" ? "#D0D0D0" : "#A0A0A0"
                Text { anchors.centerIn: parent; text: "↑"; font.pixelSize: parent.height * 0.60; color: teclado.modoActual === "symbols" ? "gray" : "black" }
                MouseArea {
                    anchors.fill: parent
                    enabled: teclado.modoActual !== "symbols"
                    onClicked: teclado.modoActual = (teclado.modoActual === "lowercase") ? "uppercase" : "lowercase"
                }
            }
        }

        // ── Fila 5: ?123 + Espacio + Cerrar ──────────────────────────────
        Row {
            spacing: 8
            height: teclado.altoTecla
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: teclado.anchoTecla * 2 + 8; height: parent.height; color: "#A0A0A0"; radius: 5
                Text { anchors.centerIn: parent; text: teclado.modoActual === "symbols" ? "ABC" : "?123"; font.pixelSize: parent.height * 0.40; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: teclado.modoActual = (teclado.modoActual === "symbols") ? "lowercase" : "symbols" }
            }
            Rectangle {
                width: teclado.anchoTecla * 7 + (8 * 6); height: parent.height; color: "white"; radius: 5
                Text { anchors.centerIn: parent; text: qsTr("Espacio"); font.pixelSize: parent.height * 0.40; color: "gray" }
                MouseArea { anchors.fill: parent; onClicked: teclado.teclaPresionada(" ") }
            }
            Rectangle {
                width: teclado.anchoTecla * 2 + 8; height: parent.height; color: "#A0A0A0"; radius: 5
                Text { anchors.centerIn: parent; text: qsTr("Cerrar"); font.pixelSize: parent.height * 0.40; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: teclado.cerrarPresionado() }
            }
        }
    }
}
