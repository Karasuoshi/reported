import { chromium } from 'playwright';
import { mkdir, readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';

const base = 'http://127.0.0.1:8765';
const pages = [{ path: '/', name: 'novice' }, { path: '/addons.html', name: 'addon' }];
const sizes = [{ name: 'desktop', width: 1440, height: 900 }, { name: 'mobile', width: 390, height: 844 }];
const server = spawn('python3', ['-m', 'http.server', '8765', '--bind', '127.0.0.1'], { stdio: 'ignore' });
let browser;
const failures = [];
const check = (ok, message) => { if (!ok) failures.push(message); };
try {
  await mkdir('site-screenshots', { recursive: true });
  for (let i = 0; i < 40; i++) {
    try { const r = await fetch(base); if (r.ok) break; } catch {}
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  browser = await chromium.launch({ headless: true });
  for (const size of sizes) {
    const context = await browser.newContext({ viewport: { width: size.width, height: size.height }, deviceScaleFactor: 1 });
    for (const item of pages) {
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => { if (r.url().startsWith(base) && r.status() >= 400) errors.push('HTTP ' + r.status() + ': ' + r.url()); });
      const response = await page.goto(base + item.path, { waitUntil: 'networkidle', timeout: 30000 });
      check(response?.ok(), size.name + ' ' + item.name + ': page unavailable');
      await page.screenshot({ path: 'site-screenshots/' + item.name + '-' + size.name + '.png', fullPage: true });
      const info = await page.evaluate(() => ({
        broken: [...document.images].filter(x => !x.complete || x.naturalWidth === 0).map(x => x.src),
        horizontalOverflow: document.documentElement.scrollWidth > innerWidth + 2,
        internalLinks: [...document.querySelectorAll('a[href]')].map(x => x.getAttribute('href')).filter(x => x && !x.startsWith('#') && !/^https?:|^mailto:/.test(x)),
        body: document.body.innerText
      }));
      check(!info.broken.length, size.name + ' ' + item.name + ': broken images: ' + info.broken.join(', '));
      check(!info.horizontalOverflow, size.name + ' ' + item.name + ': horizontal overflow');
      check(!errors.length, size.name + ' ' + item.name + ': ' + errors.join('; '));
      check(!/beget\.tech|чат гильдии/i.test(info.body), size.name + ' ' + item.name + ': forbidden public text');
      for (const href of info.internalLinks) {
        const url = new URL(href, base + item.path);
        if (url.origin === base) {
          const r = await fetch(url);
          check(r.ok, size.name + ' ' + item.name + ': broken link ' + href + ' (' + r.status + ')');
        }
      }
      await page.close();
    }
    await context.close();
  }
} catch (e) {
  failures.push(String(e.stack || e));
} finally {
  await browser?.close();
  server.kill();
}
if (failures.length) {
  console.error('SITE CHECK FAILED:\n' + failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log('SITE CHECK PASSED: 4 screenshots saved in site-screenshots/');
}
