{ nixos-hardware, pkgs, inputs, ... }:

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
    ./modules/qt-modules.nix

    # Tema do SDDM
    inputs.silentSDDM.nixosModules.default

    # Perfil oficial do ThinkPad T495.
    nixos-hardware.nixosModules.lenovo-thinkpad-t495
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "America/Sao_Paulo";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  services.xserver.xkb = {
    layout = "br";
    variant = "thinkpad";
  };
  
  i18n.defaultLocale = "pt_BR.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };
  
  system.stateVersion = "26.05";
}
