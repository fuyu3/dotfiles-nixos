{ pkgs, ... }:

{

  # Ferramentas disponíveis globalmente para todos os usuários do sistema.
  environment.systemPackages = with pkgs; [

    awww
    bibata-cursors
    btop
    btrfs-progs
    cava
    chafa
    discord
    fastfetch
    gamescope
    gnome-calculator
    gnome-characters
    gnome-disk-utility
    gnome-keyring
    gnome-system-monitor
    gnome-text-editor
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
    nwg-look
    obs-studio
    papers
    papirus-icon-theme
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
    
    git
    wget
    curl

  ];

  environment.variables = {
    QML_IMPORT_PATH = 
      "${pkgs.qt6.qt5compat}/lib/qt-6/qml";

    QML2_IMPORT_PATH =  
      "${pkgs.qt6.qt5compat}/lib/qt-6/qml";
  };

  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;

  programs.fish.enable = true;

  services.power-profiles-daemon.enable = true;

  services.flatpak.enable = true;

  programs.steam.enable = true;

  programs.virt-manager.enable = true;

  virtualisation.libvirtd.enable = true;

  programs.firefox.enable = true;

}
