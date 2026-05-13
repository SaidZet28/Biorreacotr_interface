import QtQuick 2.15
import QtCharts

Item {
    id: root

    property var  appWindow: null
    property bool pausado:   false
    property bool finalizado: false

    function resetear() {
        seriesSensor.clear()
        seriesSetpoint.clear()
        chartView.tiempoSegundos = 0.0
        axisX.min = 0
        axisX.max = chartView.ventanaMinutos
        actualizarEjesY()
    }

    function actualizarEjesY() {
        if (!root.appWindow) return
        switch (root.appWindow.var_seleccion_grafica) {
            case 1: axisY.min = 0; axisY.max = 50;  break
            case 2: axisY.min = 0; axisY.max = 100; break
            case 3: axisY.min = 0; axisY.max = 14;  break
            case 4: axisY.min = 0; axisY.max = 100; break
        }
    }

    ChartView {
        id: chartView
        anchors.fill: parent

        backgroundColor: "#6E9C9C"
        plotAreaColor:   "#3d6b6b"
        antialiasing: true

        legend.alignment:  Qt.AlignBottom
        legend.labelColor: "white"

        title: {
            if (!root.appWindow) return ""
            switch (root.appWindow.var_seleccion_grafica) {
                case 1: return qsTranslate("Main", "Temperatura °") + root.appWindow.unidadTemperatura
                case 2: return qsTranslate("Main", "Nivel de Agua")
                case 3: return qsTranslate("Main", "Nivel de pH")
                case 4: return qsTranslate("Main", "Nivel de Luz")
                default: return ""
            }
        }
        titleColor: "white"

        property int  maxPuntos:      300
        property real tiempoSegundos: 0.0
        property real ventanaMinutos: 5.0

        Component.onCompleted: root.actualizarEjesY()

        ValueAxis {
            id: axisX
            min: 0; max: 5; tickCount: 6
            labelFormat: "%.1f"
            labelsColor: "white"
            gridLineColor: "#508888"
            color: "white"
        }

        ValueAxis {
            id: axisY
            min: 0; max: 100; tickCount: 6
            labelFormat: "%.1f"
            labelsColor: "white"
            gridLineColor: "#508888"
            color: "white"
        }

        LineSeries {
            id: seriesSensor
            name: qsTranslate("Main", "Sensor")
            axisX: axisX; axisY: axisY
            color: "#00e5ff"; width: 2
        }

        LineSeries {
            id: seriesSetpoint
            name: qsTranslate("Main", "Setpoint")
            axisX: axisX; axisY: axisY
            color: "#ff9800"; width: 2
        }

        Timer {
            interval: 1000
            running: !root.pausado && !root.finalizado && root.appWindow !== null
            repeat: true
            onTriggered: {
                if (!root.appWindow) return
                chartView.tiempoSegundos += 1.0
                const tMin = chartView.tiempoSegundos / 60.0

                let vSensor = 0.0, vSetpoint = 0.0
                switch (root.appWindow.var_seleccion_grafica) {
                    case 1: vSensor = backend.sensorTem;   vSetpoint = backend.setpointTem;   break
                    case 2: vSensor = backend.sensorNivel; vSetpoint = backend.setpointNivel; break
                    case 3: vSensor = backend.sensorPH;    vSetpoint = backend.setpointPH;    break
                    case 4: vSensor = backend.sensorLuz;   vSetpoint = backend.setpointLuz;   break
                    default: return
                }

                seriesSensor.append(tMin, vSensor)
                seriesSetpoint.append(tMin, vSetpoint)

                if (seriesSensor.count > chartView.maxPuntos) {
                    seriesSensor.removePoints(0, 1)
                    seriesSetpoint.removePoints(0, 1)
                }

                if (tMin > axisX.max) {
                    axisX.max = tMin
                    axisX.min = Math.max(0.0, tMin - chartView.ventanaMinutos)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.appWindow)
                    root.appWindow.estadoActual = "pantalla_configuracion_graficas"
            }
        }
    }

    Connections {
        target: root.appWindow
        function onVar_seleccion_graficaChanged() { root.resetear() }
    }
}
