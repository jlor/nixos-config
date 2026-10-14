# Lists "name<TAB>version" for every package this desktop installs, both
# system-wide and in jlor's home.
#
# Evaluation only — nothing is built, so CI can afford to run it on both sides
# of a pull request. That's what makes it usable here: a full build of this
# machine (Nvidia, Steam, CUDA) is far too big for a free runner, but the
# version of every package is known at eval time.
#
# FLAKE_DIR selects which checkout to read, so the same expression can be
# pointed at a PR's base and head. Needs --impure for getFlake/getEnv.
let
  flake = builtins.getFlake (builtins.getEnv "FLAKE_DIR");
  config = flake.nixosConfigurations.desktop.config;

  home = config.home-manager.users.jlor.home.packages or [ ];
  packages = config.environment.systemPackages ++ home;

  # Fall back through pname -> name -> "?" so a package with an unusual
  # derivation still produces a line instead of failing the whole eval.
  line = p: "${p.pname or p.name or "?"}\t${p.version or "?"}";
in
builtins.concatStringsSep "\n" (map line packages)
