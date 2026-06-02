cmake_minimum_required(VERSION 3.16)
project(TestsBiorreactor LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(Qt6 REQUIRED COMPONENTS Test Core SerialPort)

enable_testing()

set(ROOT       "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(BACKEND    "${ROOT}/src/backend")
set(CTRL       "${ROOT}/src/controllers")
set(DRIVERS    "${ROOT}/src/drivers")

# ── ControladorHisteresis ─────────────────────────────────────────────────────
qt_add_executable(tst_histeresis
    tst_histeresis.cpp
    ${CTRL}/controladorhisteresis.h
    ${CTRL}/controladorhisteresis.cpp)
target_include_directories(tst_histeresis PRIVATE ${CTRL})
target_link_libraries(tst_histeresis PRIVATE Qt6::Test Qt6::Core)
add_test(NAME tst_histeresis COMMAND tst_histeresis)

# ── ControladorPID ────────────────────────────────────────────────────────────
qt_add_executable(tst_pid
    tst_pid.cpp
    ${CTRL}/controladorpid.h
    ${CTRL}/controladorpid.cpp)
target_include_directories(tst_pid PRIVATE ${CTRL})
target_link_libraries(tst_pid PRIVATE Qt6::Test Qt6::Core)
add_test(NAME tst_pid COMMAND tst_pid)

# ── ControladorFuzzy ──────────────────────────────────────────────────────────
qt_add_executable(tst_fuzzy
    tst_fuzzy.cpp
    ${CTRL}/controladorfuzzy.h
    ${CTRL}/controladorfuzzy.cpp)
target_include_directories(tst_fuzzy PRIVATE ${CTRL})
target_link_libraries(tst_fuzzy PRIVATE Qt6::Test Qt6::Core)
add_test(NAME tst_fuzzy COMMAND tst_fuzzy)

# ── parsearTrama (vía GestorBiorreactor) ──────────────────────────────────────
qt_add_executable(tst_parseartrama
    tst_parseartrama.cpp
    ${BACKEND}/gestorbiorreactor.h      ${BACKEND}/gestorbiorreactor.cpp
    ${CTRL}/controladorpid.h            ${CTRL}/controladorpid.cpp
    ${CTRL}/controladorfuzzy.h          ${CTRL}/controladorfuzzy.cpp
    ${CTRL}/controladorhisteresis.h     ${CTRL}/controladorhisteresis.cpp
    ${DRIVERS}/driverpca9685.h          ${DRIVERS}/driverpca9685.cpp
    ${DRIVERS}/driverxm125.h            ${DRIVERS}/driverxm125.cpp)
target_include_directories(tst_parseartrama PRIVATE ${BACKEND} ${CTRL} ${DRIVERS})
target_compile_definitions(tst_parseartrama PRIVATE SIMULACION_ACTIVA)
target_link_libraries(tst_parseartrama PRIVATE Qt6::Test Qt6::Core Qt6::SerialPort)
add_test(NAME tst_parseartrama COMMAND tst_parseartrama)
