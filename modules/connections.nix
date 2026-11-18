{ ... }:

{

  networking.hostName = "nixos-pc";

  networking.networkmanager.enable = true;

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };

  services.resolved.enable = true;

  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  networking.firewall.enable = true;

}
