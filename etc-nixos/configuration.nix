{ nixos-hardware, ... }:

{
  imports = [
    # Arquivo gerado por `nixos-generate-config` para discos e filesystems.
    # Copie-o para a raiz e descomente esta linha antes da primeira instalação.
    ./hardware-configuration.nix

    ./modules/boot.nix
    ./modules/hardware.nix
    ./modules/networking.nix
    ./modules/desktop.nix
    ./modules/users.nix
    ./modules/packages.nix

    # Driver NVIDIA ativo neste perfil. Comente esta linha em máquinas sem NVIDIA.
    ./modules/nvidia.nix

    # Perfil oficial do ThinkPad T495; descomente ao usar esse notebook.
    # nixos-hardware.nixosModules.lenovo-thinkpad-t495
  ];

  time.timeZone = "America/Sao_Paulo";

  system.stateVersion = "26.05";
}
