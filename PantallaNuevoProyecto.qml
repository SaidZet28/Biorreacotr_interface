import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_nuevo_proyecto"

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.05
        spacing: parent.width * 0.05

        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.40
            color: areaBotonProyectosGuardados.pressed ? "#7da84c" : "#8DBB5A"
            radius: 20
            Text {
                anchors.centerIn: parent
                text: qsTranslate("Main", "Proyectos\nguardados")
                horizontalAlignment: Text.AlignHCenter
                color: "black"
                font.pixelSize: parent.height * 0.15
                font.bold: true
            }
            MouseArea {
                id: areaBotonProyectosGuardados
                anchors.fill: parent
                onClicked: appWindow.estadoActual = "pantalla_proyectos_guardados"
            }
        }
        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.40
            color: areaBotonNuevoProyecto.pressed ? "#5a8282" : "#6E9C9C"
            radius: 20
            Text {
                anchors.centerIn: parent
                text: qsTranslate("Main", "Nuevo\nproyecto")
                horizontalAlignment: Text.AlignHCenter
                color: "black"
                font.pixelSize: parent.height * 0.15
                font.bold: true
            }
            MouseArea {
                id: areaBotonNuevoProyecto
                anchors.fill: parent
                onClicked: {
                    appWindow.estadoPrevioPantalla6 = "pantalla_nuevo_proyecto"
                    appWindow.omitirPedirNombre = false
                    appWindow.limpiarDatos(false)
                    appWindow.estadoActual = "pantalla_6"
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: parent.width * 0.05
        width: parent.width * 0.12
        height: parent.height * 0.10
        color: areaAtrasSeleccion.pressed ? "#cc1e1e" : "#FF2D2D"
        radius: height / 2

        Text {
            anchors.centerIn: parent
            text: "↶"
            color: "black"
            font.pixelSize: parent.height * 0.70
            font.bold: true
        }
        MouseArea {
            id: areaAtrasSeleccion
            anchors.fill: parent
            onClicked: appWindow.estadoActual = "pantalla_principal"
        }
    }
}
