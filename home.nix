{ pkgs, lib, ... }:

let
  flatRemixGtk = pkgs.stdenvNoCC.mkDerivation {
    pname = "flat-remix-gtk";
    version = "git-2026-08-16";

    src = pkgs.fetchFromGitHub {
      owner = "daniruiz";
      repo = "flat-remix-gtk";
      rev = "919494f4f4ede88e2efb45cd48b98db7cc23f6ee";
      hash = "sha256-EWe84bLG14RkCNbHp0S5FbUQ5/Ye/KbCk3gPTsGg9oQ=";
    };

    installPhase = ''
      mkdir -p "$out/share/themes"
      cp -r themes/Flat-Remix-GTK-Blue-Darkest-Solid "$out/share/themes/"
      rm "$out/share/themes/Flat-Remix-GTK-Blue-Darkest-Solid"/{install,uninstall}.sh
    '';
  };
in {

  home.username = "fuyu";

  home.homeDirectory = "/home/fuyu";

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.git.enable = true;

  programs.fish.enable = true;

  gtk = {
    enable = true;

    theme = {
      name = "Flat-Remix-GTK-Blue-Darkest-Solid";
      package = flatRemixGtk;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

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
