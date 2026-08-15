{ nixos-hardware, ... }:

{
  imports = [
    # Arquivo gerado por `nixos-generate-config` para discos e filesystems.
    # Copie-o para a raiz e descomente esta linha antes da primeira instalação.
    # ./hardware-configuration.nix

    ./modules/boot.nix
    ./modules/desktop.nix
    ./modules/users.nix
    ./modules/packages.nix
    
    # Driver NVIDIA ativo neste perfil. Comente esta linha em máquinas sem NVIDIA.
    ./modules/nvidia.nix

    # Perfil oficial do ThinkPad T495; descomente ao usar esse notebook.
    # nixos-hardware.nixosModules.lenovo-thinkpad-t495
  ];

  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Sao_Paulo";

  # Microcode para processadores Ryzen/AMD; deixe ativo no ThinkPad T495.
  hardware.cpu.amd.updateMicrocode = true;

  # Microcode do Intel.
  # hardware.cpu.intel.updateMicrocode = true;

  system.stateVersion = "26.05";
}
