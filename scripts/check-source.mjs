import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
const root = new URL('../',import.meta.url);
const names = (await readdir(new URL('src/',root))).sort();
assert.deepEqual(names,['package.devc.xml','zche_tcmb_load.prog.abap','zche_tcmb_load.prog.xml']);
const source = (await readFile(new URL('src/zche_tcmb_load.prog.abap',root),'utf8')).replaceAll('\r\n','\n');
const metadata = await readFile(new URL('src/zche_tcmb_load.prog.xml',root),'utf8');
assert.match(source,/^REPORT zche_tcmb_load\./m);
assert.match(metadata,/<NAME>ZCHE_TCMB_LOAD<\/NAME>/);
assert.match(metadata,/<FIXPT>X<\/FIXPT>/,'abapGit imports must enable fixed-point arithmetic');
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

const production=source.split('*& Unit tests:')[0];
const messageMethod=production.match(/  METHOD message\.([\s\S]*?)  ENDMETHOD\./)?.[1];
assert.ok(messageMethod,'Missing message catalog');
const definitions=[...messageMethod.matchAll(/WHEN '([A-Z_]+)'\.\s+lv_template = choose\(\s+iv_en = `((?:``|[^`])*)`\s+iv_tr = `((?:``|[^`])*)` \)\./g)];
const keys=new Set();
for(const [,key,en,tr] of definitions){
  assert.ok(!keys.has(key),'Duplicate message key '+key);
  keys.add(key);
  assert.ok(en.trim()&&tr.trim(),'Empty translation for '+key);
  const slots=s=>[...new Set(s.match(/&[1-4]/g)||[])].sort();
  assert.deepEqual(slots(en),slots(tr),'Translation loses parameters for '+key);
}
assert.ok(keys.size>0,'Empty message catalog');
for(const [,key] of production.matchAll(/(?:iv_key|text_key)\s*=\s*'([A-Z_]+)'/g)){
  assert.ok(keys.has(key),'Undefined production message key '+key);
}
const show=production.match(/  METHOD show\.([\s\S]*?)  ENDMETHOD\./)?.[1]||'';
const columns=new Set([...show.matchAll(/iv_name = '([A-Z_]+)'/g)].map(m=>m[1]));
const lineType=production.match(/BEGIN OF ty_line,([\s\S]*?)END OF ty_line/)?.[1]||'';
for(const [,field] of lineType.matchAll(/(\w+)\s+TYPE/g))assert.ok(columns.has(field.toUpperCase()),'Missing localized ALV header '+field);
assert.ok(columns.has('STATUS_TEXT'),'Missing localized status description');
console.log(keys.size+' bilingual message templates checked for references/parameter parity; '+columns.size+' ALV headers covered.');
