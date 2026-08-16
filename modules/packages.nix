{ pkgs, ... }:

{

  # Ferramentas disponíveis globalmente para todos os usuários do sistema.
  environment.systemPackages = with pkgs; [

    awww
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
    gnome-system-monitor
    gnome-text-editor
    goverlay
    hypridle
    hyprpicker
    hyprpolkitagent
    hyprshot
    imagemagick
    kitty
    krita
    less
    nautilus
    obs-studio
    papers
    pavucontrol
    peaclock
    prismlauncher
    qbittorrent
    quickshell
    smartmontools
    systemsettings
    unzip
    virt-manager
    wallust
    xwaylandvideobridge
    
    git
    wget
    curl

  ];

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
