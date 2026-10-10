# Secrets

Encrypted with sops + age. Edit with `sops secrets/secrets.yaml` (decrypts in your
editor, re-encrypts on save). Only the values are encrypted; the key names stay readable
so diffs make sense.

Never put a plaintext secret anywhere else in this repo: it's public.
Setup and usage: see "Secrets" in the main README.
