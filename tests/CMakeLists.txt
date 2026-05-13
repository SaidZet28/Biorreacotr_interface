cmake_minimum_required(VERSION 3.16)
project(TestsBiorreactor LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(Qt6 REQUIRED COMPONENTS Test Core SerialPort)

enable_testing()

set(SRC "${CMAKE_CURRENT_SOURCE_DIR}/..")

# ── ControladorHisteresis ─────────────────────────────────────────────────────
qt_add_executable(tst_histeresis
    tst_histeresis.cpp
    ${SRC}/controladorhisteresis.h
    ${SRC}/controladorhisteresis.cpp)
target_include_directories(tst_histeresis PRIVATE ${SRC})
target_link_libraries(tst_histeresis PRIVATE Qt6::Test Qt6::Core)
add_test(NAME tst_histeresis COMMAND tst_histeresis)

# ── ControladorPID ────────────────────────────────────────────────────────────
qt_add_executable(tst_pid
    tst_pid.cpp
    ${SRC}/controladorpid.h
    ${SRC}/controladorpid.cpp)
target_include_directories(tst_pid PRIVATE ${SRC})
target_link_libraries(tst_pid PRIVATE Qt6::Test Qt6::Core)
add_test(NAME tst_pid COMMAND tst_pid)

# ── ControladorFuzzy ──────────────────────────────────────────────────────────
qt_add_executable(tst_fuzzy
    tst_fuzzy.cpp
    ${SRC}/controladorfuzzy.h
    ${SRC}/controladorfuzzy.cpp)
target_include_directories(tst_fuzzy PRIVATE ${SRC})
target_link_libraries(tst_fuzzy PRIVATE Qt6::Test Qt6::Core)
add_test(NAME tst_fuzzy COMMAND tst_fuzzy)

# ── parsearTrama (vía GestorBiorreactor) ──────────────────────────────────────
qt_add_executable(tst_parseartrama
    tst_parseartrama.cpp
    ${SRC}/gestorbiorreactor.h    ${SRC}/gestorbiorreactor.cpp
    ${SRC}/controladorpid.h       ${SRC}/controladorpid.cpp
    ${SRC}/controladorfuzzy.h     ${SRC}/controladorfuzzy.cpp
    ${SRC}/controladorhisteresis.h ${SRC}/controladorhisteresis.cpp
    ${SRC}/driverpca9685.h        ${SRC}/driverpca9685.cpp
    ${SRC}/driverxm125.h          ${SRC}/driverxm125.cpp)
target_include_directories(tst_parseartrama PRIVATE ${SRC})
target_link_libraries(tst_parseartrama PRIVATE Qt6::Test Qt6::Core Qt6::SerialPort)
add_test(NAME tst_parseartrama COMMAND tst_parseartrama)
