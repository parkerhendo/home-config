import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";

type CommandSpec = {
	command: string;
	args: string[];
};

type NotificationResult = {
	body: string;
	desktop: boolean;
	terminal: boolean;
	tmuxSwitch: boolean;
	tmuxWindowName?: string;
	tmuxPaneId?: string;
};

const COMMAND_TIMEOUT_MS = 2_500;
const TMUX_WINDOW_FORMAT = "#{session_name}:#{window_index}.#{window_name}";
const TMUX_PANE_FORMAT = "#{pane_id}";
const TMUX_SESSION_ID_FORMAT = "#{session_id}";
const TMUX_CLIENT_LIST_FORMAT = "#{client_tty}\t#{session_id}\t#{client_flags}";

type TmuxClient = {
	tty: string;
	sessionId: string;
	flags: Set<string>;
};

function runCommandSilent(command: CommandSpec, timeoutMs = COMMAND_TIMEOUT_MS): Promise<boolean> {
	return new Promise((resolve) => {
		const child = spawn(command.command, command.args, { stdio: "ignore" });
		let settled = false;

		const finish = (ok: boolean) => {
			if (settled) return;
			settled = true;
			clearTimeout(timeoutId);
			resolve(ok);
		};

		const timeoutId = setTimeout(() => {
			child.kill("SIGKILL");
			finish(false);
		}, timeoutMs);

		child.on("error", () => finish(false));
		child.on("exit", (code) => finish(code === 0));
	});
}

function runCommandCapture(command: CommandSpec, timeoutMs = COMMAND_TIMEOUT_MS): Promise<string | undefined> {
	return new Promise((resolve) => {
		const child = spawn(command.command, command.args, {
			stdio: ["ignore", "pipe", "ignore"],
		});
		let settled = false;
		let stdout = "";

		const finish = (output?: string) => {
			if (settled) return;
			settled = true;
			clearTimeout(timeoutId);
			resolve(output);
		};

		const timeoutId = setTimeout(() => {
			child.kill("SIGKILL");
			finish(undefined);
		}, timeoutMs);

		child.stdout.on("data", (chunk) => {
			stdout += chunk.toString();
			if (stdout.length > 4_096) {
				stdout = stdout.slice(0, 4_096);
			}
		});

		child.on("error", () => finish(undefined));
		child.on("exit", (code) => finish(code === 0 ? stdout : undefined));
	});
}

function escapeAppleScript(value: string): string {
	return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r?\n/g, " ");
}

