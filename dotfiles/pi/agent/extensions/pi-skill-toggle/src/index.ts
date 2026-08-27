import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { dirname } from "node:path";
import { AtomicSkillChangeWriter } from "./apply/writer.ts";
import { DefaultSkillTogglePlanner } from "./apply/planner.ts";
import { DefaultSkillLocator } from "./discovery/skill-locator.ts";
import { MinimalFrontmatterPatcher } from "./frontmatter/patcher.ts";
import { SimpleFrontmatterCodec } from "./frontmatter/parser.ts";
import { DefaultSkillInventory } from "./inventory/loader.ts";
import { NodeFileSystem } from "./ports/fs.ts";
import type { LocatedSkillFile, SkillSource } from "./types.ts";
import { runToggleSkillsCommand } from "./command.ts";

export default function piSkillToggle(pi: ExtensionAPI) {
  const fs = new NodeFileSystem();
  const codec = new SimpleFrontmatterCodec();
  const patcher = new MinimalFrontmatterPatcher();
  const locator = new DefaultSkillLocator(fs, () => getLoadedSkillFiles(pi));
  const inventory = new DefaultSkillInventory(locator, fs, codec);
  const planner = new DefaultSkillTogglePlanner(fs, codec, patcher);
  const writer = new AtomicSkillChangeWriter(fs);

  pi.registerCommand("toggle-skills", {
    description: "Toggle whether skills are agent-invocable or manual-only",
    handler: async (_args, ctx) => {
      await runToggleSkillsCommand(ctx, { inventory, planner, writer });
    },
  });
}

function getLoadedSkillFiles(pi: ExtensionAPI): LocatedSkillFile[] {
  return pi.getCommands()
    .filter((command) => command.source === "skill")
    .map((command) => ({
      filePath: command.sourceInfo.path,
      source: getSkillSource(command.sourceInfo),
      editable: command.sourceInfo.origin !== "package",
    }));
}

function getSkillSource(sourceInfo: {
  path: string;
  scope: "user" | "project" | "temporary";
  origin: "package" | "top-level";
  baseDir?: string;
}): SkillSource {
  const root = sourceInfo.baseDir ?? dirname(sourceInfo.path);
  if (sourceInfo.origin === "package") return { kind: "package", root };
  if (sourceInfo.scope === "user") return { kind: "user", root };
  if (sourceInfo.scope === "project") return { kind: "project", root };
  return { kind: "unknown", root };
}
