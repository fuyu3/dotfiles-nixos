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

  # Os dotfiles são aplicados somente depois que `./config` existir.
  # Isso permite avaliar a configuração mesmo antes de adicioná-los ao repositório.
  xdg.configFile = lib.optionalAttrs (builtins.pathExists ./config) {
    "hypr".source = ./config/hypr;
    "kitty".source = ./config/kitty;
    "fish".source = ./config/fish;
    "fastfetch".source = ./config/fastfetch;
    "btop".source = ./config/btop;
    "cava".source = ./config/cava;
    "wallust".source = ./config/wallust;
    "quickshell".source = ./config/quickshell;
  };

}
