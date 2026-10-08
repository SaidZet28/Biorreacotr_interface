import QtQuick 2.15
import Prototipo

// ─────────────────────────────────────────────────────────────────────────────
// Gráfica en tiempo real SIN QtCharts (Canvas + Text de QtQuick).
// QtCharts crasheaba en su propio init (ChartTitle/tema/fuente) bajo eglfs en la
// RPi (y en Windows). Esta versión dibuja con Canvas — el mismo camino de render
// que el resto de la interfaz — y las etiquetas con Text (fuente embebida → ° y
// acentos). Interfaz externa idéntica a la anterior: appWindow, pausado,
// finalizado, resetear(). Muestra Sensor y Setpoint vs tiempo (minutos), con la
// variable elegida en appWindow.var_seleccion_grafica (1=Temp, 2=Agua, 3=pH, 4=Luz).
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property var  appWindow:  null
    property bool pausado:    false
    property bool finalizado: false

    // Datos (arrays JS de {t, v}; t en minutos). No se usan en bindings: el repintado
    // se dispara a mano con requestPaint() para evitar copias por cada muestra.
    property var  _sensor:   []
    property var  _setpoint: []
    property real _tSeg:     0.0

    property real ventanaMinutos: 5.0
    property int  maxPuntos:      300
    property real xMin: 0.0
    property real xMax: 5.0
    property real yMin: 0.0
    property real yMax: 100.0

    readonly property color colBg:       "#6E9C9C"
    readonly property color colPlot:     "#3d6b6b"
    readonly property color colGrid:     "#508888"
    readonly property color colSensor:   "#00e5ff"
    readonly property color colSetpoint: "#ff9800"

    // Rango del eje Y según la variable (Temp respeta °C/°F)
    function _rangoY() {
        if (!appWindow) return [0, 100]
        switch (appWindow.var_seleccion_grafica) {
        case 1: { var esF = appWindow.unidadTemperatura === "F"; return esF ? [32, 122] : [0, 50] }
        case 2: return [0, 100]
        case 3: return [0, 14]
        case 4: return [0, 100]
        }
        return [0, 100]
    }
    function _titulo() {
        if (!appWindow) return ""
        switch (appWindow.var_seleccion_grafica) {
        case 1: return qsTranslate("Main", "Temperatura °") + appWindow.unidadTemperatura
        case 2: return qsTranslate("Main", "Nivel de Agua")
        case 3: return qsTranslate("Main", "Nivel de pH")
        case 4: return qsTranslate("Main", "Nivel de Luz")
        }
        return ""
    }

    function resetear() {
        _sensor = []
        _setpoint = []
        _tSeg = 0.0
        xMin = 0.0
        xMax = ventanaMinutos
        var r = _rangoY(); yMin = r[0]; yMax = r[1]
        lienzo.requestPaint()
    }

    Component.onCompleted: resetear()

    // Fondo de la tarjeta
    Rectangle { anchors.fill: parent; color: root.colBg; radius: 10 }

    // Título (Text QML → usa la fuente embebida, renderiza ° y acentos)
    Text {
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.03
        anchors.horizontalCenter: parent.horizontalCenter
        text: root._titulo()
        color: "white"
        font.bold: true
        font.pixelSize: Math.max(1, parent.height * 0.075)
    }

    // Área de graficado (define los márgenes: título arriba, etiquetas a los lados)
    Item {
        id: area
        anchors.fill: parent
        anchors.topMargin: parent.height * 0.15
        anchors.bottomMargin: parent.height * 0.16
        anchors.leftMargin: parent.width * 0.12
        anchors.rightMargin: parent.width * 0.04

        // Lienzo: fondo del plot + rejilla + curvas
        Canvas {
            id: lienzo
            anchors.fill: parent
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                var W = width, H = height
                if (W <= 0 || H <= 0) return
                ctx.reset()

                // Fondo del área de graficado
                ctx.fillStyle = root.colPlot
                ctx.fillRect(0, 0, W, H)

                // Rejilla (5 divisiones en cada eje)
                ctx.strokeStyle = root.colGrid
                ctx.lineWidth = 1
                ctx.beginPath()
                for (var i = 0; i <= 5; i++) { var gx = Math.round(i / 5 * W) + 0.5; ctx.moveTo(gx, 0); ctx.lineTo(gx, H) }
                for (var j = 0; j <= 5; j++) { var gy = Math.round(j / 5 * H) + 0.5; ctx.moveTo(0, gy); ctx.lineTo(W, gy) }
                ctx.stroke()

                // Mapeo dato → pixel
                var dx = (root.xMax - root.xMin) || 1
                var dy = (root.yMax - root.yMin) || 1
                function X(t) { return (t - root.xMin) / dx * W }
                function Y(v) { return H - (v - root.yMin) / dy * H }

                function traza(arr, col) {
                    if (!arr || arr.length < 1) return
                    ctx.strokeStyle = col
                    ctx.lineWidth = 3.5
                    ctx.beginPath()
                    for (var k = 0; k < arr.length; k++) {
                        var px = X(arr[k].t), py = Y(arr[k].v)
                        if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                    }
                    ctx.stroke()
                }
                traza(root._setpoint, root.colSetpoint)
                traza(root._sensor,   root.colSensor)

                // Marco
                ctx.strokeStyle = "white"
                ctx.lineWidth = 1
                ctx.strokeRect(0.5, 0.5, W - 1, H - 1)
            }
        }

        // Etiquetas eje Y (6, de arriba=yMax a abajo=yMin)
        Repeater {
            model: 6
            Text {
                property real val: root.yMax - (index / 5) * (root.yMax - root.yMin)
                text: val.toFixed(1)
                color: "white"
                font.pixelSize: Math.max(1, root.height * 0.045)
                x: -width - root.width * 0.015
                y: index / 5 * area.height - height / 2
            }
        }
        // Etiquetas eje X (6, tiempo en minutos)
        Repeater {
            model: 6
            Text {
                property real val: root.xMin + (index / 5) * (root.xMax - root.xMin)
                text: val.toFixed(1)
                color: "white"
                font.pixelSize: Math.max(1, root.height * 0.045)
                x: index / 5 * area.width - width / 2
                y: area.height + root.height * 0.02
            }
        }
    }

    // Leyenda (abajo, centrada)
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.03
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: parent.width * 0.05

        Row {
            spacing: 6
            Rectangle { width: 18; height: 4; radius: 2; color: root.colSensor; anchors.verticalCenter: parent.verticalCenter }
            Text { text: qsTranslate("Main", "Sensor"); color: "white"; font.pixelSize: Math.max(1, root.height * 0.045); anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            spacing: 6
            Rectangle { width: 18; height: 4; radius: 2; color: root.colSetpoint; anchors.verticalCenter: parent.verticalCenter }
            Text { text: qsTranslate("Main", "Setpoint"); color: "white"; font.pixelSize: Math.max(1, root.height * 0.045); anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Muestreo cada 1 s (igual que antes)
    Timer {
        interval: 1000
        running: !root.pausado && !root.finalizado && root.appWindow !== null
        repeat: true
        onTriggered: {
            if (!root.appWindow) return
            root._tSeg += 1.0
            var tMin = root._tSeg / 60.0

            var vS = 0.0, vSP = 0.0
            switch (root.appWindow.var_seleccion_grafica) {
            case 1: vS = root.appWindow.tempMostrada(backend.sensorTem); vSP = root.appWindow.tempMostrada(backend.setpointTem); break
            case 2: vS = backend.sensorNivel; vSP = backend.nivelLlenadoPct; break
            case 3: vS = backend.sensorPH;    vSP = backend.setpointPH;    break
            case 4: vS = backend.sensorLuz;   vSP = backend.setpointLuz;   break
            default: return
            }

            root._sensor.push({ t: tMin, v: vS })
            root._setpoint.push({ t: tMin, v: vSP })
            if (root._sensor.length > root.maxPuntos) { root._sensor.shift(); root._setpoint.shift() }

            if (tMin > root.xMax) {
                root.xMax = tMin
                root.xMin = Math.max(0.0, tMin - root.ventanaMinutos)
            }
            lienzo.requestPaint()
        }
    }

    // Reset al cambiar la variable graficada
    Connections {
        target: root.appWindow
        function onVar_seleccion_graficaChanged() { root.resetear() }
    }

    // Tocar la gráfica → menú de selección de variable
    MouseArea {
        anchors.fill: parent
        onClicked: { if (root.appWindow) root.appWindow.estadoActual = "pantalla_configuracion_graficas" }
    }
}
