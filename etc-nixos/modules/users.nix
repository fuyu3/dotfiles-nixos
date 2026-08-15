{ pkgs, ... }:

{

  # Conta principal do sistema e grupos necessários para administração e rede.
  users.users.fuyu = {

    isNormalUser = true;

    description = "Fuyu";

    extraGroups = [

      "wheel"
      "networkmanager"

    ];

    # Define Fish como shell de login; o Home Manager configura seus arquivos.
    shell = pkgs.fish;

  };

}
