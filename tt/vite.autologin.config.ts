import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Wraps the repo's own vite config and, on requests with no session-token cookie,
// injects the token that `rpg` seeded into the DB. Nothing here is committed to the repo.
function readToken() {
  try {
    return readFileSync(join(homedir(), ".config/tt/dev-session-token"), "utf8").trim();
  } catch {
    return "";
  }
}

export default async function (env: { command: string; mode: string }) {
  const mod = await import(join(process.cwd(), "vite.config.ts"));
  const base = typeof mod.default === "function" ? await mod.default(env) : mod.default;
  const token = readToken();
  if (!token) return base;

  return {
    ...base,
    plugins: [
      {
        name: "tt-dev-auto-login",
        configureServer(server: any) {
          server.middlewares.use((req: any, _res: any, next: () => void) => {
            if (!/(^|;\s*)session-token=/.test(req.headers.cookie ?? "")) {
              req.headers.cookie = [req.headers.cookie, `session-token=${token}`].filter(Boolean).join("; ");
            }
            next();
          });
        },
      },
      ...(base.plugins ?? []),
    ],
  };
}
