import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
const root = new URL('../',import.meta.url);
const names = (await readdir(new URL('src/',root))).sort();
assert.deepEqual(names,['package.devc.xml','zche_tcmb_load.prog.abap','zche_tcmb_load.prog.xml']);
const source = (await readFile(new URL('src/zche_tcmb_load.prog.abap',root),'utf8')).replaceAll('\r\n','\n');
const metadata = await readFile(new URL('src/zche_tcmb_load.prog.xml',root),'utf8');
assert.match(source,/^REPORT zche_tcmb_load\./m);
assert.match(metadata,/<NAME>ZCHE_TCMB_LOAD<\/NAME>/);
assert.ok(!source.includes('\uFFFD'),'Invalid UTF-8 replacement character');
assert.ok(source.split('\n').every(l=>l.length<=255),'A line exceeds the classic editor maximum of 255');
const code = source.split('\n').map(l=>l.startsWith('*')?'':l.replace(/'(?:''|[^'])*'|`(?:``|[^`])*`/g,'literal').split('"')[0]).join('\n');
// Supplemental restrictions; neither this scan nor lint proves SAP 7.00 runtime.
for (const forbidden of [/\bWITH\s+EMPTY\s+KEY/i,/\bRISK\s+LEVEL\b/i,/\bDURATION\s+(?:SHORT|MEDIUM|LONG)\b/i,/\b(?:DATA|FIELD-SYMBOL|FINAL)\s*\(/i,/\b(?:NEW|VALUE|CONV|COND|SWITCH|REDUCE|CORRESPONDING)\s+[\w#]*\s*\(/i,/\bDECFLOAT(?:16|34)\b/i,/\bCL_ABAP_UNIT_ASSERT\b/i,/##\w/,/\bRESPECTING\s+BLANKS\b/i,/&&/,/\|/]) {
  assert.ok(!forbidden.test(code),'Post-7.00 syntax restriction: '+forbidden);
}
const count=[...source.matchAll(/^\s*METHODS\s+\w+\s+FOR TESTING\b/gmi)].length;
assert.ok(count>=34,'Embedded SAP test suite is missing');
console.log('Single report and classic syntax restrictions checked; '+count+' embedded SAP tests discovered, not executed.');
