// Writes the German texts of every server error code, as club-client shows them, to ClubKit/Contract/error-texts.json.
// The texts live in club-client's TypeScript catalogs (some built from its settings), so they are imported, not parsed.
import { registerHooks } from 'node:module';
import { readdirSync, writeFileSync } from 'node:fs';

const src = new URL('../../club-client/src/', import.meta.url);

registerHooks({
  // club-client imports without extensions (Vite resolves them).
  resolve(specifier, context, next) {
    try {
      return next(specifier, context);
    } catch (error) {
      if (!specifier.startsWith('.')) throw error;
      return next(`${specifier}.ts`, context);
    }
  },
  // settings.ts reads Vite's import.meta.env.
  load(url, context, next) {
    const result = next(url, context);
    if (!url.endsWith('/settings.ts')) return result;
    return { ...result, source: String(result.source).replace('import.meta.env', '({})') };
  },
});

const files = [
  'lib/errors/coreMessages.ts',
  'lib/links/messages.ts',
  ...readdirSync(new URL('features/', src), { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => `features/${d.name}/messages.ts`)
    .filter((f) => readdirSync(new URL(f.replace(/messages\.ts$/, ''), src)).includes('messages.ts')),
];

const texts = {};
let status, unknown;
for (const file of files) {
  const module = await import(new URL(file, src));
  for (const [name, value] of Object.entries(module)) {
    if (name === 'STATUS_MESSAGES') status = value;
    else if (name === 'UNKNOWN_MESSAGE') unknown = value;
    else if (name.endsWith('_MESSAGES')) Object.assign(texts, value);
  }
}
const sorted = Object.fromEntries(Object.entries(texts).sort(([a], [b]) => a.localeCompare(b)));
const out = new URL('../ClubKit/Contract/error-texts.json', import.meta.url);
writeFileSync(out, `${JSON.stringify({ codes: sorted, status, unknown }, null, 2)}\n`);
console.log(`error-texts.json: ${Object.keys(sorted).length} codes`);
