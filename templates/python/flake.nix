{
  description = "Python dev shell";

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
          # Python 3.13 + uv + ruff
          packages = with pkgs; [
            python313
            uv
            ruff
          ];

          # Let uv manage the virtualenv but use Nix's Python
          UV_PYTHON_DOWNLOADS = "never";
        };
      });
    };
}
