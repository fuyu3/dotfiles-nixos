{ ... }:

{

  # SDDM inicia a sessão gráfica; Hyprland é o compositor Wayland escolhido.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = false;
  
  # Necessário para o SDDM iniciar a sessão gráfica.
  services.xserver.enable = true;
  
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Necessário para aceleração gráfica (OpenGL/Vulkan) no Wayland/Hyprland.
  # O módulo programs.hyprland NÃO ativa isso sozinho (checado no código-fonte
  # do nixpkgs em nixos/modules/programs/wayland/hyprland.nix) — sem essa
  # linha o compositor sobe sem aceleração de hardware, ou nem sobe.
  # Renomeado de hardware.opengl.enable para hardware.graphics.enable no
  # NixOS 24.11; como este flake segue nixos-unstable, use graphics.
  hardware.graphics.enable = true;

  # Portais XDG permitem integração de arquivos, tela e permissões no Wayland.
  xdg.portal.enable = true;

  # Áudio moderno via PipeWire.
  services.pipewire.enable = true;

}
