# Local AI: NInfer serving an abliterated Qwen3.8-27B on the RTX 5090.
#
# Replaces the Ollama setup this file grew out of. The trade is deliberate:
# NInfer is written for this exact GPU and gives a 200k context, but it serves
# exactly one model and is built from source on this machine. See docs/ai.md.
{ pkgs, ... }:

let
  ninfer = pkgs.callPackage ./pkgs/ninfer.nix { };

  # The client for the local model. Claude Code can't fill this role: it
  # implements Anthropic's *platform*, while NInfer implements only the wire
  # format, so every hosted feature 400s — the effort vocabulary, server-side
  # web_search, and thinking.display='omitted' all did. omp speaks
  # openai-completions instead and runs web_search client-side, so the local
  # model gains search rather than losing it. ~/.omp config is in home.nix.
  omp = pkgs.callPackage ./pkgs/omp.nix { };

  # Qwen3.8-27B NVFP4 with the refusal directions removed (huihui-ai's
  # abliteration of the base weights, converted to a .ninfer artifact by a
  # third party). Apache-2.0, like the official checkpoints.
  #
  # Checksum is the one published in the repo's SHA256SUMS, repeated in its
  # BUILD_MANIFEST.json. Bump both together.
  modelRepo = "lyf/Qwen3.8-27B-Huihui-Abliterated-NInfer-NVFP4";
  modelSha256 = "f21f308d3b23ccd627071cd015e413db08deee4356643900518e2b251750fdc2";

  stateDir = "/var/lib/ninfer";
  downloaded = "${stateDir}/qwen3_8_27b_nvfp4.v2.ninfer";
  modelPath = "${stateDir}/qwen3_8_27b_nvfp4.ninfer";

  # Public HTTP name, pinned so clients don't depend on whatever name is stored
  # inside the artifact. Purely an alias; it selects no behaviour. Must match
  # the model id in config/omp/models.yml.
  modelId = "qwen3.8-27b";
  port = 8080;
in
{
  # `ninfer-serve --help`, and the one-shot `ninfer` CLI for poking at an
  # artifact. Note the CLI loads its own copy of the weights, so stop the
  # service first or the two fight over VRAM.
  environment.systemPackages = [ ninfer omp ];

  users.users.ninfer = {
    isSystemUser = true;
    group = "ninfer";
    home = stateDir;
    description = "NInfer inference server";
  };
  users.groups.ninfer = { };

  # Fetched into /var/lib/ninfer rather than the Nix store on purpose: a store
  # fetch would stall every nixos-rebuild switch — and so every comin deploy —
  # behind a 20 GiB download. This runs in the background instead, the way
  # Ollama's loadModels used to, and is a no-op once the model is in place.
  #
  # The published artifact is a v2 container and the current engine only loads
  # v3, so it gets upgraded here with upstream's own offline tool. That tool
  # stamps a fresh uuid4 into every output, so the result is not reproducible
  # byte-for-byte and there is nothing to pin a checksum against. Integrity
  # therefore rests on the *downloaded* file, which is verified below, plus the
  # pinned NInfer commit the upgrade tool comes from.
  systemd.services.ninfer-model = {
    description = "Download and upgrade the NInfer model artifact";
    # A permanent failure (a stale modelSha256, say) should end up in
    # `systemctl --failed`, not retry a 20 GiB download forever.
    startLimitIntervalSec = 6 * 3600;
    startLimitBurst = 10;
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.curl pkgs.coreutils ninfer.upgradeTool ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "ninfer";
      Group = "ninfer";
      StateDirectory = "ninfer";
      # A 20 GiB download followed by a 20 GiB rewrite; systemd must not give
      # up on either.
      TimeoutStartSec = "infinity";
      # Back off 60s → 10m over five failures: a boot-time race against
      # network-online.target still recovers in a minute, while a network that
      # stays down is retried every 10 minutes instead of every minute.
      Restart = "on-failure";
      RestartSec = "60s";
      RestartSteps = 5;
      RestartMaxDelaySec = "10m";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };

    script = ''
      set -euo pipefail

      expected=${modelSha256}
      stamp=${stateDir}/.verified

      # The stamp records the checksum of the download the live artifact was
      # built from, so neither the 20 GiB hash nor the upgrade is repeated on
      # every boot.
      if [ -e ${modelPath} ] && [ "$(cat "$stamp" 2>/dev/null)" = "$expected" ]; then
        echo "Model already present and verified."
        exit 0
      fi

      if [ ! -e ${downloaded} ]; then
        echo "Downloading the abliterated artifact (20 GiB, resumable)..."
        curl --fail --location --retry 5 --retry-delay 10 \
          --continue-at - \
          --output ${downloaded}.part \
          "https://huggingface.co/${modelRepo}/resolve/main/qwen3_8_27b_nvfp4.ninfer"

        echo "Verifying checksum..."
        actual=$(sha256sum ${downloaded}.part | cut -d' ' -f1)
        if [ "$actual" != "$expected" ]; then
          echo "checksum mismatch: got $actual, expected $expected" >&2
          rm -f ${downloaded}.part
          exit 1
        fi
        mv ${downloaded}.part ${downloaded}
      fi

      # Needs room for both copies at once, writes its temporaries next to the
      # output, and refuses to start if any target already exists — so a failed
      # run has to be swept up before retrying. The glob covers the extra parts
      # it would emit for an artifact above its 32 GB single-file limit.
      echo "Upgrading the v2 container to v3..."
      rm -f ${modelPath}.part*
      ninfer-upgrade-v2-to-v3 ${downloaded} ${modelPath}.part
      mv ${modelPath}.part ${modelPath}

      printf '%s\n' "$expected" > "$stamp"

      # 20 GiB that is only ever needed again if the upgrade tool changes, and
      # re-downloading is cheaper than keeping it.
      rm -f ${downloaded}
      echo "Model ready."
    '';
  };

  systemd.services.ninfer = {
    description = "NInfer inference server (abliterated Qwen3.8-27B NVFP4)";
    wantedBy = [ "multi-user.target" ];
    after = [ "ninfer-model.service" ];
    requires = [ "ninfer-model.service" ];

    serviceConfig = {
      # This artifact carries text, vision, MTP and the optimized proposal head
      # (text/draft_head), but no DFlash2 — so MTP3 is the speculative mode.
      # 204800 is the context its publisher validated on a 32 GB 5090; the
      # official artifact's 240000 does not leave room here.
      ExecStart = ''
        ${ninfer}/bin/ninfer-serve ${modelPath} \
          --host 127.0.0.1 \
          --port ${toString port} \
          --model-id ${modelId} \
          --max-context 204800 \
          --kv-capacity 204800 \
          --max-concurrency 2 \
          --kv-dtype fp8 \
          --device-state-slots 2 \
          --spec mtp --draft-tokens 3 \
          --lm-head-draft \
          --preserve-thinking \
          --chat-template ${ninfer.chatTemplate}
      '';

      User = "ninfer";
      Group = "ninfer";
      StateDirectory = "ninfer";
      Restart = "on-failure";
      RestartSec = "10s";

      # It pins 8 GiB+ of host memory for KV and pause snapshots; the systemd
      # default of 8 MiB would fail the allocation outright.
      LimitMEMLOCK = "infinity";
      LimitNOFILE = 65536;

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      # No syscall filter: CUDA and liburing both need more than @system-service
      # reliably allows, and the endpoint is bound to localhost anyway.
    };
  };
}
