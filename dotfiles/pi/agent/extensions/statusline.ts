/**
 * Statusline Extension
 *
 * Replaces the default footer with a single status line showing:
 * - Directory name
 * - Model name + thinking level
 * - Context window usage bar
 * - Git branch + file changes (+added/-removed)
 * - Session cost
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { visibleWidth, truncateToWidth } from "@mariozechner/pi-tui";
import { basename } from "node:path";

export default function (pi: ExtensionAPI) {
  let cachedGitInfo: string | null = null;

  async function refreshGit(cwd: string) {
    try {
      const branchResult = await pi.exec("git", ["branch", "--show-current"], {
        timeout: 3000,
      });
      if (branchResult.code !== 0) {
        cachedGitInfo = null;
        return;
      }

      const branch = branchResult.stdout.trim() || "detached";

      const statusResult = await pi.exec("git", ["status", "--porcelain"], {
        timeout: 3000,
      });
      const statusLines = statusResult.stdout.trim();

      if (!statusLines) {
        cachedGitInfo = branch;
        return;
      }

      const totalFiles = statusLines.split("\n").filter((l) => l).length;

      const diffResult = await pi.exec("git", ["diff", "--numstat", "HEAD"], {
        timeout: 3000,
      });
      let added = 0;
      let removed = 0;
      for (const line of diffResult.stdout.trim().split("\n")) {
        if (!line) continue;
        const [a, r] = line.split("\t");
        added += parseInt(a) || 0;
        removed += parseInt(r) || 0;
      }

      let info = `${branch} | ${totalFiles} files`;
      if (added > 0) info += ` +${added}`;
      if (removed > 0) info += ` -${removed}`;
      cachedGitInfo = info;
    } catch {
      cachedGitInfo = null;
    }
  }

  function installFooter(ctx: any) {
    ctx.ui.setFooter((tui: any, theme: any, footerData: any) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          const sep = theme.fg("dim", " │ ");

          // Directory
          const dirName = basename(ctx.cwd);

          // Model + thinking level
          const modelName = ctx.model?.name ?? ctx.model?.id ?? "no model";
          const thinkingLevel = pi.getThinkingLevel();
          const thinkingColorMap: Record<string, string> = {
            off: "thinkingOff",
            minimal: "thinkingMinimal",
            low: "thinkingLow",
            medium: "thinkingMedium",
            high: "thinkingHigh",
            xhigh: "thinkingXhigh",
          };
          const thinkingColor = thinkingColorMap[thinkingLevel] ?? "muted";
          const modelStr =
            theme.fg("muted", modelName) +
            " " +
            theme.fg(thinkingColor, thinkingLevel);

          // Context usage
          const usage = ctx.getContextUsage();
          let contextPercent = 0;
          if (usage) {
            const contextWindow = ctx.model?.contextWindow ?? 200000;
            contextPercent = Math.min(
              100,
              Math.round((usage.tokens / contextWindow) * 100),
            );
          }
          const barWidth = 15;
          const filled = Math.round((contextPercent * barWidth) / 100);
          const bar = "█".repeat(filled) + "░".repeat(barWidth - filled);
          const barColor =
            contextPercent > 80
              ? "error"
              : contextPercent > 50
                ? "warning"
                : "dim";
          const contextStr =
            theme.fg(barColor, bar) +
            " " +
            theme.fg("muted", `${contextPercent}%`);

          // Session cost
          let totalCost = 0;
          for (const entry of ctx.sessionManager.getBranch()) {
            if (entry.type === "message" && entry.message.role === "assistant") {
              const m = entry.message as AssistantMessage;
              totalCost += m.usage?.cost?.total ?? 0;
            }
          }

          // Git info
          const gitBranch = footerData.getGitBranch() ?? cachedGitInfo;
          let gitStr = "";
          if (cachedGitInfo) {
            const hasChanges = cachedGitInfo.includes("|");
            if (hasChanges) {
              const [branchPart, rest] = cachedGitInfo.split(" | ");
              let colored = theme.fg("warning", branchPart);
              if (rest) {
                const parts = rest.split(" ");
                const filesPart = parts.slice(0, 2).join(" ");
                colored +=
                  theme.fg("dim", " | ") + theme.fg("muted", filesPart);
                for (const p of parts.slice(2)) {
                  if (p.startsWith("+")) {
                    colored += " " + theme.fg("success", p);
                  } else if (p.startsWith("-")) {
                    colored += " " + theme.fg("error", p);
                  }
                }
              }
              gitStr =
                theme.fg("warning", "(") +
                colored +
                theme.fg("warning", ")");
            } else {
              gitStr = theme.fg("warning", `(${cachedGitInfo})`);
            }
          } else if (gitBranch) {
            gitStr = theme.fg("warning", `(${gitBranch})`);
          }

          // Assemble
          const left = [
            theme.fg("accent", dirName),
            modelStr,
            contextStr,
          ].join(sep);

          const right = [
            gitStr,
            totalCost > 0 ? theme.fg("muted", `$${totalCost.toFixed(4)}`) : "",
          ]
            .filter(Boolean)
            .join(sep);

          if (!right) {
            return [truncateToWidth(left, width)];
          }

          const pad = " ".repeat(
            Math.max(1, width - visibleWidth(left) - visibleWidth(right) - visibleWidth(sep)),
          );
          return [truncateToWidth(left + pad + sep + right, width)];
        },
      };
    });
  }

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    await refreshGit(ctx.cwd);
    installFooter(ctx);
  });

  pi.on("turn_end", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    await refreshGit(ctx.cwd);
  });

  pi.on("tool_execution_end", async (event, ctx) => {
    if (!ctx.hasUI) return;
    if (["bash", "write", "edit"].includes(event.toolName)) {
      await refreshGit(ctx.cwd);
    }
  });
}
