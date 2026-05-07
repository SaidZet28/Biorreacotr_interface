import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_proyectos_guardados"

    property bool mostrarPopupGuardar: false
    property bool mostrarPopupConfirmacion: false

    property bool mostrarPopupOpciones: false
    property bool mostrarPopupBorrarGuardado: false
    property bool mostrarPopupEdicionProyecto: false
    property bool mostrarPopupConfirmarEdicion: false

    property int indexEditando: -1
    QtObject {
        id: datosEdicion
        property string nombre: ""
        property real temp: 0.0
        property real ph: 0.0
        property real agua: 0.0
        property real luz: 0.0
        property string tiempo: ""
    }

    property string campoEditActivo: ""
    property string entradaEditTemporal: ""

    Column {
        id: colTituloProyectos
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.16
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: appWindow.height * 0.01

        Text {
            text: qsTranslate("Main", "Proyectos Guardados")
            font.pixelSize: appWindow.height * 0.06
            font.bold: true
            color: "black"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Item {
        anchors.top: colTituloProyectos.bottom
        anchors.topMargin: appWindow.height * 0.05
        anchors.bottom: botonAtras9.top
        anchors.bottomMargin: appWindow.height * 0.02
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: appWindow.width * 0.05

        Rectangle {
            id: botonCarruselIzq
            width: appWindow.width * 0.04
            height: appWindow.height * 0.15
            radius: width / 2
            color: carruselGuardados.currentIndex > 0 ? "#A0A0A0" : "#D0D0D0"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.centerIn: parent; text: "◀"; font.pixelSize: parent.width * 0.50; color: "#333333" }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (carruselGuardados.currentIndex > 0) {
                        carruselGuardados.currentIndex--;
                        carruselGuardados.positionViewAtIndex(carruselGuardados.currentIndex, ListView.Beginning);
                    }
                }
            }
        }

        ListView {
            id: carruselGuardados
            anchors.left: botonCarruselIzq.right
            anchors.right: botonCarruselDer.left
            anchors.leftMargin: appWindow.width * 0.02
            anchors.rightMargin: appWindow.width * 0.02
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height * 0.85
            orientation: ListView.Horizontal
            spacing: appWindow.width * 0.02
            clip: true
            interactive: false
            snapMode: ListView.SnapToItem

            Behavior on contentX { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

            model: appWindow.datos_guardados
            delegate: Rectangle {
                width: (carruselGuardados.width - (carruselGuardados.spacing * 2)) / 3
                height: carruselGuardados.height
                radius: 20
                color: index % 2 === 0 ? "#8DBB5A" : "#6E9C9C"

                Image {
                    source: "Engrane.png"
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: parent.width * 0.05
                    width: parent.width * 0.12
                    height: width
                    fillMode: Image.PreserveAspectFit
                    z: 10
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.indexEditando = index;
                            root.mostrarPopupOpciones = true;
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: parent.width * 0.08
                    spacing: parent.height * 0.015
                    Text { text: qsTranslate("Main", "Proyecto %1:").arg(index + 1); font.pixelSize: parent.height * 0.08; font.bold: true; color: "black" }
                    Text { text: model.nombre; font.pixelSize: parent.height * 0.07; font.bold: true; color: "black"; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                    Item { height: parent.height * 0.01; width: 1 }
                    Text {
                        text: qsTranslate("Main", "Temp °%1: %2").arg(appWindow.unidadTemperatura).arg(appWindow.unidadTemperatura === "C" ? model.temp : (model.temp * 9/5 + 32).toFixed(1))
                        font.pixelSize: parent.height * 0.06; font.bold: true; color: "black"
                    }
                    Text { text: qsTranslate("Main", "Nivel pH: %1").arg(model.ph); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                    Text { text: qsTranslate("Main", "Nivel agua: %1 %").arg(model.agua); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                    Text { text: qsTranslate("Main", "Nivel luz: %1 %").arg(model.luz); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                    Text { text: qsTranslate("Main", "Tiempo: %1 hrs").arg(model.tiempo); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        appWindow.limpiarDatos(false);
                        appWindow.var_nombre_proyecto = model.nombre;
                        appWindow.var_deseada_Tem = (appWindow.unidadTemperatura === "C" ? model.temp : (model.temp * 9/5 + 32));
                        appWindow.var_deseada_pH = model.ph;
                        appWindow.var_deseada_Agua = model.agua;
                        appWindow.var_deseada_Luz = model.luz;
                        let total = parseFloat(model.tiempo);
                        appWindow.var_deseada_tiempo_total_horas = total;
                        appWindow.var_deseada_tiempo_semanas = Math.floor(total / 168);
                        let rem = total % 168;
                        appWindow.var_deseada_tiempo_dias = Math.floor(rem / 24);
                        rem = rem % 24;
                        appWindow.var_deseada_tiempo_horas = Math.floor(rem);
                        appWindow.var_deseada_tiempo_minutos = Math.round((rem - appWindow.var_deseada_tiempo_horas) * 60);
                        popupGuardar9.nombrePorDefecto = "";
                        root.mostrarPopupGuardar = true;
                    }
                }
            }
        }

        Rectangle {
            id: botonCarruselDer
            width: appWindow.width * 0.04
            height: appWindow.height * 0.15
            radius: width / 2
            color: carruselGuardados.currentIndex < carruselGuardados.count - 3 ? "#A0A0A0" : "#D0D0D0"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.centerIn: parent; text: "▶"; font.pixelSize: parent.width * 0.50; color: "#333333" }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (carruselGuardados.currentIndex < carruselGuardados.count - 3) {
                        carruselGuardados.currentIndex++;
                        carruselGuardados.positionViewAtIndex(carruselGuardados.currentIndex, ListView.Beginning);
                    }
                }
            }
        }
    }

    Rectangle {
        id: botonAtras9
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: parent.width * 0.05
        width: parent.width * 0.12
        height: parent.height * 0.10
        color: areaAtras9.pressed ? "#cc1e1e" : "#FF2D2D"
        radius: height / 2
        Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: areaAtras9
            anchors.fill: parent
            onClicked: { appWindow.limpiarDatos(false); appWindow.estadoActual = "pantalla_nuevo_proyecto" }
        }
    }

    PopupIngresoNombre {
        id: popupGuardar9
        visible: root.mostrarPopupGuardar
        tituloPopup: qsTranslate("Main", "Ingrese nombre del experimento")
        onAceptado: function(name) {
            var nombreFinal = name.trim();
            if (nombreFinal === "") {
                var d = new Date();
                nombreFinal = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear() + "_" + ("0" + d.getHours()).slice(-2) + "_" + ("0" + d.getMinutes()).slice(-2);
            }
            appWindow.var_nombre_experimento = nombreFinal;
            root.mostrarPopupGuardar = false;
            root.mostrarPopupConfirmacion = true;
        }
        onCancelado: { root.mostrarPopupGuardar = false; }
    }

    PopupConfirmarProceso {
        id: popupConfirmacion9
        visible: root.mostrarPopupConfirmacion
        nombreProyecto: appWindow.var_nombre_proyecto
        nombreExperimento: appWindow.var_nombre_experimento
        temp: appWindow.var_deseada_Tem
        ph: appWindow.var_deseada_pH
        agua: appWindow.var_deseada_Agua
        luz: appWindow.var_deseada_Luz
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
                "peso": (Math.random() * 5 + 0.5).toFixed(1) + " MB",
                "seleccionado": false
            });
            appWindow.estadoActual = "pantalla_7"
        }
        onCancelado: { root.mostrarPopupConfirmacion = false; }
    }

    // --- POPUP OPCIONES (Lápiz y Papelera) ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupOpciones
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.50
            height: parent.height * 0.45
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Opciones del proyecto")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
            }

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -10
                spacing: appWindow.width * 0.05

                Rectangle {
                    width: appWindow.width * 0.12
                    height: width
                    radius: 20
                    color: areaLapizOpt.pressed ? "#d1d5db" : "#F3F4F6"
                    Image { source: "Lapiz.png"; anchors.centerIn: parent; width: parent.width * 0.6; fillMode: Image.PreserveAspectFit }
                    MouseArea {
                        id: areaLapizOpt
                        anchors.fill: parent
                        onClicked: {
                            let item = appWindow.datos_guardados.get(root.indexEditando);
                            datosEdicion.nombre = item.nombre;
                            datosEdicion.temp = item.temp;
                            datosEdicion.ph = item.ph;
                            datosEdicion.agua = item.agua;
                            datosEdicion.luz = item.luz;
                            datosEdicion.tiempo = item.tiempo;
                            root.mostrarPopupOpciones = false;
                            root.mostrarPopupEdicionProyecto = true;
                        }
                    }
                }

                Rectangle {
                    width: appWindow.width * 0.12
                    height: width
                    radius: 20
                    color: areaPapeleraOpt.pressed ? "#d1d5db" : "#F3F4F6"
                    Image { source: "Basura.png"; anchors.centerIn: parent; width: parent.width * 0.6; fillMode: Image.PreserveAspectFit }
                    MouseArea {
                        id: areaPapeleraOpt
                        anchors.fill: parent
                        onClicked: {
                            root.mostrarPopupOpciones = false;
                            root.mostrarPopupBorrarGuardado = true;
                        }
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.12
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.08
                anchors.horizontalCenter: parent.horizontalCenter
                color: areaAtrasOpt.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasOpt; anchors.fill: parent; onClicked: root.mostrarPopupOpciones = false }
            }
        }
    }

    // --- POPUP CONFIRMACIÓN DE BORRADO INDIVIDUAL ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupBorrarGuardado
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.50
            height: parent.height * 0.40
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.15
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "¿Desea borrar este proyecto guardado?")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
                width: parent.width * 0.9
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: appWindow.width * 0.12
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.10
                color: areaOkBorrar.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkBorrar
                    anchors.fill: parent
                    onClicked: {
                        appWindow.datos_guardados.remove(root.indexEditando);
                        root.mostrarPopupBorrarGuardado = false;
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.12
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.10
                color: areaAtrasBorrar.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasBorrar; anchors.fill: parent; onClicked: root.mostrarPopupBorrarGuardado = false }
            }
        }
    }

    // --- POPUP EDICIÓN DE DATOS ---
    Item {
        id: popupEdicionDatosRoot
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupEdicionProyecto

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { root.campoEditActivo = ""; }
        }

        focus: visible
        Keys.onPressed: (event) => {
            if (root.campoEditActivo === "Nombre") {
                if (event.key === Qt.Key_Backspace) {
                    if (datosEdicion.nombre.length > 0)
                        datosEdicion.nombre = datosEdicion.nombre.substring(0, datosEdicion.nombre.length - 1);
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    root.campoEditActivo = "";
                } else if (event.text.length > 0) {
                    datosEdicion.nombre += event.text;
                }
                event.accepted = true;
            } else if (root.campoEditActivo !== "") {
                if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                    let digito = (event.key - Qt.Key_0).toString()
                    root.entradaEditTemporal = (root.entradaEditTemporal === "0") ? digito : root.entradaEditTemporal + digito
                    event.accepted = true
                } else if (event.key === Qt.Key_Period) {
                    if (root.entradaEditTemporal.indexOf(".") === -1) {
                        root.entradaEditTemporal += (root.entradaEditTemporal === "" ? "0." : ".")
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Backspace) {
                    if (root.entradaEditTemporal.length > 0) {
                        root.entradaEditTemporal = root.entradaEditTemporal.substring(0, root.entradaEditTemporal.length - 1)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    let val = parseFloat(root.entradaEditTemporal);
                    if (!isNaN(val)) {
                        if (root.campoEditActivo === "Tem") {
                            let minT = appWindow.unidadTemperatura === "C" ? 20 : 68;
                            let maxT = appWindow.unidadTemperatura === "C" ? 100 : 212;
                            datosEdicion.temp = Math.max(minT, Math.min(maxT, val));
                        }
                        else if (root.campoEditActivo === "pH") datosEdicion.ph = Math.max(1, Math.min(14, val));
                        else if (root.campoEditActivo === "Agua") datosEdicion.agua = Math.max(30, Math.min(100, val));
                        else if (root.campoEditActivo === "Luz") datosEdicion.luz = Math.max(0, Math.min(100, val));
                        else if (root.campoEditActivo === "Tiempo") datosEdicion.tiempo = Math.max(6, val).toString();
                    }
                    root.campoEditActivo = "";
                    root.entradaEditTemporal = "";
                    event.accepted = true
                }
            }
        }

        Rectangle {
            width: parent.width * 0.80
            height: parent.height * 0.85
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: root.campoEditActivo = ""
            }

            Text {
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Editar Proyecto")
                font.pixelSize: parent.height * 0.06
                font.bold: true
                color: "black"
            }

            Row {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.15
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.95
                height: parent.height * 0.45
                spacing: 15

                Column {
                    width: parent.width * 0.55
                    height: parent.height
                    spacing: parent.height * 0.035

                    Rectangle {
                        width: parent.width; height: parent.height * 0.13; radius: height/2; color: root.campoEditActivo === "Nombre" ? "#A5D6A7" : "#8DBB5A"
                        Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nombre:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.35; anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: root.campoEditActivo === "Nombre" ? datosEdicion.nombre + "|" : datosEdicion.nombre; font.pixelSize: parent.height * 0.40; font.bold: true; color: "black"; elide: Text.ElideRight }
                        MouseArea { anchors.fill: parent; onClicked: { root.campoEditActivo = "Nombre"; popupEdicionDatosRoot.forceActiveFocus(); } }
                    }
                    Rectangle {
                        width: parent.width; height: parent.height * 0.13; radius: height/2; color: root.campoEditActivo === "Tem" ? "#A5D6A7" : "#8DBB5A"
                        Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Temp °%1:").arg(appWindow.unidadTemperatura); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (root.campoEditActivo === "Tem" ? root.entradaEditTemporal + "|" : datosEdicion.temp); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: { root.campoEditActivo = "Tem"; root.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                    }
                    Rectangle {
                        width: parent.width; height: parent.height * 0.13; radius: height/2; color: root.campoEditActivo === "pH" ? "#A5D6A7" : "#8DBB5A"
                        Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nivel de pH:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (root.campoEditActivo === "pH" ? root.entradaEditTemporal + "|" : datosEdicion.ph); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: { root.campoEditActivo = "pH"; root.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                    }
                    Rectangle {
                        width: parent.width; height: parent.height * 0.13; radius: height/2; color: root.campoEditActivo === "Agua" ? "#A5D6A7" : "#8DBB5A"
                        Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nivel agua %:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (root.campoEditActivo === "Agua" ? root.entradaEditTemporal + "|" : datosEdicion.agua); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: { root.campoEditActivo = "Agua"; root.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                    }
                    Rectangle {
                        width: parent.width; height: parent.height * 0.13; radius: height/2; color: root.campoEditActivo === "Luz" ? "#A5D6A7" : "#8DBB5A"
                        Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nivel luz %:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (root.campoEditActivo === "Luz" ? root.entradaEditTemporal + "|" : datosEdicion.luz); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: { root.campoEditActivo = "Luz"; root.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                    }
                    Rectangle {
                        width: parent.width; height: parent.height * 0.13; radius: height/2; color: root.campoEditActivo === "Tiempo" ? "#A5D6A7" : "#8DBB5A"
                        Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Duración (h):"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (root.campoEditActivo === "Tiempo" ? root.entradaEditTemporal + "|" : datosEdicion.tiempo); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: { root.campoEditActivo = "Tiempo"; root.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                    }
                }

                TecladoNumerico {
                    width: parent.width * 0.45 - 15
                    height: parent.height * 0.95
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.campoEditActivo !== "" && root.campoEditActivo !== "Nombre"
                    onDigitoPresionado: function(d) { root.entradaEditTemporal = root.entradaEditTemporal === "0" ? d : root.entradaEditTemporal + d }
                    onPuntoPresionado:  { if (root.entradaEditTemporal.indexOf(".") === -1) root.entradaEditTemporal += root.entradaEditTemporal === "" ? "0." : "." }
                    onBorrarPresionado: { if (root.entradaEditTemporal.length > 0) root.entradaEditTemporal = root.entradaEditTemporal.slice(0, -1) }
                    onOkPresionado: {
                        let val = parseFloat(root.entradaEditTemporal);
                        if (!isNaN(val)) {
                            if (root.campoEditActivo === "Tem") {
                                let minT = appWindow.unidadTemperatura === "C" ? 20 : 68;
                                let maxT = appWindow.unidadTemperatura === "C" ? 100 : 212;
                                datosEdicion.temp = Math.max(minT, Math.min(maxT, val));
                            }
                            else if (root.campoEditActivo === "pH") datosEdicion.ph = Math.max(1, Math.min(14, val));
                            else if (root.campoEditActivo === "Agua") datosEdicion.agua = Math.max(30, Math.min(100, val));
                            else if (root.campoEditActivo === "Luz") datosEdicion.luz = Math.max(0, Math.min(100, val));
                            else if (root.campoEditActivo === "Tiempo") datosEdicion.tiempo = Math.max(6, val).toString();
                        }
                        root.campoEditActivo = "";
                        root.entradaEditTemporal = "";
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 30
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.15
                color: areaOkEdit.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkEdit
                    anchors.fill: parent
                    enabled: root.campoEditActivo === ""
                    onClicked: {
                        root.mostrarPopupEdicionProyecto = false;
                        root.mostrarPopupConfirmarEdicion = true;
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.15
                color: areaAtrasEdit.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea {
                    id: areaAtrasEdit
                    anchors.fill: parent
                    enabled: root.campoEditActivo === ""
                    onClicked: { root.campoEditActivo = ""; root.mostrarPopupEdicionProyecto = false; }
                }
            }

            TecladoQwerty {
                id: tecladoQwertyEdit
                z: 100
                width: parent.width * 0.95
                height: parent.height * 0.35
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.campoEditActivo === "Nombre" ? 10 : parent.height * -0.50
                Behavior on anchors.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                onTeclaPresionada:  function(t) { datosEdicion.nombre += t }
                onBorrarPresionado: { if (datosEdicion.nombre.length > 0) datosEdicion.nombre = datosEdicion.nombre.slice(0, -1) }
                onIntroPresionado:  { root.campoEditActivo = "" }
                onCerrarPresionado: { root.campoEditActivo = "" }
            }
        }
    }

    // --- POPUP CONFIRMACIÓN EDICIÓN FINAL ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupConfirmarEdicion
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            id: cajaConfirmarEdicion
            width: parent.width * 0.85
            height: parent.height * 0.65
            anchors.centerIn: parent
            color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: cajaConfirmarEdicion.height * 0.05
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.9
                text: qsTranslate("Main", "¿Estás seguro que quieres guardar los cambios hechos al proyecto?")
                font.pixelSize: cajaConfirmarEdicion.height * 0.06
                font.bold: false
                color: "#cc0000"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: cajaConfirmarEdicion.height * 0.02
                width: parent.width * 0.90
                spacing: cajaConfirmarEdicion.height * 0.03

                Text {
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Proyecto: <b>%1</b>").arg(datosEdicion.nombre)
                    font.pixelSize: cajaConfirmarEdicion.height * 0.055
                    color: "black"
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Row {
                    width: parent.width
                    spacing: parent.width * 0.02
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTranslate("Main", "Temperatura: <b>%1 °%2</b>").arg(datosEdicion.temp.toFixed(1)).arg(appWindow.unidadTemperatura)
                        font.pixelSize: cajaConfirmarEdicion.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTranslate("Main", "Nivel de pH: <b>%1</b>").arg(datosEdicion.ph.toFixed(1))
                        font.pixelSize: cajaConfirmarEdicion.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    width: parent.width
                    spacing: parent.width * 0.02
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTranslate("Main", "Nivel de agua: <b>%1 %</b>").arg(datosEdicion.agua.toFixed(1))
                        font.pixelSize: cajaConfirmarEdicion.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTranslate("Main", "Nivel de luz: <b>%1 %</b>").arg(datosEdicion.luz.toFixed(1))
                        font.pixelSize: cajaConfirmarEdicion.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    textFormat: Text.RichText
                    property int t_total: parseFloat(datosEdicion.tiempo) || 0
                    property int t_semanas: Math.floor(t_total / 168)
                    property int t_dias: Math.floor((t_total % 168) / 24)
                    property int t_horas: Math.floor(t_total % 24)
                    property int t_minutos: Math.round((t_total - Math.floor(t_total)) * 60)
                    text: qsTranslate("Main", "Tiempo: Semanas <b>%1</b>, Días <b>%2</b>, Horas <b>%3</b>, Minutos <b>%4</b> (Total: <b>%5 Hrs</b>)").arg(t_semanas).arg(t_dias).arg(t_horas).arg(t_minutos).arg(t_total.toFixed(1))
                    font.pixelSize: cajaConfirmarEdicion.height * 0.055
                    color: "black"
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: appWindow.width * 0.05
                anchors.bottomMargin: cajaConfirmarEdicion.height * 0.05
                width: appWindow.width * 0.20
                height: appWindow.height * 0.10
                color: areaOkConfirmEdit.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkConfirmEdit
                    anchors.fill: parent
                    onClicked: {
                        appWindow.datos_guardados.setProperty(root.indexEditando, "nombre", datosEdicion.nombre);
                        appWindow.datos_guardados.setProperty(root.indexEditando, "temp", datosEdicion.temp);
                        appWindow.datos_guardados.setProperty(root.indexEditando, "ph", datosEdicion.ph);
                        appWindow.datos_guardados.setProperty(root.indexEditando, "agua", datosEdicion.agua);
                        appWindow.datos_guardados.setProperty(root.indexEditando, "luz", datosEdicion.luz);
                        appWindow.datos_guardados.setProperty(root.indexEditando, "tiempo", datosEdicion.tiempo);
                        root.mostrarPopupConfirmarEdicion = false;
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: appWindow.width * 0.05
                anchors.bottomMargin: cajaConfirmarEdicion.height * 0.05
                width: appWindow.width * 0.12
                height: appWindow.height * 0.10
                color: areaAtrasConfirmEdit.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasConfirmEdit; anchors.fill: parent; onClicked: root.mostrarPopupConfirmarEdicion = false }
            }
        }
    }
}
