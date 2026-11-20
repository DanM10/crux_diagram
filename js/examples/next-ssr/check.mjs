// After `npm run build`: the server-rendered HTML holds the drawing's accessible group.
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('./.next/server/app/index.html', import.meta.url), 'utf8');
if (!html.includes('Drawing with 1 shape and 0 joints')) {
  console.error('The prerendered page does not contain the drawing description.');
  process.exit(1);
}
console.log('SSR output contains the drawing description.');
