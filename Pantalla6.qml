import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_6"

    property string campoActivo: ""
    property string entradaTemporal: ""

    property bool mostrarPopupGuardar: false
    property bool mostrarPopupAdvertencia: false
    property bool mostrarPopupConfirmacion: false

    property bool tempConfigurada: false
    property bool phConfigurado: false
    property bool aguaConfigurada: false
    property bool luzConfigurada: false
    property bool tiempoConfigurado: false

    function aplicarValor(campo, entrada) {
        let v = parseFloat(entrada)
        if (isNaN(v)) return
        if      (campo === "Tem")     { let mn = appWindow.unidadTemperatura === "C" ? 20 : 68; let mx = appWindow.unidadTemperatura === "C" ? 100 : 212; backend.setpointTem = Math.max(mn, Math.min(mx, v)); root.tempConfigurada = true }
        else if (campo === "pH")      { backend.setpointPH   = Math.max(1,  Math.min(14,  v)); root.phConfigurado   = true }
        else if (campo === "Agua")    { backend.setpointAgua = Math.max(30, Math.min(100, v)); root.aguaConfigurada = true }
        else if (campo === "Luz")     { backend.setpointLuz  = Math.max(0,  Math.min(100, v)); root.luzConfigurada  = true }
        else if (campo === "Semanas") { appWindow.var_deseada_tiempo_semanas = Math.max(0, Math.min(52, v)); root.tiempoConfigurado = true }
        else if (campo === "Dias")    { appWindow.var_deseada_tiempo_dias    = Math.max(0, Math.min(6,  v)); root.tiempoConfigurado = true }
        else if (campo === "Horas")   { appWindow.var_deseada_tiempo_horas   = Math.max(0, Math.min(23, v)); root.tiempoConfigurado = true }
        else if (campo === "Minutos") { appWindow.var_deseada_tiempo_minutos = Math.max(0, Math.min(59, v)); root.tiempoConfigurado = true }
        appWindow.var_deseada_tiempo_total_horas = (appWindow.var_deseada_tiempo_semanas * 168) + (appWindow.var_deseada_tiempo_dias * 24) + appWindow.var_deseada_tiempo_horas + (appWindow.var_deseada_tiempo_minutos / 60)
    }

    focus: visible
    Keys.onPressed: (event) => {
        if (root.campoActivo !== "" && !root.mostrarPopupGuardar && !root.mostrarPopupAdvertencia && !root.mostrarPopupConfirmacion) {
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                let digito = (event.key - Qt.Key_0).toString()
                root.entradaTemporal = (root.entradaTemporal === "0") ? digito : root.entradaTemporal + digito
                event.accepted = true
            } else if (event.key === Qt.Key_Period) {
                if (root.entradaTemporal.indexOf(".") === -1) {
                    root.entradaTemporal += (root.entradaTemporal === "" ? "0." : ".")
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (root.entradaTemporal.length > 0) {
                    root.entradaTemporal = root.entradaTemporal.substring(0, root.entradaTemporal.length - 1)
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                aplicarValor(root.campoActivo, root.entradaTemporal)
                root.campoActivo = ""; root.entradaTemporal = ""; event.accepted = true
            }
        }
    }

    Column {
        id: columnaBarrasConfiguracion
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.05
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.22
        spacing: parent.height * 0.02

        BarraInputConfig {
            idCampo: "Tem"
            campoActivo: root.campoActivo
            textoEtiqueta: qsTranslate("Main", "Temperatura:")
            valorMostrado: (root.campoActivo === "Tem" ? root.entradaTemporal + "|" : backend.setpointTem) + " °" + appWindow.unidadTemperatura
            onBarraClicada: { root.campoActivo = "Tem"; root.entradaTemporal = ""; root.forceActiveFocus() }
        }
        BarraInputConfig {
            idCampo: "pH"
            campoActivo: root.campoActivo
            textoEtiqueta: qsTranslate("Main", "Nivel de pH:")
            valorMostrado: (root.campoActivo === "pH" ? root.entradaTemporal + "|" : backend.setpointPH)
            onBarraClicada: { root.campoActivo = "pH"; root.entradaTemporal = ""; root.forceActiveFocus() }
        }
        BarraInputConfig {
            idCampo: "Agua"
            campoActivo: root.campoActivo
            textoEtiqueta: qsTranslate("Main", "Nivel de agua:")
            valorMostrado: (root.campoActivo === "Agua" ? root.entradaTemporal + "|" : backend.setpointAgua) + " %"
            onBarraClicada: { root.campoActivo = "Agua"; root.entradaTemporal = ""; root.forceActiveFocus() }
        }
        BarraInputConfig {
            idCampo: "Luz"
            campoActivo: root.campoActivo
            textoEtiqueta: qsTranslate("Main", "Nivel de luz:")
            valorMostrado: (root.campoActivo === "Luz" ? root.entradaTemporal + "|" : backend.setpointLuz) + " %"
            onBarraClicada: { root.campoActivo = "Luz"; root.entradaTemporal = ""; root.forceActiveFocus() }
        }

        // Tiempos (Semanas/Días)
        Rectangle {
            width: appWindow.width * 0.45
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2
            Row {
                anchors.fill: parent
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: parent.height * 0.8
                        color: root.campoActivo === "Semanas" ? "#A5D6A7" : "transparent"
                        radius: height / 2
                    }
                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Main", "Semanas: ") + (root.campoActivo === "Semanas" ? root.entradaTemporal + "|" : appWindow.var_deseada_tiempo_semanas)
                        font.pixelSize: parent.height * 0.35
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.campoActivo = "Semanas"; root.entradaTemporal = ""; root.forceActiveFocus() }
                    }
                }
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: parent.height * 0.8
                        color: root.campoActivo === "Dias" ? "#A5D6A7" : "transparent"
                        radius: height / 2
                    }
                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Main", "Días: ") + (root.campoActivo === "Dias" ? root.entradaTemporal + "|" : appWindow.var_deseada_tiempo_dias)
                        font.pixelSize: parent.height * 0.35
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.campoActivo = "Dias"; root.entradaTemporal = ""; root.forceActiveFocus() }
                    }
                }
            }
        }

        // Tiempos (Horas/Minutos)
        Rectangle {
            width: appWindow.width * 0.45
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2
            Row {
                anchors.fill: parent
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: parent.height * 0.8
                        color: root.campoActivo === "Horas" ? "#A5D6A7" : "transparent"
                        radius: height / 2
                    }
                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Main", "Horas: ") + (root.campoActivo === "Horas" ? root.entradaTemporal + "|" : appWindow.var_deseada_tiempo_horas)
                        font.pixelSize: parent.height * 0.35
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.campoActivo = "Horas"; root.entradaTemporal = ""; root.forceActiveFocus() }
                    }
                }
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: parent.height * 0.8
                        color: root.campoActivo === "Minutos" ? "#A5D6A7" : "transparent"
                        radius: height / 2
                    }
                    Text {
                        anchors.centerIn: parent
                        text: qsTranslate("Main", "Minutos: ") + (root.campoActivo === "Minutos" ? root.entradaTemporal + "|" : appWindow.var_deseada_tiempo_minutos)
                        font.pixelSize: parent.height * 0.35
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.campoActivo = "Minutos"; root.entradaTemporal = ""; root.forceActiveFocus() }
                    }
                }
            }
        }
    }

    Image {
        source: "Hongo_4.png"
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.08
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: appWindow.height * 0.03
        width: parent.width * 0.30
        fillMode: Image.PreserveAspectFit
        z: 1
    }

    // --- TECLADO NUMÉRICO 4x4 ---
    TecladoNumerico {
        id: tecladoNumerico
        z: 10
        visible: root.campoActivo !== ""
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.08
        anchors.verticalCenter: columnaBarrasConfiguracion.verticalCenter
        width: parent.width * 0.35
        height: parent.height * 0.45
        onDigitoPresionado: function(d) { root.entradaTemporal = root.entradaTemporal === "0" ? d : root.entradaTemporal + d }
        onPuntoPresionado:  { if (root.entradaTemporal.indexOf(".") === -1) root.entradaTemporal += root.entradaTemporal === "" ? "0." : "." }
        onBorrarPresionado: { if (root.entradaTemporal.length > 0) root.entradaTemporal = root.entradaTemporal.slice(0, -1) }
        onOkPresionado: {
            aplicarValor(root.campoActivo, root.entradaTemporal)
            root.campoActivo = "";
            root.entradaTemporal = "";
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: parent.width * 0.05
        width: parent.width * 0.20
        height: parent.height * 0.10
        color: areaOkPantalla6.pressed ? "#6b42b5" : "#8b5cf6"
        radius: height / 2

        Text {
            anchors.centerIn: parent
            text: qsTranslate("Main", "Okay")
            color: "black"
            font.pixelSize: parent.height * 0.40
            font.bold: true
        }
        MouseArea {
            id: areaOkPantalla6
            anchors.fill: parent
            onClicked: {
                if (root.campoActivo !== "" && root.entradaTemporal !== "") {
                    aplicarValor(root.campoActivo, root.entradaTemporal)
                    root.campoActivo = "";
                    root.entradaTemporal = "";
                }

                appWindow.var_deseada_tiempo_total_horas = (appWindow.var_deseada_tiempo_semanas * 168) + (appWindow.var_deseada_tiempo_dias * 24) + appWindow.var_deseada_tiempo_horas + (appWindow.var_deseada_tiempo_minutos / 60);

                if (root.tiempoConfigurado && appWindow.var_deseada_tiempo_total_horas < 6) {
                    appWindow.var_deseada_tiempo_horas = 6;
                    appWindow.var_deseada_tiempo_minutos = 0;
                    appWindow.var_deseada_tiempo_dias = 0;
                    appWindow.var_deseada_tiempo_semanas = 0;
                    appWindow.var_deseada_tiempo_total_horas = 6;
                }
                if (appWindow.var_deseada_tiempo_total_horas > 583) {
                    appWindow.var_deseada_tiempo_total_horas = 583;
                }

                if (root.tempConfigurada && root.phConfigurado && root.aguaConfigurada && root.luzConfigurada && root.tiempoConfigurado) {
                    if (appWindow.omitirPedirNombre) {
                        root.mostrarPopupConfirmacion = true;
                    } else {
                        root.mostrarPopupGuardar = true;
                    }
                } else {
                    root.mostrarPopupAdvertencia = true;
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
        color: areaAtrasPantalla6.pressed ? "#cc1e1e" : "#FF2D2D"
        radius: height / 2

        Text {
            anchors.centerIn: parent
            text: "↶"
            color: "black"
            font.pixelSize: parent.height * 0.70
            font.bold: true
        }
        MouseArea {
            id: areaAtrasPantalla6
            anchors.fill: parent
            onClicked: {
                appWindow.limpiarDatos(false)
                appWindow.omitirPedirNombre = false
                appWindow.estadoActual = appWindow.estadoPrevioPantalla6
            }
        }
    }

    PopupIngresoNombre {
        id: popupGuardado6
        visible: root.mostrarPopupGuardar
        tituloPopup: qsTranslate("Main", "Ingrese nombre del experimento")
        nombrePorDefecto: ""
        onAceptado: function(name) {
            var nombreFinal = name.trim();
            if (nombreFinal === "") {
                var d = new Date();
                nombreFinal = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear() + "_" + ("0" + d.getHours()).slice(-2) + "_" + ("0" + d.getMinutes()).slice(-2);
            }
            appWindow.var_nombre_experimento = nombreFinal;
            appWindow.var_nombre_proyecto = qsTranslate("Main", "Experimento Nuevo");
            root.mostrarPopupGuardar = false;
            root.mostrarPopupConfirmacion = true;
        }
        onCancelado: {
            root.mostrarPopupGuardar = false;
        }
    }

    PopupConfirmarProceso {
        id: popupConfirmacion6
        visible: root.mostrarPopupConfirmacion
        nombreProyecto: appWindow.var_nombre_proyecto
        nombreExperimento: appWindow.var_nombre_experimento
        temp: backend.setpointTem
        ph: backend.setpointPH
        agua: backend.setpointAgua
        luz: backend.setpointLuz
        tiempoSemanas: appWindow.var_deseada_tiempo_semanas
        tiempoDias: appWindow.var_deseada_tiempo_dias
        tiempoHoras: appWindow.var_deseada_tiempo_horas
        tiempoMinutos: appWindow.var_deseada_tiempo_minutos
        tiempoTotal: appWindow.var_deseada_tiempo_total_horas
        unidadTemperatura: appWindow.unidadTemperatura

        onConfirmado: {
            root.mostrarPopupConfirmacion = false;
            var d = new Date();
            var cadenaFecha = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear();

            appWindow.registro_experimentos.append({
                "proyecto": appWindow.var_nombre_proyecto,
                "experimento": appWindow.var_nombre_experimento,
                "fecha": cadenaFecha,
                "tiempo": "0.0 / " + appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " hrs",
                "peso": "N/A",
                "seleccionado": false
            });
            appWindow.estadoPrevioPantalla7 = "pantalla_6"
            appWindow.estadoActual = "pantalla_7"
        }
        onCancelado: {
            root.mostrarPopupConfirmacion = false;
        }
    }

    Item {
        id: overlayAdvertencia
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupAdvertencia

        MouseArea {
            anchors.fill: parent
        }
        Rectangle {
            width: parent.width * 0.75
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.7, 0.7, 0.7, 0.9)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Por favor, ingrese todos los parámetros")
                font.pixelSize: parent.height * 0.08
                font.bold: true
                color: "black"
            }
            Image {
                source: "Alerta.png"
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.03
                height: parent.height * 0.35
                fillMode: Image.PreserveAspectFit
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: parent.height * 0.10
                width: appWindow.width * 0.20
                height: appWindow.height * 0.10
                color: areaOkAdvertencia.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Okay")
                    color: "black"
                    font.pixelSize: parent.height * 0.40
                    font.bold: true
                }
                MouseArea {
                    id: areaOkAdvertencia
                    anchors.fill: parent
                    onClicked: root.mostrarPopupAdvertencia = false
                }
            }
        }
    }
}
