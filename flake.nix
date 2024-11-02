{
  description = "nftools的linux下nix开发环境";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  };

  outputs = { self , nixpkgs ,... }: let
    # system should match the system you are running on
     system = "x86_64-linux";
  in {
    devShells."${system}".default = let
      pkgs = import nixpkgs {
        inherit system;
      };
    in pkgs.mkShell {
        packages = with pkgs; [
            fish
        ];
       nativeBuildInputs = [ pkgs.pkg-config pkgs.cmake ];
       buildInputs = [ pkgs.libayatana-appindicator ];

      shellHook = ''
        exec fish
      '';
    };
  };
}