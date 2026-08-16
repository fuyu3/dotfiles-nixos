{ ... }:

{

  networking.hostName = "nixos-pc";

  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  networking.firewall.enable = true;

}
