{ ... }:

{

  boot.loader.grub = {
    enable = true;
    devices = [ "nodev" ];
    efiSupport = true;
    useOSProber = true;

    # Define a resolução do menu de boot do GRUB.
    gfxmodeEfi = "1920x1080x32";     
  };

  # Permite criar e atualizar a entrada de boot na partição EFI.
  boot.loader.efi.canTouchEfiVariables = true;

}
