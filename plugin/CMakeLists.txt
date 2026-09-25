qt_add_library(morphblobs SHARED)

qt_add_qml_module(morphblobs
    URI Morph.Blobs
    VERSION 1.0
    SOURCES
        src/blobgroup.cpp
        src/blobgroup.hpp
        src/blobshape.cpp
        src/blobshape.hpp
        src/blobrect.cpp
        src/blobrect.hpp
        src/blobinvertedrect.cpp
        src/blobinvertedrect.hpp
        src/blobmaterial.cpp
        src/blobmaterial.hpp
)

# The scene graph batches geometry, so the vertex shader needs its
# batchable variant baked in or pipeline creation fails.
qt_add_shaders(morphblobs "morphblobs_shaders"
    BATCHABLE
    OPTIMIZED
    NOHLSL
    NOMSL
    GLSL "300es,330"
    PREFIX "/"
    FILES
        shaders/blob.vert
        shaders/blob.frag
)

# The generated qmltyperegistrations.cpp includes our headers by bare
# name, so src/ has to be on the include path.
target_include_directories(morphblobs PRIVATE src)

target_link_libraries(morphblobs PRIVATE Qt6::Gui Qt6::Quick)

install(
    TARGETS morphblobs morphblobsplugin
    LIBRARY DESTINATION "${MORPH_QML_DIR}/Morph/Blobs"
    RUNTIME DESTINATION "${MORPH_QML_DIR}/Morph/Blobs"
)

install(
    FILES "${QT_QML_OUTPUT_DIRECTORY}/Morph/Blobs/qmldir"
    DESTINATION "${MORPH_QML_DIR}/Morph/Blobs"
)

# Painted helpers that are not blobs get their own module so the URI
# stays meaningful.
qt_add_library(morphcomponents SHARED)

qt_add_qml_module(morphcomponents
    URI Morph.Components
    VERSION 1.0
    SOURCES
        src/wavyline.cpp
        src/wavyline.hpp
)

target_include_directories(morphcomponents PRIVATE src)

target_link_libraries(morphcomponents PRIVATE Qt6::Gui Qt6::Quick)

install(
    TARGETS morphcomponents morphcomponentsplugin
    LIBRARY DESTINATION "${MORPH_QML_DIR}/Morph/Components"
    RUNTIME DESTINATION "${MORPH_QML_DIR}/Morph/Components"
)

install(
    FILES "${QT_QML_OUTPUT_DIRECTORY}/Morph/Components/qmldir"
    DESTINATION "${MORPH_QML_DIR}/Morph/Components"
)
