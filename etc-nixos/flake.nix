{
  description = "Fuyu's NixOS Configuration";

  inputs = {
    # Canal principal do NixOS usado por todos os módulos.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager configura os programas e arquivos do usuário fuyu.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Perfis mantidos pela comunidade para hardware específico, como o T495.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dotfiles pessoais moram fora de /etc/nixos (/home/fuyu/dotfiles).
    # Precisam ser registrados como input de flake -- e não importados por
    # caminho absoluto solto no código -- porque flakes avaliam em "modo
    # puro" por padrão, e um `import /home/fuyu/...` direto é bloqueado
    # nesse modo ("access to absolute path is forbidden in pure evaluation
    # mode"). Como flake input, o Nix busca o diretório e o registra no
    # flake.lock, e a avaliação continua pura.
    dotfiles = {
      url = "path:/home/fuyu/dotfiles";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, nixos-hardware, dotfiles, ... }:
  let
    system = "x86_64-linux";
  in {
    # Única configuração do repositório; use `.#default` no nixos-rebuild.
    nixosConfigurations.default =
      nixpkgs.lib.nixosSystem {

        inherit system;
        specialArgs = { inherit nixos-hardware; };

        modules = [

          # Configuração principal do sistema e seleção dos módulos locais.
          ./configuration.nix

          # Integra o Home Manager ao mesmo rebuild do NixOS.
          home-manager.nixosModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # Config pessoal do usuário mora fora de /etc/nixos, em
            # /home/fuyu/dotfiles, separada da config do sistema.
            home-manager.users.fuyu =
              import (dotfiles + "/home.nix");
          }

        ];
      };

  };
}
