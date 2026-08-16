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

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nixos-hardware, spicetify-nix, ... }:
  let
    system = "x86_64-linux";
  in {
    # Única configuração do repositório; use `.#default` no nixos-rebuild.
    nixosConfigurations.default =
      nixpkgs.lib.nixosSystem {

        inherit system;
        specialArgs = { inherit nixos-hardware spicetify-nix; };

        modules = [

          # Configuração principal do sistema e seleção dos módulos locais.
          ./configuration.nix

          # Integra o Home Manager ao mesmo rebuild do NixOS.
          home-manager.nixosModules.home-manager

          # Fornece o módulo declarativo que cria o Spotify já modificado.
          spicetify-nix.nixosModules.spicetify

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";

            # home.nix mora na mesma árvore do flake agora (raiz do repo),
            # então importa por caminho relativo -- sem input de flake
            # separado, sem git+file://, sem os problemas de path: que a
            # gente teve enquanto isso vivia fora de /etc/nixos.
            home-manager.users.fuyu = import ./home.nix;
          }

        ];
      };

  };
}
