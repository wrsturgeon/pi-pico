{
  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-analyzer-src = {
          flake = false;
          url = "github:rust-lang/rust-analyzer/nightly";
        };
      };
    };
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-filter.url = "github:numtide/nix-filter";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      fenix,
      flake-utils,
      naersk,
      nix-filter,
      nixpkgs,
      self,
    }:

    let

      name = "pi-pico";
      version = "0.1.0";

    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        env = {
          CARGO_BUILD_TARGET = "thumbv6m-none-eabi";
        };

        files = import ./files.nix { inherit name version; };
        write-files = pkgs.lib.strings.concatLines (
          builtins.attrValues (
            builtins.mapAttrs (
              filename: contents:
              let
                escaped-filename = "${pkgs.lib.strings.escapeShellArg "./${filename}"}";
              in
              ''
                mkdir -p ${escaped-filename}
                rm -fr ${escaped-filename}
                echo ${pkgs.lib.strings.escapeShellArg contents} > ${escaped-filename}
              ''
            ) files
          )
        );

        with-shebang = script: ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          shopt -s nullglob

          ${script}
        '';

      in
      {

        devShells.default = self.lib.${system}.shell;

        lib = {

          shell = pkgs.mkShell (
            {
              # packagesFrom = builtins.attrValues self.packages.${system};
              packages =
                [ self.lib.${system}.toolchain ]
                ++ (with pkgs; [
                  elf2uf2-rs
                  flip-link
                  probe-rs
                  rust-analyzer
                ]);
            }
            // env
          );

          toolchain =
            with fenix.packages.${system};
            combine (
              (with minimal; [
                cargo
                rustc
              ])
              ++ (with targets.${env.CARGO_BUILD_TARGET}.latest; [
                rust-std
              ])
            );

        };

        /*
          packages = {

            default =
              (naersk.lib.${system}.override {
                cargo = self.lib.${system}.toolchain;
                rustc = self.lib.${system}.toolchain;
              }).buildPackage
                (
                  {
                    inherit name version;
                    inherit (self.packages.${system}) src;
                  }
                  // env
                );

            src = pkgs.stdenvNoCC.mkDerivation (
              {
                pname = "${name}-src";
                inherit version;

                src = nix-filter {
                  root = ./.;
                  include = [ ./src ];
                };

                buildPhase = ":";
                installPhase = ''
                  mkdir -p $out
                  ls -A | xargs -I{} mv {} $out/
                  cd $out
                  ${write-files}
                '';
              }
              // env
            );

          };
        */

      }
    );
}
