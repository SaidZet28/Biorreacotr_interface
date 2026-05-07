import QtQuick 2.15

Item {
    id: teclado

    signal digitoPresionado(string d)
    signal puntoPresionado()
    signal borrarPresionado()
    signal okPresionado()

    property real espaciado: 8
    property real anchoTecla: (width  - espaciado * 3) / 4
    property real altoTecla:  (height - espaciado * 3) / 4

    Grid {
        anchors.centerIn: parent
        columns: 4
        rows: 4
        spacing: teclado.espaciado

        Repeater {
            model: ["7","8","9","DEL","4","5","6","OK","1","2","3","","","0",".",""]
            Rectangle {
                width:   teclado.anchoTecla
                height:  teclado.altoTecla
                opacity: modelData === "" ? 0 : 1
                radius:  10
                color: modelData === "" ? "transparent"
                     : areaTecla.pressed   ? "#C4C0B7"
                     : modelData === "OK"  ? "#7B8A80"
                     : modelData === "DEL" ? "#615E5E"
                     : "#E4E0D7"
                border.color: "#D1CDC4"
                border.width: (modelData !== "" && modelData !== "OK" && modelData !== "DEL") ? 1 : 0

                Text {
                    anchors.centerIn: parent
                    text: modelData === "DEL" ? qsTranslate("Main", "DEL")
                        : modelData === "OK"  ? qsTranslate("Main", "OK")
                        : modelData
                    font.pixelSize: parent.height * 0.40
                    color: (modelData === "OK" || modelData === "DEL") ? "#F5F5F5" : "#4A4A4A"
                }
                MouseArea {
                    id: areaTecla
                    anchors.fill: parent
                    enabled: modelData !== ""
                    onClicked: {
                        if      (modelData === "DEL") teclado.borrarPresionado()
                        else if (modelData === "OK")  teclado.okPresionado()
                        else if (modelData === ".")   teclado.puntoPresionado()
                        else                          teclado.digitoPresionado(modelData)
                    }
                }
            }
        }
    }
}
