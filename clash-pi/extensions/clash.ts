/**
 * Clash extension for Pi agent.
 *
 * Bridges Pi's extension API to Clash's CLI hook interface.
 * Installed via: pi install npm:@empathic/clash-pi
 */

import { execSync } from "child_process";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const HOOK_TIMEOUT = 10_000;

export default function (pi: ExtensionAPI) {
  let sessionId = "";
  let clashMissing = false;
  let warnedOnce = false;

  function runHook(subcommand: string, input: string): string | null {
    try {
      return execSync(`clash hook --agent opencode ${subcommand}`, {
        input,
        encoding: "utf-8",
        timeout: HOOK_TIMEOUT,
      });
    } catch (err: any) {
      if (!clashMissing && err.code === "ENOENT") {
        clashMissing = true;
        console.error(
          "[clash] WARNING: clash binary not found on PATH. " +
            "Policy enforcement is disabled for this session. " +
            "Install clash: npm install -g @empathic/clash"
        );
      }
      return null;
    }
  }

  pi.on("session_start", async (_event, _ctx) => {
    runHook(
      "session-start",
      JSON.stringify({
        session_id: sessionId,
        cwd: process.cwd(),
        hook_event_name: "session.start",
      })
    );
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!sessionId && event.sessionId) {
      sessionId = `pi-${event.sessionId}`;
    }

    if (clashMissing) {
      if (!warnedOnce) {
        warnedOnce = true;
        console.error(
          "[clash] clash binary not found — all tool calls are unprotected"
        );
      }
      return undefined;
    }

    const hookInput = JSON.stringify({
      tool: event.toolName,
      args: event.input,
      session_id: sessionId,
      directory: process.cwd(),
      hook_event_name: "tool.execute.before",
    });

    const result = runHook("pre-tool-use", hookInput);
    if (!result) {
      return undefined;
    }

    let decision: any;
    try {
      decision = JSON.parse(result);
    } catch {
      return undefined;
    }

    if (decision.action === "deny") {
      return {
        block: true,
        reason: decision.reason || "blocked by clash policy",
      };
    }

    if (decision.action === "ask") {
      if (ctx.hasUI) {
        const choice = await ctx.ui.select(
          `Clash policy requires approval:\n${decision.reason || event.toolName}`,
          ["Allow", "Deny"]
        );
        if (choice === "Deny") {
          return { block: true, reason: "denied by user" };
        }
      }
      return undefined;
    }

    if (decision.action === "allow" && decision.args) {
      Object.assign(event.input, decision.args);
    }

    return undefined;
  });

  pi.on("tool_result", async (event, _ctx) => {
    if (clashMissing) return;

    runHook(
      "post-tool-use",
      JSON.stringify({
        tool: event.toolName,
        args: event.input,
        session_id: sessionId,
        directory: process.cwd(),
        hook_event_name: "tool.execute.after",
      })
    );
  });
}
