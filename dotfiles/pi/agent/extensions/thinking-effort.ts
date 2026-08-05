/**
 * Thinking Effort Extension
 *
 * Adjust the thinking effort level the model uses via:
 * - `/thinking <level>` command (e.g., `/thinking high`)
 * - `Ctrl+T` — cycle through levels
 *
 * Usage: auto-discovered from ~/.pi/agent/extensions/
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh"] as const;
type ThinkingLevel = (typeof LEVELS)[number];

export default function (pi: ExtensionAPI) {
	pi.registerShortcut("ctrl+t", {
		description: "Cycle thinking effort level",
		handler: async () => {
			const current = pi.getThinkingLevel() as ThinkingLevel;
			const currentIndex = LEVELS.indexOf(current);
			const nextIndex = (currentIndex + 1) % LEVELS.length;
			pi.setThinkingLevel(LEVELS[nextIndex]);
		},
	});

	pi.registerCommand("thinking", {
		description: "Set thinking effort level",
		handler: async (args) => {
			const requested = args.trim().toLowerCase() as ThinkingLevel;
			if (LEVELS.includes(requested)) {
				pi.setThinkingLevel(requested);
			}
		},
	});
}
