# AI

Claude Code, plus a local model on the 5090. Configured in `ai.nix`
(the server and the model) , `pkgs/ninfer.nix` (the engine) and `home.nix`.

- **Claude Code:** `claude` (log in on first run).
- **Local model:** [NInfer](https://github.com/Neroued/ninfer) serves an
  abliterated Qwen3.8-27B NVFP4 on the 5090. It's an inference engine written
  for this exact GPU, so it's two to three times faster than Ollama was and runs
  a 204,800-token context instead of 64k.
  - `claude-local` runs Claude Code against it. NInfer implements Anthropic's
    `/v1/messages` natively — tools, streaming and token counting included — so
    this is a real backend rather than a translation layer.
    `CLAUDE_LOCAL_MODEL=<id> claude-local` picks another id.
  - For a plain chat, talk to the server directly:
    ```bash
    curl http://127.0.0.1:8080/v1/chat/completions \
      -H 'Content-Type: application/json' \
      -d '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"hello"}],"max_tokens":256}'
    ```
  - `systemctl status ninfer` shows the server, `curl localhost:8080/health` its
    readiness, and `GET /v1/models` the model id and effective context length.
  - Local models are far weaker than Claude at multi-step coding; good for offline
    use, quick questions and privacy-sensitive code.

## The model

[huihui-ai's abliteration](https://huggingface.co/huihui-ai/Huihui-Qwen3.8-27B-abliterated)
of Qwen3.8-27B — the refusal directions removed from the base weights — converted
to a `.ninfer` artifact by a third party and published as
`lyf/Qwen3.8-27B-Huihui-Abliterated-NInfer-NVFP4`. Apache-2.0, like the official
checkpoints. Abliteration also costs some instruction-following accuracy, which
is the part that shows up when driving an agent loop rather than chatting.

`ninfer-model.service` downloads it in the background after the first boot and
verifies it against the checksum published in the repo's `SHA256SUMS`. The
download is resumable and the unit is a no-op once the model is in place, so a
failed download just retries. `journalctl -fu ninfer-model` follows it; until it
finishes, `ninfer.service` sits in `activating` — expected, not a hang.

Budget roughly 40 GiB of free space while it runs: the published file is a **v2**
container and the current engine only loads v3, so the unit upgrades it with
upstream's own `upgrade_ninfer_v2_to_v3.py` and both copies exist briefly. The v2
download is deleted afterwards.

That upgrade is the one place this setup falls short of the repo's usual
reproducibility: the tool stamps a fresh `uuid4` into every output, so the result
is not byte-for-byte reproducible and there is no checksum to pin it against.
Integrity rests on the *downloaded* file, which is verified, plus the pinned
NInfer commit the tool comes from. The upgrade is gated on
`(model_id, weights_id)` and object count — this artifact reports
`qwen3.8-27b` / `nvfp4` / 1124 objects, which is a combination the tool accepts.

The artifact carries text (773 tensors), vision (333), MTP (12) and the
optimized proposal head, but no DFlash2 — so `ai.nix` runs
`--spec mtp --draft-tokens 3 --lm-head-draft`. Vision is off, because it has to
be chosen at startup and costs VRAM; add `--vision` to `ExecStart` for image and
video prompts.

NInfer serves exactly one resident model per process, so unlike Ollama there's no
pulling another one on a whim. Swapping means editing `ai.nix` and
re-downloading; the official (non-abliterated) artifacts are at
`neroued/Qwen3.8-27B-nvfp4-NInfer` and friends, are already v3, and additionally
carry DFlash2.

## Building it

NInfer isn't in nixpkgs, so `pkgs/ninfer.nix` builds it from a pinned commit.
Two consequences worth knowing:

- **No binary cache.** 564 CUDA/C++ translation units compile on this machine,
  which takes a while. It happens when `pkgs/ninfer.nix` changes or when
  `cudaPackages_13_1` moves under it — including via a Renovate lock bump, which
  lands unattended through comin. The CUDA *toolkit* itself still comes from
  `cache.nixos-cuda.org`; only NInfer is built locally. The Python upgrade tool
  hangs off `passthru`, which is outside the derivation hash, so touching it
  doesn't trigger a rebuild.
- **It is 5090-only by construction.** Upstream's CMake rejects any CUDA
  architecture other than `sm_120a`, so the package stops building the day the
  GPU changes.

Upstream has no tags or releases, so the commit in `pkgs/ninfer.nix` is bumped by
hand; Renovate doesn't watch it. To bump: set `rev`, run
`nix-prefetch-url --unpack https://github.com/Neroued/ninfer/archive/<rev>.tar.gz`,
convert with `nix hash convert --to sri --hash-algo sha256 <hash>`, and check
upstream's artifact format hasn't moved — it already broke v2 once, and this
model depends on the upgrade tool continuing to accept it.

CUDA 13.1 is pinned rather than the newest available: upstream builds its own
container on 13.1, and `cudaPackages_13_3` is incomplete in nixos-26.05
(`cuda_cccl` evaluates as `0-unsupported`).

## The CLI

`ninfer` (one-shot) and `ninfer-serve` are on `PATH`. The CLI loads its own copy
of the weights, so stop the service first:

```bash
sudo systemctl stop ninfer
ninfer /var/lib/ninfer/qwen3_8_27b_nvfp4.ninfer \
  --prompt "Explain prefill and decode." --max-context 32768 --max-new 2048
```
