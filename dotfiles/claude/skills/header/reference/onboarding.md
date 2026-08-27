# First-run onboarding — welcome & language

Loaded on demand on a first interactive run (`WELCOME_SEEN: no` or `LANGUAGE_PROMPTED: no`). `<HEADER_BIN>` is the preamble's echoed path.

**Claude Code only:** the choices below use the `AskUserQuestion` tool. Other harnesses present the same options as a numbered list and ask the user to reply with a number.

### Welcome — before the audit

If `WELCOME_SEEN: no`, print this once, then continue:

> 👋 **Header** — I optimize AI coding agents. Each run I audit your harness (`CLAUDE.md`, model, dependencies) for prompt-config debt and supply-chain gaps, and check it against what's new in agentic coding. No account needed to start.

```bash
touch "${HEADER_HOME:-$HOME/.header}/.welcome-seen"
```

### Language — before the audit

If `LANGUAGE: English` (the built-in default) **and** `LANGUAGE_PROMPTED: no`, ask **once** which language to render output in:

> **Which language should output be rendered in?**
>
> Briefing content stays English on the wire; the agent translates the presentation for you. Translation quality varies by language; proper nouns, code identifiers, and URLs stay verbatim.

Options (label English as recommended):

1. **English** — recommended, no translation.
2. **Spanish** — agent translates the presentation.
3. **Turkish** — agent translates the presentation.
4. **Other** — ask the user which language to use.

Persist the choice and touch the marker (`<HEADER_BIN>` is the preamble's echoed path):

```bash
<HEADER_BIN> set language "Chosen"
touch "${HEADER_HOME:-$HOME/.header}/.language-prompted"
```

Replace `Chosen` with the user's pick. Persisting `English` explicitly is harmless. Always touch the marker so the prompt never fires again. Skip the prompt entirely if `INTERACTIVE: no` or `LANGUAGE_PROMPTED: yes`.
