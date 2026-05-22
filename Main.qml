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
    property string textoMensajeError: qsTr("Falla en sensor")

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
    property bool _cargandoModelos: false

    ListModel { id: _modelDatosGuardados }

    ListModel { id: _modelRegistroExperimentos }

    // ── Persistencia JSON ─────────────────────────────────────────────────
    function salvarDatosGuardados() {
        let arr = []
        for (let i = 0; i < datos_guardados.count; i++) {
            let it = datos_guardados.get(i)
            arr.push({ "nombre": it.nombre, "temp": it.temp, "ph": it.ph,
                        "agua": it.agua, "luz": it.luz, "tiempo": it.tiempo })
        }
        backend.guardarModelo("datos_guardados", arr)
    }

    function salvarRegistroExperimentos() {
        let arr = []
        for (let i = 0; i < registro_experimentos.count; i++) {
            let it = registro_experimentos.get(i)
            arr.push({ "proyecto": it.proyecto, "experimento": it.experimento,
                        "fecha": it.fecha, "tiempo": it.tiempo,
                        "peso": it.peso, "seleccionado": it.seleccionado })
        }
        backend.guardarModelo("registro_experimentos", arr)
    }

    // Carga al inicio; si no existe el JSON mantiene los datos de muestra
    Component.onCompleted: {
        _cargandoModelos = true
        let dg = backend.cargarModelo("datos_guardados")
        if (dg.length > 0) {
            _modelDatosGuardados.clear()
            for (let i = 0; i < dg.length; i++) _modelDatosGuardados.append(dg[i])
        }
        let re = backend.cargarModelo("registro_experimentos")
        if (re.length > 0) {
            _modelRegistroExperimentos.clear()
            for (let i = 0; i < re.length; i++) _modelRegistroExperimentos.append(re[i])
        }
        _cargandoModelos = false
    }

    // Auto-guardo cuando cambia el número de elementos (append / remove),
    // excepto durante la carga inicial para evitar N escrituras en disco.
    Connections {
        target: _modelDatosGuardados
        function onCountChanged() { if (!_cargandoModelos) salvarDatosGuardados() }
    }
    Connections {
        target: _modelRegistroExperimentos
        function onCountChanged() { if (!_cargandoModelos) salvarRegistroExperimentos() }
    }

    // ==========================================
    // 4. COMPONENTES REUTILIZABLES (archivos externos)
    // ==========================================

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