function escapePowerShellSingleQuoted(value: string): string {
	return value.replace(/'/g, "''").replace(/\r?\n/g, " ");
}

function windowsToastScript(title: string, body: string): string {
	const escapedTitle = escapePowerShellSingleQuoted(title);
	const escapedBody = escapePowerShellSingleQuoted(body);
	const type = "Windows.UI.Notifications";
	const mgr = `[${type}.ToastNotificationManager, ${type}, ContentType = WindowsRuntime]`;
	const template = `[${type}.ToastTemplateType]::ToastText02`;
	const toast = `[${type}.ToastNotification]::new($xml)`;

	return [
		`${mgr} > $null`,
		`$xml = [${type}.ToastNotificationManager]::GetTemplateContent(${template})`,
		`$xml.GetElementsByTagName('text')[0].AppendChild($xml.CreateTextNode('${escapedTitle}')) > $null`,
		`$xml.GetElementsByTagName('text')[1].AppendChild($xml.CreateTextNode('${escapedBody}')) > $null`,
		`[${type}.ToastNotificationManager]::CreateToastNotifier('Pi').Show(${toast})`,
	].join("; ");
}

function notifyOSC777(title: string, body: string): void {
	process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
}

function notifyOSC99(title: string, body: string): void {
	process.stdout.write(`\x1b]99;i=1:d=0;${title}\x1b\\`);
	process.stdout.write(`\x1b]99;i=1:p=body;${body}\x1b\\`);
}

async function getTmuxFormat(format: string): Promise<string | undefined> {
	if (!process.env.TMUX) return undefined;

	const args = ["display-message", "-p"];
	if (process.env.TMUX_PANE) {
		args.push("-t", process.env.TMUX_PANE);
	}
	args.push(format);

	const output = await runCommandCapture({ command: "tmux", args }, 1_000);
	const value = output?.trim();
	return value ? value : undefined;
}

async function getTmuxWindowName(): Promise<string | undefined> {
	return getTmuxFormat(TMUX_WINDOW_FORMAT);
}

async function getTmuxPaneId(): Promise<string | undefined> {
	if (process.env.TMUX_PANE) return process.env.TMUX_PANE;
	return getTmuxFormat(TMUX_PANE_FORMAT);
}

async function getTmuxSessionIdForPane(paneId: string): Promise<string | undefined> {
	if (!process.env.TMUX) return undefined;

	const output = await runCommandCapture(
		{ command: "tmux", args: ["display-message", "-p", "-t", paneId, TMUX_SESSION_ID_FORMAT] },
		1_000,
	);
	const value = output?.trim();
	return value ? value : undefined;
}

function parseTmuxClients(output: string | undefined): TmuxClient[] {
	if (!output) return [];

	return output
		.split(/\r?\n/)
		.map((line) => line.trim())
		.filter((line) => line.length > 0)
		.map((line) => {
			const [tty = "", sessionId = "", flagsRaw = ""] = line.split("\t", 3);
			const flags = new Set(
				flagsRaw
					.split(",")
					.map((flag) => flag.trim())
					.filter((flag) => flag.length > 0),
			);
			return { tty, sessionId, flags };
		});
}

function isClientForegrounded(client: TmuxClient): boolean {
	return (
		client.flags.has("focused") ||
		client.flags.has("active") ||
		client.flags.has("foreground")
	);
}

async function isTmuxSessionForegrounded(sessionId: string): Promise<boolean> {
	if (!process.env.TMUX) return false;

	const clientsOutput = await runCommandCapture(
		{ command: "tmux", args: ["list-clients", "-F", TMUX_CLIENT_LIST_FORMAT] },
		1_000,
	);
	const clients = parseTmuxClients(clientsOutput);

	return clients.some((client) => client.sessionId === sessionId && isClientForegrounded(client));
}

function getSoundCommands(): CommandSpec[] {
	if (process.platform === "darwin") {
		return [
			{ command: "afplay", args: ["/System/Library/Sounds/Glass.aiff"] },
			{ command: "osascript", args: ["-e", "beep 1"] },
		];
	}

	if (process.platform === "win32") {
		return [
			{
				command: "powershell.exe",
				args: ["-NoProfile", "-Command", "[console]::beep(880,180)"],
			},
		];
	}

	return [
		{ command: "canberra-gtk-play", args: ["-i", "complete", "-d", "pi"] },
		{ command: "paplay", args: ["/usr/share/sounds/freedesktop/stereo/complete.oga"] },
		{ command: "aplay", args: ["/usr/share/sounds/alsa/Front_Center.wav"] },
		{ command: "play", args: ["-nq", "-t", "alsa", "synth", "0.15", "sine", "880"] },
	];
}

function getDesktopNotificationCommands(title: string, body: string): CommandSpec[] {
	if (process.platform === "darwin") {
		return [
			{
				command: "osascript",
				args: [
					"-e",
					`display notification "${escapeAppleScript(body)}" with title "${escapeAppleScript(title)}"`,
				],
			},
		];
	}

	if (process.platform === "win32") {
		return [
			{
				command: "powershell.exe",
				args: ["-NoProfile", "-Command", windowsToastScript(title, body)],
			},
		];
	}

	return [{ command: "notify-send", args: [title, body] }];
}

async function playCompletionSound(): Promise<void> {
	for (const command of getSoundCommands()) {
		if (await runCommandSilent(command)) return;
	}

	// Terminal bell fallback.
	process.stderr.write("\x07");
}

async function sendDesktopNotification(title: string, body: string): Promise<boolean> {
	for (const command of getDesktopNotificationCommands(title, body)) {
		if (await runCommandSilent(command)) return true;
	}
	return false;
}

function sendTerminalNotification(title: string, body: string): boolean {
	if (!process.stdout.isTTY) return false;

	if (process.env.KITTY_WINDOW_ID) {
		notifyOSC99(title, body);
		return true;
	}

	notifyOSC777(title, body);
	return true;
}

async function switchTmuxClientsToPane(paneId: string): Promise<boolean> {
	if (!process.env.TMUX) return false;

	const sessionId = await getTmuxSessionIdForPane(paneId);
	if (sessionId && (await isTmuxSessionForegrounded(sessionId))) {
		return false;
	}

	const clientsOutput = await runCommandCapture(
		{ command: "tmux", args: ["list-clients", "-F", "#{client_tty}"] },
		1_000,
	);
	const clients = clientsOutput
		?.split(/\r?\n/)
		.map((line) => line.trim())
		.filter((line) => line.length > 0);

	if (!clients || clients.length === 0) {
		return runCommandSilent({ command: "tmux", args: ["switch-client", "-t", paneId] }, 1_000);
	}

	const results = await Promise.all(
		clients.map((clientTty) =>
			runCommandSilent(
				{ command: "tmux", args: ["switch-client", "-c", clientTty, "-t", paneId] },
				1_000,
			),
		),
	);
	return results.some(Boolean);
}

async function sendCompletionNotification(
	tmuxWindowName?: string,
	tmuxPaneId?: string,
): Promise<NotificationResult> {
	const title = "Pi";
	const body = tmuxWindowName
		? `Ready for input (tmux: ${tmuxWindowName})`
		: "Ready for input";

	const [desktop, tmuxSwitch] = await Promise.all([
		sendDesktopNotification(title, body),
		tmuxPaneId ? switchTmuxClientsToPane(tmuxPaneId) : Promise.resolve(false),
	]);
	const terminal = sendTerminalNotification(title, body);

	return {
		body,
		desktop,
		terminal,
		tmuxSwitch,
		tmuxWindowName,
		tmuxPaneId,
	};
}

async function runCompletionAlert(): Promise<NotificationResult> {
	const [tmuxWindowName, tmuxPaneId] = await Promise.all([
		getTmuxWindowName(),
		getTmuxPaneId(),
	]);
	const notificationPromise = sendCompletionNotification(tmuxWindowName, tmuxPaneId);
	await Promise.all([playCompletionSound(), notificationPromise]);
	return notificationPromise;
}

function describeChannels(result: NotificationResult): string {
	const channels: string[] = [];
	if (result.desktop) channels.push("desktop");
	if (result.terminal) channels.push("terminal");
	if (result.tmuxSwitch) channels.push("tmux-switch");
	return channels.length > 0 ? channels.join(", ") : "in-app";
}

export default function (pi: ExtensionAPI) {
	let completionAlertsEnabled = true;

	pi.on("agent_end", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		if (!completionAlertsEnabled) return;

		const result = await runCompletionAlert();
		if (!result.desktop && !result.terminal && !result.tmuxSwitch) {
			ctx.ui.notify(result.body, "info");
		}
	});

	pi.registerCommand("ding-on", {
		description: "Enable automatic completion alerts",
		handler: async (_args, ctx) => {
			completionAlertsEnabled = true;
			ctx.ui.notify("Automatic completion alerts enabled", "info");
		},
	});

	pi.registerCommand("ding-off", {
		description: "Disable automatic completion alerts",
		handler: async (_args, ctx) => {
			completionAlertsEnabled = false;
			ctx.ui.notify("Automatic completion alerts disabled", "info");
		},
	});

	pi.registerCommand("ding", {
		description: "Play completion sound + notification now",
		handler: async (_args, ctx) => {
			const result = await runCompletionAlert();
			ctx.ui.notify(`Played completion alert via ${describeChannels(result)}`, "info");
		},
	});
}
