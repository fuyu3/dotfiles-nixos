{ ... }:

{

  # Microcode para processadores Ryzen/AMD; deixe ativo no ThinkPad T495.
  hardware.cpu.amd.updateMicrocode = true;

  # Microcode do Intel.
  # hardware.cpu.intel.updateMicrocode = true;

  powerManagement.enable = true;

  services = {
    upower.enable = true;
    acpid.enable = true;

    tlp = {
      enable = true;

      settings = {
        # Processador
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        # Saúde da bateria
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;

        # Economia de energia
        WIFI_PWR_ON_BAT = "on";
        USB_AUTOSUSPEND = 1;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    acpi
    powertop
    brightnessctl
  ];

}



