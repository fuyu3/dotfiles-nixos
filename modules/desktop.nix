{ ... }:

{

  # SDDM inicia a sessão gráfica; Hyprland é o compositor Wayland escolhido.
  services.displayManager.sddm.enable = true;

  programs.hyprland.enable = true;

  # Portais XDG permitem integração de arquivos, tela e permissões no Wayland.
  xdg.portal.enable = true;

  # Áudio moderno via PipeWire.
  services.pipewire.enable = true;

}
