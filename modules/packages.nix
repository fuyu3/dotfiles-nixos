{ pkgs, ... }:

{

  # Ferramentas disponíveis globalmente para todos os usuários do sistema.
  environment.systemPackages = with pkgs; [

    git
    vim
    wget
    curl

  ];

}
