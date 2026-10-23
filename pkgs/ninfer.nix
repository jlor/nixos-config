# NInfer: a from-scratch C++/CUDA inference engine for a single RTX 5090.
# https://github.com/Neroued/ninfer (Apache-2.0)
#
# Not in nixpkgs, so the derivation lives here. Two things about it are unusual:
#
#  - It is RTX 5090-only by construction. CMakeLists.txt hard-rejects any
#    CMAKE_CUDA_ARCHITECTURES other than 120a, so this package dies the day the
#    GPU changes. nixpkgs' cudaCapabilities doesn't model the "a" suffix, which
#    is why the architecture goes in as a raw cmake flag.
#  - There is no binary cache for it. 564 CUDA/C++ translation units get built
#    locally on every bump of this file or of cudaPackages.
{ lib
, fetchFromGitHub
, runCommand
, cmake
, ninja
, pkg-config
, autoAddDriverRunpath
, cudaPackages_13_1
, ffmpeg
, hwloc
, liburing
, curl
, python311
}:

let
  # Upstream validates on CUDA 13.4 but builds its own container on 13.1, and
  # 13.1 is the newest complete set in nixos-26.05: cudaPackages_13_3.cuda_cccl
  # evaluates as "0-unsupported". sm_120a needs >= 12.8 either way.
  cudaPackages = cudaPackages_13_1;
in
cudaPackages.backendStdenv.mkDerivation (finalAttrs: {
  pname = "ninfer";
  # No tags and no releases upstream, so pin a commit. Bumping it means a long
  # local CUDA rebuild, so it is deliberately manual: renovate.json only tracks
  # flake.lock and GitHub Actions, and neither sees this rev.
  version = "0-unstable-2026-10-16";

  src = fetchFromGitHub {
    owner = "Neroued";
    repo = "ninfer";
    rev = "64d10fbf9f8e6bfc79ab0570b94674c5b9997929";
    hash = "sha256-vwCnXyQPR6xY0r3JEg53EuHQkd4WbnKsNTvBtrL7LxM=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    cudaPackages.cuda_nvcc
    # Puts /run/opengl-driver/lib on the RUNPATH so the real libcuda.so.1 from
    # the Nvidia driver is found at runtime, not the stub we link against.
    autoAddDriverRunpath
  ];

  buildInputs = [
    cudaPackages.cuda_cudart # CUDA::cudart, and the libcuda stub for CUDA::cuda_driver
    cudaPackages.cuda_cccl # Thrust/CUB headers
    cudaPackages.cuda_nvtx # CUDA::nvtx3
    ffmpeg # libavformat, libavcodec, libavutil, libswscale
    hwloc
    liburing
    curl
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "120a")
    (lib.cmakeBool "NINFER_BUILD_APPS" true)
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "NINFER_BUILD_BENCHMARKS" false)
  ];

  # FindCUDAToolkit expects the libcuda stub under <toolkit>/lib64/stubs; with
  # nixpkgs' split CUDA packages it sits in cuda_cudart's own lib/stubs.
  env.NVCC_PREPEND_FLAGS = "-L${lib.getLib cudaPackages.cuda_cudart}/lib/stubs";

  # The server and the CLI are the products; tests and benchmarks are off above.
  ninjaFlags = [ "ninfer" "ninfer-serve" ];

  # Upstream ships no install target: "run NInfer from its source build tree".
  installPhase = ''
    runHook preInstall
    install -Dm755 apps/ninfer apps/ninfer-serve -t "$out/bin"
    runHook postInstall
  '';

  # nixpkgs' ld wrapper turns every -L into a RUNPATH entry, which would leave
  # the libcuda stub ahead of the real driver and break at load time. This runs
  # after autoAddDriverRunpath, so the driver entry it added survives.
  postFixup = ''
    for bin in "$out"/bin/*; do
      kept=$(patchelf --print-rpath "$bin" | tr ':' '\n' | grep -v '/lib/stubs$' | paste -sd: -)
      patchelf --set-rpath "$kept" "$bin"
    done
  '';

  # The v2->v3 container upgrade ai.nix needs for the third-party artifact.
  # Kept out of the main derivation deliberately: passthru is not part of the
  # derivation hash, so adding this tool doesn't invalidate the CUDA build.
  passthru.upgradeTool =
    runCommand "ninfer-upgrade-v2-to-v3" { } ''
      install -Dm755 ${finalAttrs.src}/tools/upgrade_ninfer_v2_to_v3.py \
        "$out/libexec/ninfer/upgrade_ninfer_v2_to_v3.py"
      substituteInPlace "$out/libexec/ninfer/upgrade_ninfer_v2_to_v3.py" \
        --replace-fail '#!/usr/bin/env python3' '#!${python311.interpreter}'

      # It installs the maintained chat template from a path relative to its own
      # resolved location, so the tree has to stay next to it. The bin entry is
      # a symlink because the script calls Path(__file__).resolve().
      cp -r ${finalAttrs.src}/tools/chat_templates \
        "$out/libexec/ninfer/chat_templates"
      mkdir -p "$out/bin"
      ln -s "$out/libexec/ninfer/upgrade_ninfer_v2_to_v3.py" \
        "$out/bin/ninfer-upgrade-v2-to-v3"
    '';

  meta = {
    description = "Single-GPU C++/CUDA inference engine for Qwen checkpoints on an RTX 5090";
    homepage = "https://github.com/Neroued/ninfer";
    license = lib.licenses.asl20;
    mainProgram = "ninfer-serve";
    platforms = [ "x86_64-linux" ];
  };
})
