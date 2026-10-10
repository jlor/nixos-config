{
  description = "Java dev shell";

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
          # JDK 21 LTS + Gradle + Maven
          packages = with pkgs; [
            jdk21
            gradle
            maven
          ];

          # Tools like IDEs and Gradle look for this
          JAVA_HOME = pkgs.jdk21.home;
        };
      });
    };
}
