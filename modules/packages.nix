{ pkgs, spicetify-nix, ... }:

let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {

  # Ferramentas disponíveis globalmente para todos os usuários do sistema.
  environment.systemPackages = with pkgs; [

    awww
    bc
    bibata-cursors
    btop
    btrfs-progs
    cava
    chafa
    cliphist
    (discord.override {
      withVencord = true;
    })
    e2fsprogs
    fastfetch
    gamescope
    gnome-calculator
    gnome-characters
    gnome-disk-utility
    gnome-keyring
    gnome-system-monitor
    gnome-text-editor
    grim
    goverlay
    hypridle
    hyprpicker
    hyprpolkitagent
    hyprshot
    imagemagick
    jq
    kitty
    krita
    less
    nautilus
    networkmanagerapplet
    nwg-look
    obsidian
    obs-studio
    papers
    papirus-icon-theme
    parsec-bin
    pavucontrol
    peaclock
    prismlauncher
    qbittorrent
    quickshell
    qt6.qt5compat
    smartmontools
    unzip
    virt-manager
    vscode
    wallust
    wl-clipboard
    wl-clip-persist
    
    git
    wget
    curl

  ];

  # O módulo instala o Spotify já modificado; não adicione pkgs.spotify acima.
  programs.spicetify = {
    enable = true;
    wayland = true;

    enabledExtensions = with spicePkgs.extensions; [
      adblockify
    ];

    theme = spicePkgs.themes.catppuccin;
    colorScheme = "mocha";
  };

  environment.variables = {
    QML_IMPORT_PATH = 
      "${pkgs.qt6.qt5compat}/lib/qt-6/qml";

    QML2_IMPORT_PATH =  
      "${pkgs.qt6.qt5compat}/lib/qt-6/qml";
  };

  # services.clamav.daemon.enable = true;
  # services.clamav.updater.enable = true;

  programs.fish.enable = true;

  services.power-profiles-daemon.enable = true;

  services.flatpak.enable = true;

  programs.steam.enable = true;

  programs.virt-manager.enable = true;

  virtualisation.libvirtd.enable = true;

  programs.firefox.enable = true;

}
