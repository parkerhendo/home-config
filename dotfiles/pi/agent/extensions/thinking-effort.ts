/**
 * Thinking Effort Extension
 *
 * Adjust the thinking effort level the model uses via:
 * - `/thinking` command — show a selector or set directly (e.g., `/thinking high`)
 * - `Ctrl+T` — cycle through levels
 *
 * Usage: auto-discovered from ~/.pi/agent/extensions/
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Key } from "@mariozechner/pi-tui";

const LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh"] as const;
type ThinkingLevel = (typeof LEVELS)[number];

const LEVEL_LABELS: Record<ThinkingLevel, string> = {
	off: "Off",
	minimal: "Minimal",
	low: "Low",
	medium: "Medium",
	high: "High",
	xhigh: "Extra High",
};

const LEVEL_ICONS: Record<ThinkingLevel, string> = {
	off: "💤",
	minimal: "🌱",
	low: "💭",
	medium: "🧠",
	high: "🔥",
	xhigh: "⚡",
};

export default function (pi: ExtensionAPI) {
	// Cycle through thinking levels with Ctrl+Shift+T
	pi.registerShortcut(Key.ctrl("t"), {
		description: "Cycle thinking effort level",
		handler: async (ctx) => {
			const current = pi.getThinkingLevel() as ThinkingLevel;
			const currentIndex = LEVELS.indexOf(current);
			const nextIndex = (currentIndex + 1) % LEVELS.length;
			const next = LEVELS[nextIndex];
			pi.setThinkingLevel(next);
			ctx.ui.notify(`Thinking: ${LEVEL_ICONS[next]} ${LEVEL_LABELS[next]}`, "info");
		},
	});

	// /thinking command
	pi.registerCommand("thinking", {
		description: "Set thinking effort level",
		getArgumentCompletions: (prefix: string) => {
			const items = LEVELS.map((level) => ({
				value: level,
				label: `${LEVEL_ICONS[level]} ${LEVEL_LABELS[level]}`,
			}));
			const filtered = items.filter((i) => i.value.startsWith(prefix));
			return filtered.length > 0 ? filtered : null;
		},
		handler: async (args, ctx) => {
			// Direct set if argument provided
			if (args?.trim()) {
				const requested = args.trim().toLowerCase() as ThinkingLevel;
				if (LEVELS.includes(requested)) {
					pi.setThinkingLevel(requested);
					ctx.ui.notify(`Thinking: ${LEVEL_ICONS[requested]} ${LEVEL_LABELS[requested]}`, "info");
					return;
				}
				ctx.ui.notify(`Unknown level "${args.trim()}". Options: ${LEVELS.join(", ")}`, "error");
				return;
			}

			// Show selector
			const current = pi.getThinkingLevel() as ThinkingLevel;
			const choices = LEVELS.map((level) => {
				const active = level === current ? " (current)" : "";
				return `${LEVEL_ICONS[level]} ${LEVEL_LABELS[level]}${active}`;
			});

			const choice = await ctx.ui.select("Thinking Effort", choices);
			if (choice === null) return;

			const selectedIndex = choices.indexOf(choice);
			if (selectedIndex === -1) return;

			const selected = LEVELS[selectedIndex];
			pi.setThinkingLevel(selected);
			ctx.ui.notify(`Thinking: ${LEVEL_ICONS[selected]} ${LEVEL_LABELS[selected]}`, "info");
		},
	});
}
