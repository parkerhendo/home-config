/**
 * Thinking Effort Extension
 *
 * Adjust the thinking effort level the model uses via:
 * - `/thinking <level>` command (e.g., `/thinking high`)
 * - `Ctrl+T` — cycle through levels
 *
 * Usage: auto-discovered from ~/.pi/agent/extensions/
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { Api, Model } from "@mariozechner/pi-ai";

const LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;
type ThinkingLevel = (typeof LEVELS)[number];

// Mirrors pi's internal getSupportedThinkingLevels: "xhigh"/"max" only count as
// available when the model's thinkingLevelMap explicitly maps them.
function getAvailableLevels(model: Model<Api> | undefined): ThinkingLevel[] {
	if (!model?.reasoning) return ["off"];
	return LEVELS.filter((level) => {
		const mapped = model.thinkingLevelMap?.[level];
		if (mapped === null) return false;
		if (level === "xhigh" || level === "max") return mapped !== undefined;
		return true;
	});
}

export default function (pi: ExtensionAPI) {
	pi.registerShortcut("ctrl+t", {
		description: "Cycle thinking effort level",
		handler: async (ctx: ExtensionContext) => {
			const levels = getAvailableLevels(ctx.model);
			const current = pi.getThinkingLevel() as ThinkingLevel;
			const currentIndex = levels.indexOf(current);
			const nextIndex = (currentIndex + 1) % levels.length;
			pi.setThinkingLevel(levels[nextIndex]);
		},
	});

	pi.registerCommand("thinking", {
		description: "Set thinking effort level",
		handler: async (args, ctx) => {
			const requested = args.trim().toLowerCase() as ThinkingLevel;
			if (!LEVELS.includes(requested)) return;

			if (!getAvailableLevels(ctx.model).includes(requested)) {
				ctx.ui.notify(`"${requested}" thinking is not available for the current model`, "warning");
				return;
			}

			pi.setThinkingLevel(requested);
		},
	});
}
