import { createServer as createNetServer } from "node:net";
import { spawn } from "node:child_process";
import { basename } from "node:path";
import { homedir } from "node:os";
import { join } from "node:path";

function canListen(port: number, host: string): Promise<boolean> {
  return new Promise((resolve) => {
    const server = createNetServer();

    server.unref();
    server.once("error", (error: NodeJS.ErrnoException) => {
      // An address family this machine doesn't have can't be in use.
      resolve(error.code === "EADDRNOTAVAIL" || error.code === "EAFNOSUPPORT");
    });
    server.listen({ port, host, exclusive: true }, () => {
      server.close(() => resolve(true));
    });
  });
}

async function isPortFree(port: number): Promise<boolean> {
  return (await canListen(port, "127.0.0.1")) && (await canListen(port, "::1"));
}

// Worktree dirs like `FST-1323` or `1323-foo` get ports 13230-13239 (ticket number + one digit).
function getTicketNumber(): number | null {
  const match = basename(process.cwd()).match(/(?<!\d)(\d{3,5})(?!\d)/);
  return match ? Number(match[1]) : null;
}

async function pickPort(): Promise<number> {
  const ticket = getTicketNumber();

  if (ticket !== null && ticket * 10 + 9 <= 65535) {
    for (let port = ticket * 10; port < ticket * 10 + 10; port++) {
      if (await isPortFree(port)) return port;
    }
    console.log(`Ports ${ticket * 10}-${ticket * 10 + 9} are all taken -> falling back to 3000+`);
  }

  for (let port = 3000; port < 3100; port++) {
    if (await isPortFree(port)) return port;
  }

  throw new Error("No free port found");
}

function isPortInUseError(error: unknown): boolean {
  return (
    (error instanceof Error &&
      "code" in error &&
      (error as { code?: string }).code === "EADDRINUSE") ||
    (error instanceof Error &&
      /port \d+ is already in use/i.test(error.message))
  );
}

async function startDevServer(port: number): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const child = spawn(
      "bunx",
      [
        "--bun",
        "vite",
        "--port",
        String(port),
        "--strictPort",
        ...(process.env.TT_NO_AUTOLOGIN
          ? []
          : ["--config", join(homedir(), ".config/tt/vite.autologin.config.ts")]),
      ],
      {
        cwd: process.cwd(),
        env: {
          ...process.env,
          // Used by /dev-login on branches that have it, to mint a session and set the cookie.
          DEV_AUTO_LOGIN_EMAIL:
            process.env.DEV_AUTO_LOGIN_EMAIL ?? "admin-tt-dev@lightcast.io",
          APP_URL: `http://localhost:${port}`,
          PORT: String(port),
        },
        stdio: "inherit",
      },
    );

    const stop = (signal: NodeJS.Signals) => child.kill(signal);
    process.once("SIGINT", () => stop("SIGINT"));
    process.once("SIGTERM", () => stop("SIGTERM"));

    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`Dev server exited with code ${code ?? 1}`));
    });
  });
}

async function main() {
  for (;;) {
    const port = await pickPort();

    try {
      await startDevServer(port);
      return;
    } catch (error) {
      if (!isPortInUseError(error)) throw error;
      console.log(
        `Port ${port} was taken before Vite started -> trying the next port`,
      );
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
