import { createServer as createNetServer } from "node:net";
import { spawn } from "node:child_process";

function getFreePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = createNetServer();

    server.unref();
    server.once("error", reject);
    server.listen({ host: "127.0.0.1", port: 0, exclusive: true }, () => {
      const address = server.address();

      if (!address || typeof address === "string") {
        reject(new Error("OS did not provide a free port"));
        return;
      }

      server.close(() => resolve(address.port));
    });
  });
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
      ["--bun", "vite", "--port", String(port), "--strictPort"],
      {
        cwd: process.cwd(),
        env: {
          ...process.env,
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
    const port = await getFreePort();

    try {
      await startDevServer(port);
      return;
    } catch (error) {
      if (!isPortInUseError(error)) throw error;
      console.log(
        `Port ${port} was taken before Vite started -> trying another OS port`,
      );
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
