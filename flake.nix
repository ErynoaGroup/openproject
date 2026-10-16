{
  description = "RagFit | Plan — Project Management, WorkPackages, Sprints & TimeEntries Service (Layer 3 Domain Core)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
            };
          in
          f { inherit pkgs; }
        );
    in
    {
      packages = forEachSupportedSystem (
        { pkgs, ... }:
        let
          ragfitPlanEntrypoint = pkgs.writeShellScriptBin "ragfit-plan-entrypoint" ''
            set -euo pipefail
            export RAILS_ENV="''${RAILS_ENV:-production}"
            export PORT="''${PORT:-8080}"
            export MALLOC_ARENA_MAX="''${MALLOC_ARENA_MAX:-2}"
            if [ "''${1:-}" = "--version" ]; then
              echo "ragfit-plan (OpenProject GPLv3 runtime layer)"
              exit 0
            fi
            exec "${pkgs.bashInteractive}/bin/bash" "$@"
          '';

          brandAndNoticeLayer = pkgs.runCommand "ragfit-plan-runtime-layer" { } ''
            mkdir -p $out/usr/share/doc/ragfit-plan $out/app/ragfit/brand $out/app/public/erynoa
            cp ${./LICENSE} $out/usr/share/doc/ragfit-plan/LICENSE
            cp ${./COPYRIGHT} $out/usr/share/doc/ragfit-plan/COPYRIGHT
            cp ${./COPYRIGHT_short} $out/usr/share/doc/ragfit-plan/COPYRIGHT_short
            cp ${./CHANGES-RAGFIT.md} $out/usr/share/doc/ragfit-plan/CHANGES-RAGFIT.md
            cp -r ${./ragfit/brand}/* $out/app/ragfit/brand/
            cp -r ${./public/erynoa}/* $out/app/public/erynoa/
          '';

          container = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/erynoagroup/ragfit-plan";
            tag = "latest";
            contents = [
              pkgs.cacert
              pkgs.tzdata
              pkgs.bashInteractive
              pkgs.curl
              pkgs.coreutils
              ragfitPlanEntrypoint
              brandAndNoticeLayer
            ];
            config = {
              User = "1000:1000";
              WorkingDir = "/app";
              ExposedPorts = {
                "8080/tcp" = { };
              };
              Env = [
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "TZDIR=${pkgs.tzdata}/share/zoneinfo"
                "RAILS_ENV=production"
                "PORT=8080"
                "MALLOC_ARENA_MAX=2"
              ];
              Entrypoint = [ "${ragfitPlanEntrypoint}/bin/ragfit-plan-entrypoint" ];
              Labels = {
                "org.opencontainers.image.title" = "RagFit | Plan";
                "org.opencontainers.image.description" = "Lightweight rootless Nix OCI runtime container for RagFit | Plan (Layer 3 Domain Core)";
                "org.opencontainers.image.vendor" = "ErynoaGroup";
                "org.opencontainers.image.licenses" = "GPL-3.0-only";
              };
            };
          };
        in
        {
          inherit container;
          image = container;
          default = container;
        }
      );

      devShells = forEachSupportedSystem (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "ragfit-plan";
            packages = with pkgs; [
              ruby_3_4
              nodejs_22
              just
              jq
              git
              postgresql
            ];
          };
        }
      );
    };
}
