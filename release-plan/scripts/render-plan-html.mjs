#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { basename } from 'node:path';

const src = process.argv[2];
if (!src) { console.error('usage: render-plan-html.mjs <plan.md> [out.html]'); process.exit(1); }
const md = readFileSync(src, 'utf8');
const out = process.argv[3] || `/tmp/${basename(src).replace(/\.md$/, '')}.html`;

const esc = md.replace(/<\/script>/g, '<\\/script>');
const html = `<!doctype html><html><head><meta charset="utf-8"><title>${basename(src)}</title>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"><\/script>
<style>
body{max-width:860px;margin:40px auto;padding:0 24px;font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;color:#1f2328}
h1{border-bottom:2px solid #d0d7de;padding-bottom:.3em}
h2{border-bottom:1px solid #d0d7de;padding-bottom:.3em;margin-top:2em}
table{border-collapse:collapse;width:100%;margin:1em 0;font-size:14px}
th,td{border:1px solid #d0d7de;padding:8px 10px;text-align:left;vertical-align:top}
th{background:#f6f8fa}
code{background:#eff1f3;padding:2px 6px;border-radius:6px;font-size:85%}
hr{border:0;border-top:1px solid #d0d7de;margin:2em 0}
blockquote,em{color:#57606a}
</style></head><body><div id="c"></div>
<script>document.getElementById("c").innerHTML=marked.parse(${JSON.stringify(esc)});<\/script>
</body></html>`;
writeFileSync(out, html);
console.log(out);
