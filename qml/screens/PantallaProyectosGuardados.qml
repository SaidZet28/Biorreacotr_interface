import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_proyectos_guardados"

    property bool mostrarPopupGuardar:         false
    property bool mostrarPopupConfirmacion:     false
    property bool mostrarPopupOpciones:         false
    property bool mostrarPopupBorrarGuardado:   false
    property bool mostrarPopupEdicionProyecto:  false
    property bool mostrarPopupConfirmarEdicion: false

    property int indexEditando: -1

    QtObject {
        id: datosEdicion
        property string nombre: ""
        property real   temp:   0.0
        property real   ph:     0.0
        property real   agua:   0.0
        property real   luz:    0.0
        property string tiempo: ""
    }

    // ── Título ────────────────────────────────────────────────────────────────
    Column {
        id: colTitulo
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

    // ── Carrusel ──────────────────────────────────────────────────────────────
    Item {
        anchors.top: colTitulo.bottom
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
            color: carrusel.currentIndex > 0 ? "#A0A0A0" : "#D0D0D0"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.centerIn: parent; text: "◀"; font.pixelSize: parent.width * 0.50; color: "#333333" }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (carrusel.currentIndex > 0) {
                        carrusel.currentIndex--;
                        carrusel.positionViewAtIndex(carrusel.currentIndex, ListView.Beginning);
                    }
                }
            }
        }

        ListView {
            id: carrusel
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
            delegate: TarjetaProyecto {
                width: (carrusel.width - (carrusel.spacing * 2)) / 3
                height: carrusel.height
                appWindow: root.appWindow
                indice: index
                nombre: model.nombre
                temp:   model.temp
                ph:     model.ph
                agua:   model.agua
                luz:    model.luz
                tiempo: model.tiempo
                color:  index % 2 === 0 ? "#8DBB5A" : "#6E9C9C"

                onOpcionesClicked: {
                    root.indexEditando = index;
                    root.mostrarPopupOpciones = true;
                }
                onTarjetaClicked: function(n, t, p, a, l, ti) {
                    appWindow.limpiarDatos(false);
                    appWindow.var_nombre_proyecto = n;
                    backend.setpointTem   = (appWindow.unidadTemperatura === "C" ? t : (t * 9/5 + 32));
                    backend.setpointPH    = p;
                    backend.setpointLuz   = l;
                    let total = parseFloat(ti);
                    appWindow.var_deseada_tiempo_total_horas = total;
                    appWindow.var_deseada_tiempo_semanas = Math.floor(total / 168);
                    let rem = total % 168;
                    appWindow.var_deseada_tiempo_dias    = Math.floor(rem / 24);
                    rem = rem % 24;
                    appWindow.var_deseada_tiempo_horas   = Math.floor(rem);
                    appWindow.var_deseada_tiempo_minutos = Math.round((rem - appWindow.var_deseada_tiempo_horas) * 60);
                    popupGuardar9.nombrePorDefecto = "";
                    root.mostrarPopupGuardar = true;
                }
            }
        }

        Rectangle {
            id: botonCarruselDer
            width: appWindow.width * 0.04
            height: appWindow.height * 0.15
            radius: width / 2
            color: carrusel.currentIndex < carrusel.count - 3 ? "#A0A0A0" : "#D0D0D0"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.centerIn: parent; text: "▶"; font.pixelSize: parent.width * 0.50; color: "#333333" }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (carrusel.currentIndex < carrusel.count - 3) {
                        carrusel.currentIndex++;
                        carrusel.positionViewAtIndex(carrusel.currentIndex, ListView.Beginning);
                    }
                }
            }
        }
    }

    // ── Botón Atrás ───────────────────────────────────────────────────────────
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

    // ── Popups reutilizables ──────────────────────────────────────────────────
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
        visible: root.mostrarPopupConfirmacion
        nombreProyecto:     appWindow.var_nombre_proyecto
        nombreExperimento:  appWindow.var_nombre_experimento
        temp:               backend.setpointTem
        ph:                 backend.setpointPH
        luz:                backend.setpointLuz
        tiempoSemanas:      appWindow.var_deseada_tiempo_semanas
        tiempoDias:         appWindow.var_deseada_tiempo_dias
        tiempoHoras:        appWindow.var_deseada_tiempo_horas
        tiempoMinutos:      appWindow.var_deseada_tiempo_minutos
        tiempoTotal:        appWindow.var_deseada_tiempo_total_horas
        unidadTemperatura:  appWindow.unidadTemperatura
        onConfirmado: {
            root.mostrarPopupConfirmacion = false;
            appWindow.estadoPrevioPantalla7 = "pantalla_proyectos_guardados";
            var d = new Date();
            var cadenaFecha = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear();
            appWindow.registro_experimentos.append({
                "proyecto":     appWindow.var_nombre_proyecto,
                "experimento":  appWindow.var_nombre_experimento,
                "fecha":        cadenaFecha,
                "tiempo":       "0.0 / " + appWindow.var_deseada_tiempo_total_horas.toFixed(1) + " hrs",
                "peso":         "0 lect.",
                "seleccionado": false
            });
            appWindow.estadoActual = "pantalla_7"
        }
        onCancelado: { root.mostrarPopupConfirmacion = false; }
    }

    // ── Popups de gestión de proyectos ────────────────────────────────────────
    PopupOpcionesProyecto {
        appWindow: root.appWindow
        visible: root.mostrarPopupOpciones
        onEditarSolicitado: {
            let item = appWindow.datos_guardados.get(root.indexEditando);
            popupEdicion.nombreInicial = item.nombre;
            popupEdicion.tempInicial   = item.temp;
            popupEdicion.phInicial     = item.ph;
            popupEdicion.aguaInicial   = item.agua;
            popupEdicion.luzInicial    = item.luz;
            popupEdicion.tiempoInicial = item.tiempo;
            root.mostrarPopupOpciones = false;
            root.mostrarPopupEdicionProyecto = true;
        }
        onBorrarSolicitado: {
            root.mostrarPopupOpciones = false;
            root.mostrarPopupBorrarGuardado = true;
        }
        onCerrado: { root.mostrarPopupOpciones = false; }
    }

    PopupBorrarProyecto {
        appWindow: root.appWindow
        visible: root.mostrarPopupBorrarGuardado
        onConfirmado: {
            appWindow.datos_guardados.remove(root.indexEditando);
            root.mostrarPopupBorrarGuardado = false;
        }
        onCancelado: { root.mostrarPopupBorrarGuardado = false; }
    }

    PopupEdicionProyecto {
        id: popupEdicion
        appWindow: root.appWindow
        visible: root.mostrarPopupEdicionProyecto
        onConfirmadoEdicion: function(n, t, p, a, l, ti) {
            datosEdicion.nombre = n;
            datosEdicion.temp   = t;
            datosEdicion.ph     = p;
            datosEdicion.agua   = a;
            datosEdicion.luz    = l;
            datosEdicion.tiempo = ti;
            root.mostrarPopupEdicionProyecto = false;
            root.mostrarPopupConfirmarEdicion = true;
        }
        onCancelado: { root.mostrarPopupEdicionProyecto = false; }
    }

    PopupConfirmarEdicion {
        appWindow: root.appWindow
        visible: root.mostrarPopupConfirmarEdicion
        nombre: datosEdicion.nombre
        temp:   datosEdicion.temp
        ph:     datosEdicion.ph
        agua:   datosEdicion.agua
        luz:    datosEdicion.luz
        tiempo: datosEdicion.tiempo
        onConfirmado: {
            appWindow.datos_guardados.setProperty(root.indexEditando, "nombre", datosEdicion.nombre);
            appWindow.datos_guardados.setProperty(root.indexEditando, "temp",   datosEdicion.temp);
            appWindow.datos_guardados.setProperty(root.indexEditando, "ph",     datosEdicion.ph);
            appWindow.datos_guardados.setProperty(root.indexEditando, "agua",   datosEdicion.agua);
            appWindow.datos_guardados.setProperty(root.indexEditando, "luz",    datosEdicion.luz);
            appWindow.datos_guardados.setProperty(root.indexEditando, "tiempo", datosEdicion.tiempo);
            appWindow.salvarDatosGuardados();
            root.mostrarPopupConfirmarEdicion = false;
        }
        onCancelado: { root.mostrarPopupConfirmarEdicion = false; }
    }
}
