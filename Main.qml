import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1280
    height: 800
    title: qsTr("Interfaz de Biorreactor - UPIIZ")
    color: "#FFFFFF"

    // ==========================================
    // 1. LÓGICA CENTRAL Y GESTIÓN DE ESTADOS
    // ==========================================
    // estadoActual controla la navegación de la HMI.
    property string estadoActual: "pantalla_de_carga"

    property string estadoPrevioAjustes: "pantalla_principal"
    property string estadoPrevioPantalla6: "pantalla_nuevo_proyecto"
    property string estadoPrevioPantalla7: "pantalla_6"
    property bool   procesoListoParaIniciar: false

    property int sensor_estado_primero: 1
    property int sensor_estado_calibracion: 1
    property string estado_sensor_retorno_error: "pantalla_de_carga"
    property string textoMensajeError: qsTranslate("Main", "Falla en sensor")

    // --- Configuraciones Globales ---
    property string idiomaActual: "Español"
    property string unidadTemperatura: "C"

    // Bandera para nueva configuración de mismo experimento
    property bool omitirPedirNombre: false

    // --- Variables de Identificación de Proyecto ---
    property string var_nombre_proyecto: ""
    property string var_nombre_experimento: ""

    property int var_seleccion_grafica: 1 // 1: Temp, 2: Agua, 3: pH, 4: Luz
    property int var_vaciado_nivel_1: 5000
    property int var_vaciado_nivel_2: 5000

    // --- Control de Tiempo ---
    property real var_deseada_tiempo_semanas: 0.0
    property real var_deseada_tiempo_dias: 0.0
    property real var_deseada_tiempo_horas: 0.0
    property real var_deseada_tiempo_minutos: 0.0
    property real var_deseada_tiempo_total_horas: 0.0

    // ==========================================
    // 2. FUNCIONES GLOBALES
    // ==========================================
    function limpiarDatos(mantenerNombres) {
        if (!mantenerNombres) {
            var_nombre_proyecto = ""
            var_nombre_experimento = ""
        }

        backend.resetearSetpoints()
        var_deseada_tiempo_semanas = 0.0
        var_deseada_tiempo_dias = 0.0
        var_deseada_tiempo_horas = 0.0
        var_deseada_tiempo_minutos = 0.0
        var_deseada_tiempo_total_horas = 0.0

        pantalla6.tempConfigurada = false
        pantalla6.phConfigurado = false
        pantalla6.aguaConfigurada = false
        pantalla6.luzConfigurada = false
        pantalla6.tiempoConfigurado = false

        pantalla6.campoActivo = ""
        pantalla6.entradaTemporal = ""
    }

    // ==========================================
    // 3. BASES DE DATOS LOCALES
    // ==========================================
    property alias datos_guardados: _modelDatosGuardados
    property alias registro_experimentos: _modelRegistroExperimentos

    ListModel {
        id: _modelDatosGuardados
        ListElement { nombre: "Cultivo Fresa"; temp: 24.5; ph: 6.0; agua: 80.0; luz: 50.0; tiempo: "168.0" }
        ListElement { nombre: "Cultivo Alga"; temp: 26.0; ph: 7.5; agua: 90.0; luz: 60.0; tiempo: "336.0" }
        ListElement { nombre: "Cepa X-12"; temp: 22.0; ph: 6.8; agua: 75.0; luz: 80.0; tiempo: "72.0" }
        ListElement { nombre: "Prueba Levadura"; temp: 25.0; ph: 4.5; agua: 50.0; luz: 0.0; tiempo: "48.0" }
        ListElement { nombre: "Proyecto Beta"; temp: 30.0; ph: 7.0; agua: 100.0; luz: 90.0; tiempo: "12.0" }
    }

    ListModel {
        id: _modelRegistroExperimentos
        ListElement { proyecto: "Cepa X-12"; experimento: "Beta-1"; fecha: "20/03/2026"; tiempo: "72.0 / 72.0 hrs"; peso: "1.2 MB"; seleccionado: false }
        ListElement { proyecto: "Cultivo Fresa"; experimento: "Fase 2"; fecha: "21/03/2026"; tiempo: "160.0 / 168.0 hrs"; peso: "0.8 MB"; seleccionado: false }
        ListElement { proyecto: "Prueba Levadura"; experimento: "Muestra A"; fecha: "22/03/2026"; tiempo: "24.5 / 48.0 hrs"; peso: "0.5 MB"; seleccionado: false }
    }

    // ==========================================
    // 4. COMPONENTES REUTILIZABLES (archivos externos)
    // ==========================================

    Timer {
        interval: 5000
        running: !backend.puertoConectado
        repeat: true
        onTriggered: backend.buscarYConectar()
    }

    CabeceraPersistente {}

    // ==========================================
    // ESTADOS / PANTALLAS
    // ==========================================

    PantallaCarga         { id: pantallaCarga;          anchors.fill: parent; appWindow: mainWindow }
    PantallaError         { id: pantallaError;          anchors.fill: parent; appWindow: mainWindow }
    PantallaPrincipal     { id: pantallaPrincipal;      anchors.fill: parent; appWindow: mainWindow }
    PantallaAjustes       { id: pantallaAjustes;        anchors.fill: parent; appWindow: mainWindow }
    PantallaNuevoProyecto { id: pantallaNuevoProyecto;  anchors.fill: parent; appWindow: mainWindow }
    Pantalla6             { id: pantalla6;              anchors.fill: parent; appWindow: mainWindow }
    Pantalla7             { id: pantalla7;              anchors.fill: parent; appWindow: mainWindow }
    PantallaProcesos      { id: pantallaProcesos;       anchors.fill: parent; appWindow: mainWindow }
    PantallaProyectosGuardados { id: pantallaProyectosGuardados; anchors.fill: parent; appWindow: mainWindow }
    PantallaConfigGraficas { id: pantallaConfigGraficas; anchors.fill: parent; appWindow: mainWindow }
    PantallaPostProceso   { id: pantallaPostProceso;    anchors.fill: parent; appWindow: mainWindow }
    PantallaExtraccion    { id: pantallaExtraccion;     anchors.fill: parent; appWindow: mainWindow }
    PantallaGuardarConfig { id: pantallaGuardarConfig;  anchors.fill: parent; appWindow: mainWindow }
    PantallaLimpieza      { id: pantallaLimpieza;       anchors.fill: parent; appWindow: mainWindow }
    PantallaRegistro      { id: pantallaRegistro;       anchors.fill: parent; appWindow: mainWindow }
}
