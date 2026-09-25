{
  lib,
  stdenv,
  cmake,
  ninja,
  makeWrapper,
  qt6,
  spirv-tools,
  quickshell,
  extraRuntimeDeps ? [],
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "morph-shell";
  version = "0.1.0";

  src = builtins.path {
    path = ../.;
    name = "morph-shell-src";
  };

  nativeBuildInputs = [
    cmake
    ninja
    makeWrapper
    qt6.wrapQtAppsHook
    qt6.qtshadertools
    spirv-tools
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    quickshell
  ];

  # We do not ship a Qt app of our own — we wrap quickshell's binary below.
  dontWrapQtApps = true;

  postInstall = ''
    makeWrapper ${quickshell}/bin/quickshell $out/bin/morph-shell \
      --prefix QML2_IMPORT_PATH : "$out/lib/qt-6/qml" \
      --prefix QML_IMPORT_PATH : "$out/lib/qt-6/qml" \
      ${lib.optionalString (extraRuntimeDeps != []) ''--prefix PATH : "${lib.makeBinPath extraRuntimeDeps}" ''}\
      --add-flags "-p $out/share/morph-shell"
  '';

  meta = {
    description = "A Quickshell desktop shell";
    platforms = lib.platforms.linux;
    mainProgram = "morph-shell";
  };
})
