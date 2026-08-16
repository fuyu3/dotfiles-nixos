{ nixos-hardware, pkgs, ... }:

{
  imports = [
    # Arquivo gerado por `nixos-generate-config` para discos e filesystems.
    # Copie-o para a raiz antes da primeira instalação.
    ./hardware-configuration.nix

    ./modules/boot.nix
    ./modules/hardware.nix
    ./modules/connections.nix
    ./modules/desktop.nix
    ./modules/users.nix
    ./modules/packages.nix
    ./modules/audio.nix
    ./modules/fonts.nix

    # Driver NVIDIA ativo neste perfil. Comente esta linha em máquinas sem NVIDIA.
    ./modules/nvidia.nix

    # Perfil oficial do ThinkPad T495.
    # nixos-hardware.nixosModules.lenovo-thinkpad-t495
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "America/Sao_Paulo";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  system.stateVersion = "26.05";
}
