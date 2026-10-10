{
  description = "Project dev shell";

  # nixos-unstable has the newest tool versions. flake.lock pins the exact
  # revision, so everyone on the project gets the same versions.
  # Update them with: nix flake update
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # Add the tools this project needs
          packages = with pkgs; [
            # e.g. nodejs_24, jdk21, python313, go, terraform, kubectl
          ];
        };
      });
    };
}
