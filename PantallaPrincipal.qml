import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_principal"

    Image {
        source: "Hongo_3.png"
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: parent.width * 0.02
        width: parent.width * 0.11
        fillMode: Image.PreserveAspectFit
    }

    Column {
        id: columnaBarrasPrincipales
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.05
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: appWindow.height * 0.03
        spacing: parent.height * 0.03

        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Temperatura:"); textoValor: qsTranslate("Main", "%1 °%2").arg((appWindow.unidadTemperatura === "F" ? (backend.sensorTem * 9/5 + 32) : backend.sensorTem).toFixed(1)).arg(appWindow.unidadTemperatura) }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Nivel de pH:"); textoValor: qsTranslate("Main", "%1").arg(backend.sensorPH.toFixed(1)) }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Nivel de agua:"); textoValor: qsTranslate("Main", "%1 %").arg(backend.sensorNivel.toFixed(0)) }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Nivel de luz:"); textoValor: qsTranslate("Main", "%1 %").arg(backend.sensorLuz.toFixed(0)) }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Nivel de CO2:"); textoValor: qsTranslate("Main", "%1 ppm").arg(backend.sensorCO2.toFixed(0)) }
    }

    Column {
        anchors.left: parent.left
        anchors.right: columnaBarrasPrincipales.left
        anchors.top: columnaBarrasPrincipales.top
        spacing: columnaBarrasPrincipales.spacing

        BotonAccionVerde {
            anchors.horizontalCenter: parent.horizontalCenter
            textoBoton: qsTranslate("Main", "Nuevo Proyecto")
            onClicado: {
                appWindow.omitirPedirNombre = false;
                appWindow.estadoActual = "pantalla_nuevo_proyecto";
            }
        }
        BotonAccionVerde {
            anchors.horizontalCenter: parent.horizontalCenter
            textoBoton: qsTranslate("Main", "Datos Guardados")
            onClicado: {
                appWindow.omitirPedirNombre = false;
                appWindow.estadoActual = "pantalla_15";
            }
        }
    }

    Rectangle {
        id: botonAjustes
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: appWindow.width * 0.05
        anchors.bottomMargin: appWindow.height * 0.04
        width: appWindow.width * 0.09
        height: appWindow.height * 0.11
        radius: width * 0.35
        color: areaMouseEngrane.pressed ? "#9ca3af" : "#B3B3B3"

        Image {
            source: "Engrane.png"
            anchors.centerIn: parent
            width: parent.width * 0.65
            height: parent.height * 0.65
            fillMode: Image.PreserveAspectFit
        }
        MouseArea {
            id: areaMouseEngrane
            anchors.fill: parent
            onClicked: {
                appWindow.estadoPrevioAjustes = "pantalla_principal"
                appWindow.estadoActual = "pantalla_configuraciones"
            }
        }
    }
}
