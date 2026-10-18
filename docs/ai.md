# AI

Claude Code, plus a local model on the 5090. Configured in `configuration.nix`
(`services.ollama`) and `home.nix`.

- **Claude Code:** `claude` (log in on first run).
- **Local models:** Ollama runs on the 5090 with CUDA and downloads `qwen3-coder:30b`
  (~19 GB) in the background after the first boot; `ollama ps` shows what's loaded.
  - `claude-local` runs Claude Code against the local model instead of Anthropic's API.
    Pick another model with `CLAUDE_LOCAL_MODEL=<name> claude-local`.
  - `ollama run qwen3-coder:30b` for a plain chat in the terminal.
  - Local models are far weaker than Claude at multi-step coding; good for offline use,
    quick questions and privacy-sensitive code.
- CUDA builds come from `cache.nixos-cuda.org` (set in `configuration.nix`), so Ollama
  doesn't have to compile on your machine.
