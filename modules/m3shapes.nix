{ pkgs, inputs, ... }:

let
  # Pacote exposto pelo flake do m3shapes (input já adicionado no flake.nix).
  m3shapesPkg = inputs.m3shapes.packages.${pkgs.system}.default;
in
{
  environment.systemPackages = [ m3shapesPkg ];

  # O pacote não se funde na árvore do Qt (fica no próprio /nix/store/...),
  # então o QML2_IMPORT_PATH precisa apontar pra lá explicitamente pra
  # "import M3Shapes" resolver no quickshell.
  environment.sessionVariables.QML2_IMPORT_PATH = [
    "${m3shapesPkg}/${pkgs.qt6.qtbase.qtQmlPrefix}"
  ];
}
