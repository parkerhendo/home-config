import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import { Input, matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

interface PromptEntry {
  text: string;
  timestamp: number;
  project: string;
}

function extractProjectName(dirName: string): string {
  const cleaned = dirName.replace(/^-+/, "").replace(/-+$/, "");
  const parts = cleaned.split("-");
  return parts[parts.length - 1] ?? dirName;
}

function extractUserPrompts(filePath: string, project: string): PromptEntry[] {
  const prompts: PromptEntry[] = [];
  try {
    const content = readFileSync(filePath, "utf-8");
    for (const line of content.split("\n")) {
      if (!line.trim()) continue;
      const entry = JSON.parse(line);
      if (entry.type !== "message" || entry.message?.role !== "user") continue;

      const textParts: string[] = [];
      const msg = entry.message;
      if (typeof msg.content === "string") {
        textParts.push(msg.content);
      } else if (Array.isArray(msg.content)) {
        for (const part of msg.content) {
          if (part.type === "text" && typeof part.text === "string") {
            textParts.push(part.text);
          }
        }
      }

      const text = textParts.join("\n").trim();
      if (text.length > 0 && !text.startsWith("/")) {
        prompts.push({
          text,
          timestamp: msg.timestamp ?? Date.parse(entry.timestamp) ?? 0,
          project,
        });
      }
    }
  } catch {
    // skip unreadable files
  }
  return prompts;
}

function loadAllPrompts(): PromptEntry[] {
  const sessionsDir = join(homedir(), ".pi", "agent", "sessions");
  if (!existsSync(sessionsDir)) return [];

  const allPrompts: PromptEntry[] = [];

  try {
    const projectDirs = readdirSync(sessionsDir, { withFileTypes: true });
    for (const dir of projectDirs) {
      if (!dir.isDirectory()) continue;
      const projectDir = join(sessionsDir, dir.name);
      const project = extractProjectName(dir.name);

      const files = readdirSync(projectDir)
        .filter((f) => f.endsWith(".jsonl"))
        .sort()
        .reverse()
        .slice(0, 30);

      for (const file of files) {
        allPrompts.push(
          ...extractUserPrompts(join(projectDir, file), project)
        );
      }
    }
  } catch {
    // ignore
  }

  allPrompts.sort((a, b) => b.timestamp - a.timestamp);

  const seen = new Set<string>();
  const unique: PromptEntry[] = [];
  for (const p of allPrompts) {
    if (!seen.has(p.text)) {
      seen.add(p.text);
      unique.push(p);
    }
  }

  return unique;
}

function formatAge(timestamp: number): string {
  const delta = Date.now() - timestamp;
  const mins = Math.floor(delta / 60_000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;
  return `${Math.floor(days / 30)}mo ago`;
}

function fuzzyMatch(query: string, text: string): boolean {
  const q = query.toLowerCase();
  const t = text.toLowerCase();
  return t.includes(q);
}

export default function (pi: ExtensionAPI) {
  pi.registerShortcut("ctrl+r", {
    description: "Search prompt history",
    handler: async (ctx) => {
      const allPrompts = loadAllPrompts();

      if (allPrompts.length === 0) {
        ctx.ui.notify("No prompt history found", "info");
        return;
      }

      const result = await ctx.ui.custom<string | null>(
        (tui, theme, _kb, done) => {
          const MAX_VISIBLE = 15;
          let selectedIndex = 0;
          let filtered = allPrompts;
          let lastQuery = "";

          const input = new Input();
          input.focused = true;

          input.onSubmit = () => {
            if (filtered.length > 0 && filtered[selectedIndex]) {
              done(filtered[selectedIndex].text);
            }
          };
          input.onEscape = () => done(null);

          function refilter() {
            const query = input.getValue();
            if (query === lastQuery) return;
            lastQuery = query;
            if (query === "") {
              filtered = allPrompts;
            } else {
              filtered = allPrompts.filter((p) => fuzzyMatch(query, p.text));
            }
            selectedIndex = 0;
          }

          const border = new DynamicBorder((s: string) =>
            theme.fg("accent", s)
          );

          return {
            get focused() {
              return input.focused;
            },
            set focused(v: boolean) {
              input.focused = v;
            },

            handleInput(data: string) {
              if (matchesKey(data, "up")) {
                if (filtered.length > 0) {
                  selectedIndex =
                    selectedIndex === 0
                      ? filtered.length - 1
                      : selectedIndex - 1;
                }
              } else if (matchesKey(data, "down")) {
                if (filtered.length > 0) {
                  selectedIndex =
                    selectedIndex === filtered.length - 1
                      ? 0
                      : selectedIndex + 1;
                }
              } else {
                input.handleInput(data);
                refilter();
              }
              tui.requestRender();
            },

            invalidate() {},

            render(width: number) {
              const lines: string[] = [];

              lines.push(...border.render(width));

              const title =
                theme.fg("accent", theme.bold(" Prompt History")) +
                " " +
                theme.fg(
                  "dim",
                  filtered.length === allPrompts.length
                    ? `(${allPrompts.length} prompts)`
                    : `(${filtered.length}/${allPrompts.length} matching)`
                );
              lines.push(truncateToWidth(title, width));

              lines.push(...input.render(width));

              if (filtered.length === 0) {
                lines.push(
                  theme.fg("warning", "  No matching prompts")
                );
              } else {
                const startIndex = Math.max(
                  0,
                  Math.min(
                    selectedIndex - Math.floor(MAX_VISIBLE / 2),
                    filtered.length - MAX_VISIBLE
                  )
                );
                const endIndex = Math.min(
                  startIndex + MAX_VISIBLE,
                  filtered.length
                );

                for (let i = startIndex; i < endIndex; i++) {
                  const p = filtered[i];
                  if (!p) continue;
                  const isSelected = i === selectedIndex;
                  const prefix = isSelected ? "→ " : "  ";

                  const firstLine = p.text.split("\n")[0] ?? "";
                  const meta = [
                    formatAge(p.timestamp),
                    p.project,
                    p.text.includes("\n") ? "…" : "",
                  ]
                    .filter(Boolean)
                    .join(" · ");

                  const metaWidth = visibleWidth(meta) + 2;
                  const labelWidth = Math.max(10, width - metaWidth - visibleWidth(prefix));
                  const truncLabel = truncateToWidth(firstLine, labelWidth, "…");

                  const gap = Math.max(
                    1,
                    width -
                      visibleWidth(prefix) -
                      visibleWidth(truncLabel) -
                      visibleWidth(meta) -
                      1
                  );

                  const line = isSelected
                    ? theme.fg(
                        "accent",
                        prefix +
                          truncLabel +
                          " ".repeat(gap) +
                          meta
                      )
                    : prefix +
                      truncLabel +
                      theme.fg("muted", " ".repeat(gap) + meta);

                  lines.push(truncateToWidth(line, width));
                }

                if (
                  startIndex > 0 ||
                  endIndex < filtered.length
                ) {
                  lines.push(
                    theme.fg(
                      "dim",
                      `  (${selectedIndex + 1}/${filtered.length})`
                    )
                  );
                }
              }

              lines.push(
                theme.fg(
                  "dim",
                  " ↑↓ navigate • enter select • esc cancel"
                )
              );
              lines.push(...border.render(width));

              return lines;
            },
          };
        }
      );

      if (result !== null) {
        ctx.ui.setEditorText(result);
      }
    },
  });
}
