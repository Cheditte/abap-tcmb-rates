import { execFile } from "node:child_process";
import { access, mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execute = promisify(execFile);
const root = fileURLToPath(new URL("../", import.meta.url));
const dependencies = path.join(root, ".abaplint-deps");
const dependencyUrl = "https://github.com/abaplint/deps.git";
const dependencyRevision = "17aab021807da9249c9a20b9ce785de6be6d258e";
const configurations = new Map([
  ["740", "abaplint.json"],
  ["758", "abaplint.v758.json"],
]);

async function git(args) {
  const { stdout } = await execute("git", args, {
    cwd: root,
    windowsHide: true,
    maxBuffer: 4 * 1024 * 1024,
  });
  return stdout.trim();
}

async function prepareDependencies() {
  try {
    await access(path.join(dependencies, ".git"));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
    await mkdir(dependencies, { recursive: true });
    await git(["init", dependencies]);
    await git(["-C", dependencies, "fetch", "--depth", "1", dependencyUrl, dependencyRevision]);
    await git(["-C", dependencies, "checkout", "--detach", "FETCH_HEAD"]);
  }

  const actualRoot = await git(["-C", dependencies, "rev-parse", "--show-toplevel"]);
  const revision = await git(["-C", dependencies, "rev-parse", "HEAD"]);
  const changes = await git(["-C", dependencies, "status", "--porcelain", "--untracked-files=all"]);
  if (path.resolve(actualRoot) !== path.resolve(dependencies)
      || revision !== dependencyRevision || changes !== "") {
    throw new Error("Unexpected .abaplint-deps checkout. Move that generated directory aside and rerun; it must contain the pinned, unchanged dependency revision.");
  }
  await access(path.join(dependencies, "src"));
  console.log(`SAP dependency stubs: abaplint/deps@${revision}`);
}

try {
  const arguments_ = process.argv.slice(2);
  if (arguments_.length > 1 || (arguments_.length === 1 && !configurations.has(arguments_[0]))) {
    throw new Error("Usage: node scripts/lint.mjs [740|758]");
  }
  const selected = arguments_.length === 0 ? [...configurations.values()] : [configurations.get(arguments_[0])];
  await prepareDependencies();
  const cli = path.join(root, "node_modules", "@abaplint", "cli", "abaplint");
  await access(cli);
  for (const configuration of selected) {
    await access(path.join(root, configuration));
    console.log(`\nChecking ${configuration}`);
    const { stdout, stderr } = await execute(process.execPath, [cli, configuration], {
      cwd: root,
      windowsHide: true,
      maxBuffer: 4 * 1024 * 1024,
    });
    process.stdout.write(stdout);
    process.stderr.write(stderr);
  }
} catch (error) {
  if (error.stdout) process.stdout.write(error.stdout);
  if (error.stderr) process.stderr.write(error.stderr);
  console.error(error.message ?? error);
  process.exitCode = 1;
}
