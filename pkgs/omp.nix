# oh-my-pi (omp): a coding agent with 60+ providers, built-in client-side
# web_search, and LSP/DAP wired in. https://github.com/can1357/oh-my-pi (MIT)
#
# Stencil Labs' fork of Pi (github.com/badlogic/pi-mono).
#
# This packages the *published release binary* rather than building from
# source, deliberately. Upstream ships a flake, but consuming it would mean:
#   - 2076 derivations built locally (~4 GiB) on every bump, because omp is in
#     no public binary cache — nix-community.cachix.org 404s on it;
#   - a second nixpkgs in the closure, since their flake pins nixos-unstable
#     while everything here follows one nixos-26.05;
#   - a third-party flake input that Renovate would bump unattended into a
#     machine comin auto-deploys.
# A hash-pinned fetchurl avoids all three, and avoids the `curl | sh`
# installer that this repo's rules forbid. The tradeoff is trusting a prebuilt
# binary, the same trust already extended to _1password-cli and vscode.
#
# To bump: set version, then
#   nix-prefetch-url https://github.com/can1357/oh-my-pi/releases/download/v<version>/omp-linux-x64
#   nix hash convert --to sri --hash-algo sha256 <hash>
# and cross-check against SHA256SUMS.txt in the same release. Renovate does not
# watch this (it only tracks flake.lock and GitHub Actions), so bumps are manual.
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "omp";
  version = "18.12.6";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-linux-x64";
    # Matches SHA256SUMS.txt for this release:
    # 85d9daf3a05fc76e8cd425ae1904eb576af8d21cc85fcf4690742626e07ccfa4
    hash = "sha256-hdna86Bfx26M1CWuGQTrV2r40hzIX89GkHQmJuB8z6Q=";
  };

  # A single 244 MB executable, not an archive.
  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  # DT_NEEDED is glibc only (libc, libpthread, libdl, libm), all of which
  # stdenv already provides, so there are no buildInputs to add.
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/omp"
    runHook postInstall
  '';

  # It is a Bun single-file executable: the JS payload is appended after the
  # ELF image and located from the file tail. Stripping rewrites the binary and
  # loses that payload, so leave it alone.
  dontStrip = true;

  meta = {
    description = "Coding agent with the IDE wired in (Stencil Labs' fork of Pi)";
    homepage = "https://omp.sh";
    downloadPage = "https://github.com/can1357/oh-my-pi/releases";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
