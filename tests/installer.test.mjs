import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { build } from '../scripts/build-installer.mjs';

const root = new URL('../', import.meta.url);
const decode = (expression) => [...expression.matchAll(/`((?:``|[^`])*)`/gu)]
  .map((m) => m[1].replaceAll('``', '`')).join('');

test('generated ABAP embeds exact sources, unit tests and complete DDIC metadata', async () => {
  const { text, objects } = await build();
  const blocks = text.split('\nFORM embedded_payload.')[1].split('  CLEAR item.\n').slice(1);
  assert.equal(blocks.length, objects.length);
  for (const [i, object] of objects.entries()) {
    const block = blocks[i];
    assert.ok(block.includes(`item-name = '${object.name}'.`));
    assert.equal(decode(block.match(/item-xml = ([\s\S]*?)\.\n/u)[1]), object.xml);
    for (const key of ['source', 'tests']) {
      // Match each assignment independently; do not consume another source/test append.
      const actual = [...block.matchAll(/gv_line = ((?:`(?:``|[^`])*`\s*(?:&&\s*)?)+)\.\n  APPEND gv_line TO item-(source|tests)\./gu)]
        .filter(m => m[2] === key).map(m => decode(m[1]));
      assert.equal(actual.join('\n'), object[key] ?? '', `${object.name} ${key}`);
    }
    if (object.xml) assert.ok(!object.xml.includes('\n'), 'XML must not introduce multiline ABAP literals');
  }
});

test('every repository object and test include is shipped, with DDIC parents first', async () => {
  const { objects } = await build();
  const allFiles = await readdir(new URL('src/', root));
  const metadata = allFiles.filter(n => /\.(doma|dtel|tabl|intf|clas|prog)\.xml$/u.test(n));
  assert.equal(objects.length, metadata.length);
  const index = name => objects.findIndex(o => o.name === name);
  assert.ok(index('ZCHE_TCMB_PROF') < index('ZCHE_TCMB_MAP'));
  assert.ok(index('ZCHE_TCMB_PROF') < index('ZCHE_TCMB_CURR'));
  for (const object of objects) {
    if (object.type === 'DTEL' && object.xml.includes('<DOMNAME>ZCHE_')) assert.ok(index(object.xml.match(/<DOMNAME>(ZCHE_[^<]*)/u)[1]) < objects.indexOf(object));
  }
  for (const file of allFiles.filter(n => n.endsWith('.testclasses.abap'))) {
    const object = objects.find(o => o.name === file.split('.')[0].toUpperCase());
    assert.equal(object?.tests, (await readFile(new URL(`src/${file}`, root), 'utf8')).replaceAll('\r\n', '\n').trimEnd());
  }
  assert.ok(objects.some(o => o.name === 'ZCHE_TCMB_CONFIG' && o.source));
  assert.ok(objects.some(o => o.name === 'ZCL_CHE_TCMB_CONFIG_RULES' && o.tests));
});

test('date-rule domain accommodates the full runtime value without truncated DD07 fixed values', async () => {
  const xml = await readFile(new URL('src/zche_tcmb_date_rule.doma.xml', root), 'utf8');
  const choices = [...xml.matchAll(/<DOMVALUE_L>([^<]+)<\/DOMVALUE_L>/gu)].map(m => m[1]);
  // Classic DD07V fixed values have a narrower limit than the CHAR12 field.
  assert.deepEqual(choices, []);
  const max = Number(xml.match(/<LENG>(\d+)<\/LENG>/u)[1]);
  assert.ok('NEXT_WORKDAY'.length <= max);
});
