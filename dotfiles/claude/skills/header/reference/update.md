# Staying up to date — the update flow

Loaded on demand when the preamble emitted an `UPDATE_CHECK` line. Both branches use `<HEADER_BIN>` (the preamble's echoed path).

### UPDATE_REQUIRED — non-optional

`UPDATE_CHECK: UPDATE_REQUIRED <old> <min>` means the installed skill is older than the minimum the Header API still supports; calls may fail until it's updated.

- **Interactive**: tell the user plainly and offer to update now → **Run the update**. If they decline, warn that the audit may fail, then continue.
- **Non-interactive**: print one warning line ("Header skill v{old} is below the supported minimum v{min} — update soon") and continue. Never block a scheduled run.

### UPDATE_AVAILABLE — optional

`UPDATE_CHECK: UPDATE_AVAILABLE <old> <new>`. Skip entirely if `INTERACTIVE: no`.

If `<HEADER_BIN> get auto_update` returns `true`: skip the prompt, say "Updating the Header skill v{old} → v{new}…", and go to **Run the update**.

Otherwise ask (`AskUserQuestion` on Claude Code; numbered plain text elsewhere):

> Header skill v{new} is available (you're on v{old}). Update now?
>
> 1. **Yes, update now** (recommended)
> 2. Always keep me up to date
> 3. Not now
> 4. Never ask again

- **Yes** → **Run the update**.
- **Always** → `<HEADER_BIN> set auto_update true`, then **Run the update**.
- **Not now** → write an escalating snooze and continue:

```bash
_HH="${HEADER_HOME:-$HOME/.header}"; _NEW="<new>"; _LVL=1
if [ -f "$_HH/update-snoozed" ]; then
  read -r _v _l _ < "$_HH/update-snoozed" 2>/dev/null || true
  if [ "${_v:-}" = "$_NEW" ]; then
    case "${_l:-}" in [0-9]*) _LVL=$((_l + 1)); [ "$_LVL" -gt 3 ] && _LVL=3 ;; esac
  fi
fi
printf '%s %s %s\n' "$_NEW" "$_LVL" "$(date +%s)" > "$_HH/update-snoozed"
```

- **Never ask again** → `<HEADER_BIN> set update_check false`; mention they can re-enable with `header-config set update_check true`.

### Run the update

1. Read "what's new" from the cached release info:

```bash
cat "${HEADER_HOME:-$HOME/.header}/version-info.json" 2>/dev/null
```

2. Re-run the installer — fetches the latest, swaps the install atomically, rolls back on failure:

```bash
curl -fsSL https://raw.githubusercontent.com/Header-inc/Header-skill/main/install.sh | sh
```

(Working from a git clone? `git pull --ff-only && ./install.sh` instead.)

3. Clear the update cache:

```bash
rm -f "${HEADER_HOME:-$HOME/.header}/last-update-check" "${HEADER_HOME:-$HOME/.header}/update-snoozed"
```

4. Tell the user "Updated to v{new}" plus the `message` (and `notes_url` if present), then continue with onboarding and the audit. If the installer reported a failure it restored the previous version — say so and suggest retrying.

The update takes effect on the **next** session — the current session keeps the already-loaded `SKILL.md` in context until then.
