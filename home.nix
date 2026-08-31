{ pkgs, lib, config, ... }:

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

  # Symlink direto pro repo, fora do Nix store — mutável em runtime.
  dotfilesDir = "${config.home.homeDirectory}/dotfiles-nixos/config";
  outOfStore = name:
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${name}";
in {

  home.username = "fuyu";
  home.homeDirectory = "/home/fuyu";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  gtk = {
    enable = true;
    gtk2.force = true;
    theme = {
      name = "Flat-Remix-GTK-Blue-Darkest-Solid";
      package = flatRemixGtk;
    };
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
    enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  home.packages = with pkgs; [
    
  ];

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.activation.removeLegacyGtkBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f \
      "$HOME/.gtkrc-2.0.backup" \
      "$HOME/.config/gtk-3.0/settings.ini.backup" \
      "$HOME/.config/gtk-4.0/settings.ini.backup"
  '';

  xdg.configFile = {
    "gtk-3.0/settings.ini".force = true;
    "gtk-4.0/settings.ini".force = true;
    "gtk-4.0/gtk.css".force = true;
  } // lib.optionalAttrs (builtins.pathExists ./config) (
    lib.genAttrs
      [ "hypr" "kitty" "fish" "fastfetch" "btop" "cava" "wallust" "quickshell" ]
      (name: { source = outOfStore name; })
  );
}