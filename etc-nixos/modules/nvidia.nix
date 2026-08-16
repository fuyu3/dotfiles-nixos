{ config, ... }:

{
  # Ativa o driver proprietário NVIDIA.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Usa a versão estável compatível com o kernel selecionado.
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # DRM Kernel Mode Setting é recomendado para Wayland/Hyprland.
    modesetting.enable = true;

    # Gerenciamento de energia da GPU.
    powerManagement.enable = true;

    # Usa o módulo proprietário, não o módulo NVIDIA aberto.
    open = false;
  };

  # Firmware redistribuível exigido por parte do hardware NVIDIA.
  hardware.enableRedistributableFirmware = true;

  # Ativa o suporte a Ollama 
  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };
}
