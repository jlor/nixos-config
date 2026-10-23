# AI

Two agents, two backends: **Claude Code against Anthropic** for real work, and
**omp against a local model on the 5090** for offline, private or idle-curiosity
work. Configured in `ai.nix` (the server, the model, both clients),
`pkgs/ninfer.nix` (the engine), `pkgs/omp.nix` (the local client) and `home.nix`
(omp's provider list).

- **Claude Code:** `claude` (log in on first run). Anthropic's API only — see
  "Why not Claude Code locally" below.
- **omp:** `omp` ([oh-my-pi](https://github.com/can1357/oh-my-pi)) for the local
  model. `omp` for a session, `omp -p "..."` for one shot,
  `omp --model ninfer/qwen3.8-27b` to force the local provider, `omp models ninfer`
  to check discovery. Its `web_search` runs client-side, so the local model can
  still search the web.
- **The engine:** [NInfer](https://github.com/Neroued/ninfer) serves an
  abliterated Qwen3.8-27B NVFP4. Written for this exact GPU, so it's two to three
  times faster than Ollama was, with a 204,800-token context instead of 64k.
  - `systemctl status ninfer` shows the server, `curl localhost:8080/health` its
    readiness, and `GET /v1/models` the model id and effective context length.
  - For a plain chat without a client:
    ```bash
    curl http://127.0.0.1:8080/v1/chat/completions \
      -H 'Content-Type: application/json' \
      -d '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"hello"}],"max_tokens":256}'
    ```
- Local models are far weaker than Claude at multi-step coding; good for offline
  use, quick questions and privacy-sensitive code.

## Why not Claude Code locally

There used to be a `claude-local` wrapper pointing Claude Code at NInfer. It was
removed because it could not be made to work: Claude Code implements Anthropic's
**platform**, while NInfer implements only the **wire format**. Every hosted
feature returns a 400, and they surface one at a time as Claude Code decides to
use them:

| Feature | Result |
|---|---|
| `output_config.effort: high` | Rejected by Qwen's chat template (see below) |
| `web_search_20250305` | *"requires its predefined prompt schema or server executor, which NInfer does not provide"* |
| `thinking.display: omitted` | *"requires encrypted hidden-reasoning restore semantics that NInfer does not provide"* |

Each needs a separate workaround, and there is no reason to think the list is
finished. omp avoids the whole class by speaking `openai-completions`.

## Reasoning effort is normalised

Qwen3.8's chat template accepts only `xhigh`/`medium`/`low` and **raises** on
anything else rather than clamping, so `pkgs/ninfer.nix` patches it and passes
it with `--chat-template`.

omp reaches the template via `chat_template_kwargs.reasoning_effort`, which
NInfer forwards verbatim. What it actually sends, captured off the wire — note
it clamps `xhigh`/`max` down to `high` itself:

| `omp --thinking=` | sends | mapped to |
|---|---|---|
| `minimal`, `off` | `minimal` | `low` |
| `low` | `low` | unchanged |
| `medium` | `medium` | unchanged |
| `high`, `xhigh`, `max`, `auto` (default) | `high` | `xhigh` |

Both mapped rungs come up in normal use — the default lands on `high`, and
`--thinking=off` lands on `minimal` — so without the patch omp fails on every
request out of the box.

`high` folds to `xhigh` because that is the template's own default, so an
explicit `high` behaves exactly like sending no effort at all. `max` is also
mapped but never actually emitted by omp; it's kept for the `/v1/messages`
endpoint NInfer still serves, where the ladder is
`low`/`medium`/`high`/`xhigh`/`max`. Genuinely unknown values still raise.

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

Vision being off is a two-sided setting: `config/omp/models.yml` declares
`input: [text]` to match. Without it omp assumes an openai-completions provider
takes images, and its `snapcompact` compaction method — which archives older
history as dense PNGs to save tokens — sends image blocks the server rejects
with `400 Vision is disabled for this server`. That fails *compaction*, not just
image prompts, so a long session stops being able to continue at all. If you add
`--vision`, add `image` back to the `input` list in the same change; budget for
it first, since the fixed vision allocations plus the media buffers
(`--media-cache-mib` 1024 and `--media-live-mib` 2048 by default) land on a card
where the 200k KV cache already leaves only ~2 GiB free, so expect to lower
`--max-context` and `--kv-capacity` to fit.

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

## omp's configuration

`~/.omp/agent/models.yml` comes from `config/omp/models.yml` in this repo, so
the provider definition is declarative. It repeats three values that `ai.nix`
owns — the port, the model id and the context window — and nothing checks that
they agree, so change them together. A `contextWindow` larger than the engine's
own ceiling just means omp builds prompts the engine then refuses.

`~/.omp/agent/config.yml` is deliberately **not** managed. omp rewrites it at
runtime (`omp setup`, `/model`, `/settings`), so declaring it would either fight
the app or drift silently from the repo. The consequence is that the chosen
default model is machine state, not repo state: after a reinstall, run
`omp setup` once, or use `omp --model ninfer/qwen3.8-27b` explicitly. Upstream
ships a home-manager module that writes `config.yml` as a *writable* copy for
this reason; this repo does not use it (see `pkgs/omp.nix` for why the flake
isn't consumed at all).

omp is packaged from its published release binary rather than built from source
— the full build is 2,076 derivations with no binary cache. Version bumps are
manual; the procedure is in `pkgs/omp.nix`.

## The CLI

`ninfer` (one-shot) and `ninfer-serve` are on `PATH`. The CLI loads its own copy
of the weights, so stop the service first:

```bash
sudo systemctl stop ninfer
ninfer /var/lib/ninfer/qwen3_8_27b_nvfp4.ninfer \
  --prompt "Explain prefill and decode." --max-context 32768 --max-new 2048
```
