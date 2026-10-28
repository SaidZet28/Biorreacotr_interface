import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow
    visible: appWindow.estadoActual === "pantalla_preparacion"

    onVisibleChanged: {
        if (visible) {
            root._estadoPrevio = -1
            root.mostrarConfirmCancelar = false
            root.mostrarResync = false
            backend.iniciarPreparacion()
        }
    }

    property int _estadoPrevio: -1
    property bool mostrarConfirmCancelar: false
    property bool mostrarResync: false          // popup de re-sincronización del nivel

    Connections {
        target: backend
        function onPreparacionCancelada() { appWindow.procesoListoParaIniciar = false }
        function onEstadoPreparacionChanged() {
            let s = backend.estadoPreparacion
            // Sonido de éxito cada vez que la preparación avanza a un estado nuevo (0→1, 1→2 … 5→6)
            if (s > 0 && s > root._estadoPrevio) audio.reproducirExito()
            root._estadoPrevio = s
        }
    }

    // ── 4 fases visibles que agrupan los 7 estados internos ──────────────────
    // Los 4 estados internos (0-3) corresponden 1:1 con las 4 fases visibles
    readonly property int faseVisual: Math.max(0, backend.estadoPreparacion)

    readonly property var nombreFase: [
        qsTranslate("Main", "Verificación"),
        qsTranslate("Main", "Llenado"),
        qsTranslate("Main", "Acondicionamiento"),
        qsTranslate("Main", "Listo")
    ]

    // ════════════════════════════════════════════════════════════════════════════
    // LAYOUT PRINCIPAL
    // ════════════════════════════════════════════════════════════════════════════

    // ── Panel izquierdo — estado y progreso ───────────────────────────────────
    Column {
        id: panelIzq
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.17
        anchors.left: parent.left
        anchors.leftMargin: appWindow.width * 0.05
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.13
        width: appWindow.width * 0.54
        spacing: appWindow.height * 0.025

        // Título
        Text {
            text: qsTranslate("Main", "PREPARACIÓN DEL TANQUE")
            font.pixelSize: appWindow.height * 0.055
            font.bold: true
            color: "black"
        }

        // Indicador de 4 fases
        Row {
            width: parent.width
            spacing: 0

            Repeater {
                model: 4
                delegate: Item {
                    width: panelIzq.width / 4
                    height: appWindow.height * 0.090

                    // Línea conectora entre fases
                    Rectangle {
                        visible: index < 3
                        anchors.left: parent.horizontalCenter
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 3
                        color: index < root.faseVisual ? "#4CAF50" : "#CCCCCC"
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Rectangle {
                            id: bola
                            anchors.horizontalCenter: parent.horizontalCenter
                            width:  appWindow.height * 0.065
                            height: appWindow.height * 0.065
                            radius: height / 2
                            color: index < root.faseVisual  ? "#4CAF50"
                                 : index === root.faseVisual ? "#6E9C9C"
                                 :                             "#CCCCCC"
                            Behavior on color { ColorAnimation { duration: 300 } }

                            Text {
                                anchors.centerIn: parent
                                text: index < root.faseVisual ? "✓" : (index + 1)
                                font.pixelSize: parent.height * 0.42
                                font.bold: true
                                color: index <= root.faseVisual ? "white" : "#888888"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.nombreFase[index]
                            font.pixelSize: appWindow.height * 0.024
                            color: index === root.faseVisual ? "#2a6060" : "#888888"
                            font.bold: index === root.faseVisual
                        }
                    }
                }
            }
        }

        // Barra de progreso global
        Item {
            width: parent.width
            height: appWindow.height * 0.040

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#DDDDDD"

                Rectangle {
                    width: parent.width * backend.progresoPreparacion
                    height: parent.height
                    radius: parent.radius
                    color: "#6E9C9C"
                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Math.round(backend.progresoPreparacion * 100) + " %"
                font.pixelSize: parent.height * 0.55
                font.bold: true
                color: "black"
            }
        }

        // Tarjeta con tarea actual y descripción
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.34
            color: "#6E9C9C"
            radius: 14

            Column {
                anchors.fill: parent
                anchors.margins: appWindow.height * 0.030
                spacing: appWindow.height * 0.018

                Text {
                    text: backend.textoTareaPreparacion
                    font.pixelSize: appWindow.height * 0.040
                    font.bold: true
                    color: "black"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    Behavior on text { }
                }

                Rectangle { width: parent.width; height: 2; color: Qt.rgba(0,0,0,0.15) }

                Text {
                    width: parent.width
                    height: parent.height - parent.spacing - parent.children[0].implicitHeight - parent.children[1].height - parent.spacing
                    text: backend.textoDetallePreparacion
                    font.pixelSize: appWindow.height * 0.029
                    minimumPixelSize: appWindow.height * 0.018
                    fontSizeMode: Text.Fit
                    color: "#1a1a1a"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.20
                    clip: true
                }
            }
        }
    }

    // ── Panel derecho — lecturas en tiempo real ───────────────────────────────
    Column {
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.17
        anchors.right: parent.right
        anchors.rightMargin: appWindow.width * 0.04
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.13
        width: appWindow.width * 0.34
        spacing: appWindow.height * 0.025

        Text {
            text: qsTranslate("Main", "Lecturas en tiempo real")
            font.pixelSize: appWindow.height * 0.030
            font.bold: true
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Temperatura: medido → objetivo
        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: qsTranslate("Main", "Temperatura")
            textoValor: (backend.sensorSerialValido ? appWindow.tempMostrada(backend.sensorTem).toFixed(1) : "---") + " → " + appWindow.tempMostrada(backend.setpointTem).toFixed(1) + " °" + appWindow.unidadTemperatura
        }

        // pH: medido → objetivo (en estados 0-1 el sensor aún no toca el líquido)
        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: "pH"
            textoValor: (backend.estadoPreparacion <= 1 && !backend.modoSimulacion)
                        ? "--- → " + backend.setpointPH.toFixed(1)
                        : (backend.sensorSerialValido ? backend.sensorPH.toFixed(2) : "---") + " → " + backend.setpointPH.toFixed(1)
        }

        // Tiempo transcurrido en la fase actual → tiempo estimado al setpoint (modelo FOPDT).
        // Formato "sensor → setpoint" igual que las demás lecturas.
        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: qsTranslate("Main", "Tiempo (transcurrido → estimado)")
            textoValor: {
                function fmt(s, aprox) {
                    if (s < 0) return "—"
                    var p = aprox ? "~" : ""
                    if (s < 3600) return p + Math.round(s / 60) + " min"
                    return p + Math.floor(s / 3600) + "h " +
                           ("0" + Math.floor((s % 3600) / 60)).slice(-2) + "m"
                }
                return fmt(backend.segFasePreparacion, false) + "  →  " +
                       fmt(backend.etaCalentamientoSeg, true)
            }
        }

        // Nivel: gauge de tanque vertical (fill por %, lectura robusta en mm)
        Item {
            width: parent.width
            height: appWindow.height * 0.24
            visible: backend.estadoPreparacion <= 2

            Row {
                anchors.centerIn: parent
                spacing: appWindow.width * 0.025

                // Tanque vertical
                Rectangle {
                    id: tanqueNivel
                    width: appWindow.width * 0.055
                    height: appWindow.height * 0.22
                    radius: 6
                    color: "#E3ECEC"
                    border.color: "#6E9C9C"
                    border.width: 2

                    property real nivelPct: backend.sensorNivelValido
                        ? Math.max(0, Math.min(100, backend.sensorNivel)) : 0

                    // Relleno de líquido
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 3
                        height: (parent.height - 6) * tanqueNivel.nivelPct / 100
                        radius: 4
                        color: tanqueNivel.nivelPct > 90 ? "#f0a63f" : "#3fb0d0"
                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                    // Marcas 25/50/75 %
                    Repeater {
                        model: [25, 50, 75]
                        delegate: Rectangle {
                            width: parent.width * 0.5
                            height: 1
                            color: "#9bb3b3"
                            x: parent.width * 0.25
                            y: (parent.height - 6) * (1 - modelData / 100) + 3
                        }
                    }
                }

                // Lecturas
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: appWindow.height * 0.006

                    Text {
                        text: qsTranslate("Main", "Nivel")
                        font.pixelSize: appWindow.height * 0.026
                        color: "#555555"
                    }
                    Row {
                        spacing: appWindow.width * 0.008
                        Text {
                            text: backend.textoNivel
                            font.pixelSize: appWindow.height * 0.048
                            font.bold: true
                            color: "black"
                        }
                        // Puntito de confianza del seguidor de agua: verde = siguiendo, naranja = extrapolando
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: backend.sensorNivelValido && !backend.usaFlotador
                            text: "●"
                            font.pixelSize: appWindow.height * 0.032
                            color: backend.seguidorNivelHit ? "#1a9c1a" : "#f0a63f"
                        }
                    }
                    Text {
                        visible: !backend.usaFlotador
                        text: (backend.distanciaNivelMm >= 0 ? Math.round(backend.distanciaNivelMm) : "---") + " mm"
                        font.pixelSize: appWindow.height * 0.026
                        color: "#777777"
                    }
                }
            }
        }
    }

    // ── Botón Cancelar/Atrás — disponible durante toda la preparación ─────────
    // (oculto solo cuando hay un popup modal encima: escalación o "tanque listo")
    Rectangle {
        visible: backend.estadoPreparacion <= 2 && !backend.alertaEscalacion && !backend.preparacionCompletada
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: appWindow.width * 0.05
        anchors.bottomMargin: appWindow.height * 0.03
        width: appWindow.width * 0.12
        height: appWindow.height * 0.10
        radius: height / 2
        color: maAtras.pressed ? "#cc1e1e" : "#FF2D2D"
        z: 160

        Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: maAtras
            anchors.fill: parent
            onClicked: root.mostrarConfirmCancelar = true   // pedir confirmación antes de abandonar
        }
    }

    // ── Botón "Re-sync nivel" — solo durante verificación/llenado (fases 0-1) ──
    // Abre un popup con la lectura en vivo del seguidor de agua; el operador decide si
    // está bien o re-sincroniza (útil si el arranque se enganchó a un reflejo equivocado).
    Rectangle {
        visible: backend.estadoPreparacion >= 0 && backend.estadoPreparacion <= 1
                 && !backend.preparacionCompletada && !root.mostrarConfirmCancelar
                 && !backend.usaFlotador   // el re-sync es del radar
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: appWindow.width * 0.05
        anchors.bottomMargin: appWindow.height * 0.03
        width: appWindow.width * 0.20
        height: appWindow.height * 0.10
        radius: height / 2
        color: maResync.pressed ? "#1f6f86" : "#2E90AE"
        z: 160

        Row {
            anchors.centerIn: parent
            spacing: appWindow.width * 0.010
            Text { text: "⟳"; color: "white"; font.pixelSize: parent.parent.height * 0.50; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: qsTranslate("Main", "Re-sync nivel")
                color: "white"; font.pixelSize: parent.parent.height * 0.26; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea { id: maResync; anchors.fill: parent; onClicked: root.mostrarResync = true }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP — Re-sincronizar el nivel (seguidor de agua)
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 215
        visible: root.mostrarResync
        MouseArea { anchors.fill: parent; hoverEnabled: true }   // bloquea toques detrás

        Rectangle {
            width: parent.width * 0.62
            height: parent.height * 0.50
            anchors.centerIn: parent
            color: Qt.rgba(0.90, 0.96, 0.98, 0.98)
            radius: 20

            Column {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.08
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.width * 0.08
                anchors.rightMargin: parent.width * 0.08
                spacing: appWindow.height * 0.022

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "Verificar el nivel medido")
                    font.pixelSize: appWindow.height * 0.042
                    font.bold: true
                    color: "#1a5070"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                // Lectura en vivo del seguidor de agua
                Text {
                    width: parent.width
                    text: (backend.sensorNivelValido ? backend.sensorNivel.toFixed(1) : "---") + " %   ·   "
                          + (backend.distanciaNivelMm >= 0 ? Math.round(backend.distanciaNivelMm) : "---") + " mm"
                    font.pixelSize: appWindow.height * 0.050
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    text: backend.seguidorNivelHit
                          ? qsTranslate("Main", "● Siguiendo el agua")
                          : qsTranslate("Main", "○ Extrapolando (sin eco claro)")
                    font.pixelSize: appWindow.height * 0.028
                    color: backend.seguidorNivelHit ? "#1a7d1a" : "#b07a1a"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "Si el valor no coincide con el tanque real (p. ej. marca lleno estando vacío), re-sincroniza: el seguidor volverá a buscar el nivel durante unos segundos.")
                    font.pixelSize: appWindow.height * 0.026
                    color: "#333333"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.22
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.04

                    Rectangle {
                        width: appWindow.width * 0.20
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: maResyncOk.pressed ? "#3a7d3a" : "#4CAF50"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Está bien"); font.pixelSize: parent.height * 0.28; font.bold: true; color: "white" }
                        MouseArea { id: maResyncOk; anchors.fill: parent; onClicked: root.mostrarResync = false }
                    }
                    Rectangle {
                        width: appWindow.width * 0.22
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: maResyncGo.pressed ? "#1f6f86" : "#2E90AE"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Re-sincronizar"); font.pixelSize: parent.height * 0.26; font.bold: true; color: "white" }
                        MouseArea {
                            id: maResyncGo
                            anchors.fill: parent
                            onClicked: {
                                backend.resyncNivel()
                                root.mostrarResync = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Aviso: sensores desconectados / sobre-temperatura / bombas sin efecto ──
    Rectangle {
        id: bannerAviso
        readonly property bool sensoresCaidos: backend.estadoPreparacion === 0
                                            && (!backend.sensorSerialValido || !backend.sensorNivelValido)
        readonly property bool soloDivergencia: backend.alertaDivergenciaTemp
                                            && !backend.alertaSobreTemp && !backend.alertaCruceCero
                                            && !backend.alertaBombas && !sensoresCaidos
        visible: backend.alertaSobreTemp || backend.alertaCruceCero || backend.alertaBombas
                 || sensoresCaidos || backend.alertaDivergenciaTemp
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.03
        width: appWindow.width * 0.60
        height: appWindow.height * 0.09
        radius: height / 2
        color: soloDivergencia ? "#F59E0B" : "#FF4444"   // ámbar si solo es divergencia (informativa)
        z: 150
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.92
            text: backend.alertaSobreTemp
                  ? qsTranslate("Main", "⚠ Sobre-temperatura: calentamiento cortado")
                  : backend.alertaCruceCero
                  ? qsTranslate("Main", "⚠ Sin señal de cruce por cero: calentamiento cortado — revise el detector de AC")
                  : backend.alertaBombas
                    ? qsTranslate("Main", "⚠ Bombas activas sin cambio de nivel — verifica las bombas")
                    : bannerAviso.sensoresCaidos
                      ? qsTranslate("Main", "⚠ Sensores sin respuesta — revise las conexiones")
                      : qsTranslate("Main", "⚠ Diferencia entre sensores de temperatura — verifica que ambos estén sumergidos")
            font.pixelSize: parent.height * 0.28
            font.bold: true
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP — Escalación (demasiado tiempo en acondicionamiento)
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 200
        visible: backend.alertaEscalacion
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.60
            height: parent.height * 0.50
            anchors.centerIn: parent
            color: Qt.rgba(0.97, 0.95, 0.85, 0.97)
            radius: 20

            Column {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.width * 0.08
                anchors.rightMargin: parent.width * 0.08
                spacing: appWindow.height * 0.025

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "El ajuste está tomando más tiempo del esperado")
                    font.pixelSize: appWindow.height * 0.036
                    font.bold: true
                    color: "#7a4400"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "El sistema lleva más de 2 minutos intentando alcanzar las condiciones objetivo sin lograrlo. Puede deberse a una composición muy alejada del valor deseado.\n\nSe recomienda considerar un drenaje parcial y reposición con líquido fresco antes de continuar.")
                    font.pixelSize: appWindow.height * 0.027
                    color: "#333333"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.22
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.04

                    Rectangle {
                        width: appWindow.width * 0.16
                        height: appWindow.height * 0.088
                        radius: height / 2
                        color: maContinuar.pressed ? "#6b42b5" : "#8b5cf6"
                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Continuar\nde todas formas")
                            font.pixelSize: parent.height * 0.28
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: maContinuar
                            anchors.fill: parent
                            onClicked: backend.continuarDesdeEscalacion()
                        }
                    }

                    Rectangle {
                        width: appWindow.width * 0.16
                        height: appWindow.height * 0.088
                        radius: height / 2
                        color: maDetener.pressed ? "#cc1e1e" : "#FF2D2D"
                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Detener\npreparación")
                            font.pixelSize: parent.height * 0.28
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: maDetener
                            anchors.fill: parent
                            onClicked: {
                                appWindow.procesoListoParaIniciar = false
                                backend.cancelarPreparacion()
                                appWindow.estadoActual = "pantalla_7"
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP — Tanque listo: introducir organismo
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 200
        visible: backend.preparacionCompletada
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.58
            height: parent.height * 0.50
            anchors.centerIn: parent
            color: Qt.rgba(0.88, 0.97, 0.88, 0.97)
            radius: 20

            Column {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.width * 0.08
                anchors.rightMargin: parent.width * 0.08
                spacing: appWindow.height * 0.025

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "El tanque está listo")
                    font.pixelSize: appWindow.height * 0.050
                    font.bold: true
                    color: "#1a5c1a"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "pH: %1   |   Temperatura: %2 °%4   |   Nivel: %3")
                              .arg(backend.sensorSerialValido ? backend.sensorPH.toFixed(2) : "---")
                              .arg(backend.sensorSerialValido ? appWindow.tempMostrada(backend.sensorTem).toFixed(1) : "---")
                              .arg(backend.textoNivel)
                              .arg(appWindow.unidadTemperatura)
                    font.pixelSize: appWindow.height * 0.030
                    color: "#1a5c1a"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "Introduzca el organismo en el tanque y confirme para iniciar el proceso de cultivo.")
                    font.pixelSize: appWindow.height * 0.028
                    color: "#333333"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.28
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.03

                    Rectangle {
                        width: appWindow.width * 0.26
                        height: appWindow.height * 0.090
                        radius: height / 2
                        color: maConfirmar.pressed ? "#6b42b5" : "#8b5cf6"

                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Organismo introducido — Iniciar proceso")
                            font.pixelSize: parent.height * 0.28
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.88
                            wrapMode: Text.WordWrap
                        }
                        MouseArea {
                            id: maConfirmar
                            anchors.fill: parent
                            onClicked: {
                                appWindow.procesoListoParaIniciar = true
                                appWindow.estadoActual = "pantalla_procesos"
                            }
                        }
                    }

                    Rectangle {
                        width: appWindow.width * 0.16
                        height: appWindow.height * 0.090
                        radius: height / 2
                        color: maCancelarListo.pressed ? "#cc1e1e" : "#FF2D2D"
                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Cancelar")
                            font.pixelSize: parent.height * 0.30
                            font.bold: true
                            color: "black"
                        }
                        MouseArea {
                            id: maCancelarListo
                            anchors.fill: parent
                            onClicked: {
                                appWindow.procesoListoParaIniciar = false
                                backend.cancelarPreparacion()
                                appWindow.estadoActual = "pantalla_7"
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP — Confirmar cancelación de la preparación (botón ↶)
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 210
        visible: root.mostrarConfirmCancelar
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.58
            height: parent.height * 0.42
            anchors.centerIn: parent
            color: Qt.rgba(0.92, 0.92, 0.92, 0.97)
            radius: 20

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.86
                spacing: appWindow.height * 0.045

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "¿Cancelar la preparación en curso? Se detiene todo de forma segura (mantas y bombas apagadas).")
                    font.pixelSize: appWindow.height * 0.032
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.04

                    Rectangle {
                        width: appWindow.width * 0.18
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: maConfirmCancelarSi.pressed ? "#a03030" : "#D64545"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Sí, cancelar"); font.pixelSize: parent.height * 0.28; font.bold: true; color: "white" }
                        MouseArea {
                            id: maConfirmCancelarSi
                            anchors.fill: parent
                            onClicked: {
                                root.mostrarConfirmCancelar = false
                                appWindow.procesoListoParaIniciar = false
                                backend.cancelarPreparacion()
                                appWindow.estadoActual = "pantalla_7"
                            }
                        }
                    }
                    Rectangle {
                        width: appWindow.width * 0.18
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: maConfirmCancelarNo.pressed ? "#5a8282" : "#6E9C9C"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Continuar"); font.pixelSize: parent.height * 0.28; font.bold: true; color: "white" }
                        MouseArea { id: maConfirmCancelarNo; anchors.fill: parent; onClicked: root.mostrarConfirmCancelar = false }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP — ¿Tanque vacío? (antes de iniciar el llenado)
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 220
        visible: backend.esperandoConfirmacionVacio
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.62
            height: parent.height * 0.46
            anchors.centerIn: parent
            color: Qt.rgba(0.90, 0.94, 0.98, 0.98)
            radius: 20

            Column {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.width * 0.08
                anchors.rightMargin: parent.width * 0.08
                spacing: appWindow.height * 0.028

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "¿El tanque está totalmente vacío?")
                    font.pixelSize: appWindow.height * 0.044
                    font.bold: true
                    color: "#1a5070"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "Si está vacío, se llenará a ciegas por 5 minutos antes de medir el nivel (evita lecturas erróneas por falta de líquido). Si ya tiene líquido, se mide de inmediato.")
                    font.pixelSize: appWindow.height * 0.027
                    color: "#333333"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.22
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.04

                    Rectangle {
                        width: appWindow.width * 0.22
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: maVacioSi.pressed ? "#3a7d3a" : "#4CAF50"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Sí, está vacío"); font.pixelSize: parent.height * 0.28; font.bold: true; color: "white" }
                        MouseArea { id: maVacioSi; anchors.fill: parent; onClicked: backend.confirmarTanqueVacio(true) }
                    }
                    Rectangle {
                        width: appWindow.width * 0.22
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: maVacioNo.pressed ? "#5a8282" : "#6E9C9C"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "No, ya tiene líquido"); font.pixelSize: parent.height * 0.26; font.bold: true; color: "white" }
                        MouseArea { id: maVacioNo; anchors.fill: parent; onClicked: backend.confirmarTanqueVacio(false) }
                    }
                }
            }
        }
    }
}
