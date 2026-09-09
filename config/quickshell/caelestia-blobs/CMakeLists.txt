cmake_minimum_required(VERSION 3.16)
project(CaelestiaBlobs VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick ShaderTools)

qt_standard_project_setup(REQUIRES 6.9)

if(NOT DEFINED QT_QML_OUTPUT_DIRECTORY)
    set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
endif()

qt_add_qml_module(caelestia-blobs
    URI Caelestia.Blobs
    VERSION 1.0
    SOURCES
        src/blobgroup.hpp
        src/blobgroup.cpp
        src/blobshape.hpp
        src/blobshape.cpp
        src/blobrect.hpp
        src/blobrect.cpp
        src/blobinvertedrect.hpp
        src/blobinvertedrect.cpp
        src/blobmaterial.hpp
        src/blobmaterial.cpp
)

target_link_libraries(caelestia-blobs PRIVATE
    Qt::Core
    Qt::Qml
    Qt::Quick
)

# Necessário porque o registro automático de tipos QML do Qt gera código que
# inclui os headers sem caminho (#include <blobgroup.hpp>) — no repositório
# original isso funcionava de graça porque o CMakeLists.txt vivia na mesma
# pasta dos .hpp; aqui eles estão em src/, então precisa declarar explícito.
target_include_directories(caelestia-blobs PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# O CMakeLists original do caelestia usa BATCHABLE OPTIMIZED NOHLSL NOMSL e
# GLSL "300es,330" (só o que o Linux/Wayland precisa). Reproduzido aqui.
qt_add_shaders(caelestia-blobs "blob_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    GLSL "300es,330"
    PREFIX "/"
    BASE "src"
    FILES
        src/shaders/blob.frag
        src/shaders/blob.vert
)

# Instalação — mesma lógica do qml-module.cmake original, simplificada
# (sem o truque de mover a lib "backing" pra fora do dir do plugin, que só
# importa quando vários módulos QML precisam linkar entre si).
set(INSTALL_QMLDIR "usr/lib/qt6/qml" CACHE STRING "QML install dir")

qt_query_qml_module(caelestia-blobs
    PLUGIN_TARGET module_plugin_target
    TARGET_PATH module_target_path
    QMLDIR module_qmldir
    TYPEINFO module_typeinfo
)

set(module_dir "${INSTALL_QMLDIR}/${module_target_path}")

install(TARGETS caelestia-blobs
    LIBRARY DESTINATION "${module_dir}"
    RUNTIME DESTINATION "${module_dir}"
)
install(TARGETS "${module_plugin_target}"
    LIBRARY DESTINATION "${module_dir}"
    RUNTIME DESTINATION "${module_dir}"
)
install(FILES "${module_qmldir}" DESTINATION "${module_dir}")
install(FILES "${module_typeinfo}" DESTINATION "${module_dir}")