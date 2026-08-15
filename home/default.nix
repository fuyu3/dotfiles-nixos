{ pkgs, lib, ... }:

{

  home.username = "fuyu";

  home.homeDirectory = "/home/fuyu";

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.git.enable = true;

  programs.fish.enable = true;

  home.packages = with pkgs; [

    kitty
    btop
    cava
    fastfetch
    wallust
    quickshell

  ];

  # Os dotfiles são aplicados somente depois que `home/dotfiles` existir.
  # Isso permite avaliar a configuração mesmo antes de adicioná-los ao repositório.
  xdg.configFile = lib.optionalAttrs (builtins.pathExists ./dotfiles) {
    "hypr".source = ./dotfiles/hypr;
    "kitty".source = ./dotfiles/kitty;
    "fish".source = ./dotfiles/fish;
    "fastfetch".source = ./dotfiles/fastfetch;
    "btop".source = ./dotfiles/btop;
    "cava".source = ./dotfiles/cava;
    "wallust".source = ./dotfiles/wallust;
    "quickshell".source = ./dotfiles/quickshell;
  };

}
