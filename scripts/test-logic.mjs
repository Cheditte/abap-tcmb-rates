import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFile, mkdir, mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execute = promisify(execFile);
const root = fileURLToPath(new URL("../", import.meta.url));
const coreRevision = "f735eed652288c8ed85b3083a187cc3e7e4a9b97";
const sourceObjects = [
  "zif_che_tcmb", "zif_che_tcmb_rate_store", "zif_che_tcmb_day_loader",
  "zcl_che_tcmb_writer", "zcl_che_tcmb_calc", "zcl_che_tcmb_runner", "zcx_che_tcmb",
];

async function run(commandArguments, cwd, logName) {
  try {
    const { stdout, stderr } = await execute(process.execPath, commandArguments, {
      cwd,
      shell: false,
      windowsHide: true,
      maxBuffer: 8 * 1024 * 1024,
    });
    await writeFile(path.join(cwd, logName), stdout + stderr);
    process.stdout.write(stdout);
    process.stderr.write(stderr);
    return stdout;
  } catch (error) {
    const output = (error.stdout ?? "") + (error.stderr ?? "");
    await writeFile(path.join(cwd, logName), output);
    process.stderr.write(output);
    throw error;
  }
}

try {
  const runs = path.join(root, ".logic-tests", "runs");
  await mkdir(runs, { recursive: true });
  const stage = await mkdtemp(path.join(runs, "run-"));
  const source = path.join(stage, "src");
  await mkdir(source);

  const configuration = JSON.parse(await readFile(path.join(root, "tests/logic/abap_transpile.json"), "utf8"));
  if (configuration.libs?.[0]?.ref !== coreRevision) {
    throw new Error("Unexpected open-abap-core revision in logic-test configuration");
  }
  await writeFile(path.join(stage, "abap_transpile.json"), JSON.stringify(configuration, null, 2));

  const manifest = [];
  let expectedTests = 0;
  for (const name of await readdir(path.join(root, "src"))) {
    if (!sourceObjects.some((object) => name.startsWith(`${object}.`))
        && !/^zche_.*\.(?:doma|dtel|tabl)\.xml$/u.test(name)
        && name !== "zcl_che_tcmb_rate_store.clas.xml") continue;
    const original = path.join(root, "src", name);
    await copyFile(original, path.join(source, name));
    const content = await readFile(original);
    manifest.push({ file: `src/${name}`, sha256: createHash("sha256").update(content).digest("hex") });
    if (name.endsWith(".testclasses.abap")) {
      expectedTests += [...content.toString("utf8").matchAll(/^\s*METHODS\s+\w+\s+FOR TESTING\b/gmu)].length;
    }
  }
  for (const name of await readdir(path.join(root, "tests/logic/stubs"))) {
    await copyFile(path.join(root, "tests/logic/stubs", name), path.join(source, name));
  }
  await writeFile(path.join(stage, "source-manifest.json"), JSON.stringify(manifest, null, 2));
  console.log(`Logic-test evidence: ${stage}`);

  const transpiler = path.join(root, "node_modules/@abaplint/transpiler-cli/abap_transpile");
  const buildOutput = await run([transpiler], stage, "transpile.log");
  if (!buildOutput.includes(`commit: ${coreRevision}`)) {
    throw new Error("The transpiler did not confirm the pinned open-abap-core revision");
  }
  const testOutput = await run([path.join(stage, "output/index.mjs")], stage, "runtime.log");
  const executedTests = [...testOutput.matchAll(/: running /gu)].length;
  if (expectedTests === 0 || executedTests !== expectedTests) {
    throw new Error(`Expected ${expectedTests} logic tests, but the runner reported ${executedTests}`);
  }
  console.log(`${executedTests} transpiled logic tests passed; SAP runtime acceptance remains required.`);
} catch (error) {
  console.error(error.message ?? error);
  process.exitCode = 1;
}
