import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import type { SkillSource } from "../types.ts";

export interface SkillRoot {
  path: string;
  source: SkillSource;
}

export function getAgentDir(): string {
  const configured = process.env.PI_CODING_AGENT_DIR?.trim();
  if (configured) return expandHome(configured);
  return join(homedir(), ".pi", "agent");
}

export function getSkillRoots(cwd: string): SkillRoot[] {
  const resolvedCwd = resolve(cwd);
  const agentSkills = join(getAgentDir(), "skills");
  const globalAgentsSkills = join(homedir(), ".agents", "skills");
  const projectSkills = resolve(resolvedCwd, ".pi", "skills");
  const roots: SkillRoot[] = [
    {
      path: agentSkills,
      source: { kind: "user", root: agentSkills },
    },
    {
      path: globalAgentsSkills,
      source: { kind: "user", root: globalAgentsSkills },
    },
    {
      path: projectSkills,
      source: { kind: "project", root: projectSkills },
    },
    ...getAncestorSkillRoots(resolvedCwd),
  ];

  const seen = new Set<string>();
  return roots.filter((root) => {
    const key = resolve(root.path);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function getAncestorSkillRoots(cwd: string): SkillRoot[] {
  const roots: SkillRoot[] = [];
  let current = cwd;

  while (true) {
    const path = join(current, ".agents", "skills");
    roots.push({
      path,
      source: { kind: "project", root: path },
    });

    const parent = dirname(current);
    if (parent === current) break;
    current = parent;
  }

  return roots;
}

function expandHome(input: string): string {
  if (input === "~") return homedir();
  if (input.startsWith("~/")) return join(homedir(), input.slice(2));
  return input;
}
