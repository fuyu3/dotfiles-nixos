{ pkgs, inputs, ... }:

let
  # Pacote exposto pelo flake do m3shapes (input já adicionado no flake.nix).
  m3shapesPkg = inputs.m3shapes.packages.${pkgs.stdenv.hostPlatform.system}.default;
  qt5compatQml = "${pkgs.qt6.qt5compat}/lib/qt-6/qml";
  m3shapesQml = "${m3shapesPkg}/${pkgs.qt6.qtbase.qtQmlPrefix}";

  # Caelestia.Blobs não é publicado em lugar nenhum, então em vez de um
  # input de flake (como o m3shapes), é uma derivação local: o código
  # extraído mora em vendor/caelestia-blobs-standalone dentro do próprio
  # repo, e o Nix builda ele igual buildaria qualquer outro pacote.
  caelestiaBlobsPkg = pkgs.stdenv.mkDerivation {
    pname = "caelestia-blobs";
    version = "1.0.0";
    src = ../config/quickshell/caelestia-blobs;

    nativeBuildInputs = with pkgs; [
      cmake
      ninja
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtshadertools
    ];

    # É uma lib/plugin QML, não um executável — sem isso o hook do Qt do
    # nixpkgs recusa buildar (exige dizer explicitamente qual dos dois é).
    dontWrapQtApps = true;

    cmakeFlags = [
      "-DINSTALL_QMLDIR=${pkgs.qt6.qtbase.qtQmlPrefix}"
    ];
  };
  caelestiaBlobsQml = "${caelestiaBlobsPkg}/${pkgs.qt6.qtbase.qtQmlPrefix}";
in
{
  environment.systemPackages = [ m3shapesPkg caelestiaBlobsPkg ];

  # Junto aqui os três caminhos QML num lugar só, em vez de deixar
  # QML2_IMPORT_PATH espalhado entre packages.nix e este módulo — remova
  # o bloco QML_IMPORT_PATH/QML2_IMPORT_PATH que estava em packages.nix,
  # esse aqui substitui os dois.
  environment.variables = {
    QML_IMPORT_PATH = qt5compatQml;
    QML2_IMPORT_PATH = [ qt5compatQml m3shapesQml caelestiaBlobsQml ];
  };
}
