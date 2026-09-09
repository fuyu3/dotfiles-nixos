{ pkgs, inputs, ... }:

let
  # Pacote exposto pelo flake do m3shapes (input já adicionado no flake.nix).
  m3shapesPkg = inputs.m3shapes.packages.${pkgs.system}.default;
  qt5compatQml = "${pkgs.qt6.qt5compat}/lib/qt-6/qml";
  m3shapesQml = "${m3shapesPkg}/${pkgs.qt6.qtbase.qtQmlPrefix}";
in
{
  environment.systemPackages = [ m3shapesPkg ];

  # Junto aqui os dois caminhos QML num lugar só, em vez de deixar
  # QML2_IMPORT_PATH espalhado entre packages.nix e este módulo — remova
  # o bloco QML_IMPORT_PATH/QML2_IMPORT_PATH que estava em packages.nix,
  # esse aqui substitui os dois.
  environment.variables = {
    QML_IMPORT_PATH = qt5compatQml;
    QML2_IMPORT_PATH = [ qt5compatQml m3shapesQml ];
  };
}
