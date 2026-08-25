import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';

// Usage: node render.mjs [source.html] [output.pdf]
// Defaults to informe.html in the current working directory.
const here = process.cwd();
const srcName = process.argv[2] || 'informe.html';
const outName = process.argv[3] || srcName.replace(/\.html$/, '.pdf');
const src = 'file://' + path.resolve(here, srcName);
void fileURLToPath;

// An icon class that has no matching rule in brand.css renders as an empty box.
// Catch that here rather than by squinting at 16 page previews.
const css = fs.readFileSync(path.resolve(here, 'assets', 'brand.css'), 'utf8');
const html = fs.readFileSync(path.resolve(here, srcName), 'utf8');
const defined = new Set([...css.matchAll(/\.ico-([a-z0-9-]+)\s*\{/g)].map((m) => m[1]));
const used = new Set([...html.matchAll(/\bico-([a-z0-9-]+)\b/g)].map((m) => m[1]));
const undefinedIcons = [...used].filter((n) => !defined.has(n) && n !== 'list');
console.log(undefinedIcons.length ? `ICONS MISSING: ${undefinedIcons.join(', ')}` : 'ICONS: all resolved');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1000, height: 1400 } });
await page.goto(src, { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts.ready);

const layout = await page.evaluate(() => {
  const over = [];
  const sparse = [];
  const orphans = [];

  document.querySelectorAll('.page').forEach((el, i) => {
    const n = i + 1;
    if (el.scrollHeight > el.clientHeight + 2) {
      over.push({ page: n, by: el.scrollHeight - el.clientHeight });
    }
    if (el.classList.contains('cover') || el.classList.contains('closing')) return;

    const box = el.getBoundingClientRect();
    const padBottom = parseFloat(getComputedStyle(el).paddingBottom);
    const foot = el.querySelector('.foot');
    const footTop = foot ? foot.getBoundingClientRect().top : box.top + el.clientHeight - padBottom;
    const blocks = [...el.children].filter((c) => !c.classList.contains('foot'));
    if (!blocks.length) return;

    // How much dead space sits between the last block and the footer.
    const lastBottom = Math.max(...blocks.map((c) => c.getBoundingClientRect().bottom));
    const gap = Math.round(footTop - lastBottom);
    if (gap > 150) sparse.push({ page: n, gap });

    // A short trailing block after a big one reads as a stranded paragraph.
    const last = blocks[blocks.length - 1];
    const lastH = last.getBoundingClientRect().height;
    if (blocks.length > 2 && lastH < 40 && gap > 60) {
      orphans.push({ page: n, tag: last.className, height: Math.round(lastH) });
    }
  });
  return { over, sparse, orphans };
});

const report = (label, rows) =>
  console.log(rows.length ? `${label}: ${JSON.stringify(rows)}` : `${label}: none`);

report('OVERFLOW', layout.over);
report('SPARSE (>150px dead space)', layout.sparse);
report('ORPHAN BLOCKS', layout.orphans);

// Text that vanishes into its own background. A global `strong { color: ink }`
// silently swallowed bold text on dark panels twice; measure it instead of squinting.
const contrast = await page.evaluate(() => {
  const lum = (rgb) => {
    const raw = rgb.startsWith('#')
      ? [1, 3, 5].map((i) => parseInt(rgb.slice(i, i + 2), 16))
      : rgb.match(/[\d.]+/g).slice(0, 3).map(Number);
    const [r, g, b] = raw.map((v) => {
      const c = v / 255;
      return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const bgOf = (el) => {
    for (let n = el; n; n = n.parentElement) {
      // Gradients are background-image, unreadable from the tree: the page declares
      // its worst-case (lightest) stop via data-bg so the check stays honest.
      if (n.dataset && n.dataset.bg) return n.dataset.bg;
      const bg = getComputedStyle(n).backgroundColor;
      const a = bg.match(/[\d.]+/g);
      if (a && (a.length < 4 || Number(a[3]) > 0.5)) return bg;
    }
    return 'rgb(255,255,255)';
  };
  const bad = [];
  document.querySelectorAll('p,span,td,th,li,h1,h2,h3,h4,strong,em,div').forEach((el) => {
    const text = [...el.childNodes]
      .filter((n) => n.nodeType === 3)
      .map((n) => n.textContent.trim())
      .join('');
    if (text.length < 2) return;
    const st = getComputedStyle(el);
    const l1 = lum(st.color);
    const l2 = lum(bgOf(el));
    const ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
    const px = parseFloat(st.fontSize);
    const large = px >= 24 || (px >= 18.66 && Number(st.fontWeight) >= 700);
    if (ratio < (large ? 3 : 4.5)) {
      bad.push({ ratio: Number(ratio.toFixed(2)), text: text.slice(0, 45), tag: el.tagName });
    }
  });
  return bad;
});
report('LOW CONTRAST', contrast);

await page.pdf({
  path: path.resolve(here, outName),
  format: 'A4',
  printBackground: true,
  margin: { top: 0, right: 0, bottom: 0, left: 0 },
});

fs.rmSync(path.join(here, 'preview'), { recursive: true, force: true });
fs.mkdirSync(path.join(here, 'preview'));
const pages = await page.$$('.page');
for (let i = 0; i < pages.length; i++) {
  await pages[i].screenshot({ path: path.join(here, `preview/p${String(i + 1).padStart(2, '0')}.png`) });
}
console.log(`rendered ${pages.length} pages -> ${outName}`);

await browser.close();
