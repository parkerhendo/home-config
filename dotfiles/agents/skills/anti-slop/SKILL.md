---
name: anti-slop
description: Run an isolated anti-slop Oxlint audit on the current repository.
disable-model-invocation: true
---

# Anti-slop audit

From the current repository, run:

```bash
node "$HOME/.agents/skills/install-anti-slop/scripts/audit.mjs"
```

If the user supplied paths, append those paths. If they requested current Oxlint packages, append `--refresh`.

Report the findings and exit status. Do not modify repository files or fix violations unless the user separately asks.
