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

    # Faz o Home Manager substituir configurações GTK pré-existentes, em vez
    # de interromper a ativação quando encontrar arquivos locais.
    gtk2.force = true;

    theme = {
      name = "Flat-Remix-GTK-Blue-Darkest-Solid";
      package = flatRemixGtk;
    };

    # A partir do stateVersion 26.05, GTK4 não herda o tema global. Declare-o
    # explicitamente para o Home Manager gerar (e poder sobrescrever) gtk.css.
    gtk4.theme = {
      name = "Flat-Remix-GTK-Blue-Darkest-Solid";
      package = flatRemixGtk;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  home.packages = with pkgs; [

    kitty
    btop
    cava
    fastfetch
    wallust
    quickshell

  ];

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  # Remova apenas os backups legados criados durante a migração da configuração
  # GTK; não afete arquivos .backup de outros aplicativos.
  home.activation.removeLegacyGtkBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f \
      "$HOME/.gtkrc-2.0.backup" \
      "$HOME/.config/gtk-3.0/settings.ini.backup" \
      "$HOME/.config/gtk-4.0/settings.ini.backup"
  '';

  # Os dotfiles são aplicados somente depois que `./config` existir.
  # Isso permite avaliar a configuração mesmo antes de adicioná-los ao repositório.
  xdg.configFile = {
    # GTK3/4 são gerados pelo módulo `gtk`. `force` garante que os arquivos
    # declarativos prevaleçam sobre configurações criadas manualmente ou por
    # outros programas. O módulo GTK4 já importa o CSS do tema selecionado.
    "gtk-3.0/settings.ini".force = true;
    "gtk-4.0/settings.ini".force = true;
    "gtk-4.0/gtk.css".force = true;
  } // lib.optionalAttrs (builtins.pathExists ./config) {
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
