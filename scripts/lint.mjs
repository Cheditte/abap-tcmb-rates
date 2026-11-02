import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const cli = fileURLToPath(new URL('../node_modules/@abaplint/cli/abaplint', import.meta.url));
try {
  execFileSync(process.execPath, [cli, 'abaplint.json'], {cwd:root, stdio:'inherit', windowsHide:true});
} catch (error) {
  process.exitCode = error.status ?? 1;
}
