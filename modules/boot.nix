{ ... }:

{

  # Usa systemd-boot em instalações UEFI.
  boot.loader.systemd-boot.enable = true;

  # Permite criar e atualizar a entrada de boot na partição EFI.
  boot.loader.efi.canTouchEfiVariables = true;

}
