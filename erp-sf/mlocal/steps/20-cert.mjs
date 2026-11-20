// Imports the staging signing keystore into the scratch org via Setup > Certificate and Key Management.
// There is no API/metadata path for keystore import, so this drives the UI headlessly.
// usage: node 20-cert.mjs [--probe] [--manual]
import { createRequire } from 'module';
import { execFileSync } from 'child_process';
import { readFileSync, readdirSync, existsSync, mkdirSync } from 'fs';
import os from 'os';
import path from 'path';

const home = process.env.ML_HOME || path.join(os.homedir(), '.manabie-local');
const cfg = Object.fromEntries(readFileSync(path.join(home, 'config.env'), 'utf8').split('\n')
  .filter((l) => /^[A-Z_]+=/.test(l)).map((l) => {
    const i = l.indexOf('=');
    let v = l.slice(i + 1).replace(/\s+#.*$/, '').trim();
    return [l.slice(0, i), v.replace(/^"|"$/g, '')];
  }));
const probe = process.argv.includes('--probe');
const manual = process.argv.includes('--manual');
const require = createRequire(path.join(cfg.REPO_ROOT || process.env.REPO_ROOT, 'package.json'));
const { chromium } = require('playwright');
mkdirSync(path.join(home, 'logs'), { recursive: true });
const shot = async (page, name) => page.screenshot({ path: path.join(home, 'logs', `cert-${name}.png`), fullPage: true }).catch(() => {});

// already imported? (Tooling API, no UI needed)
const q = JSON.parse(execFileSync('sf', ['data', 'query', '-o', cfg.ORG_ALIAS, '--use-tooling-api', '--json', '-q',
  `SELECT Id FROM Certificate WHERE DeveloperName='${cfg.CERT_NAME}'`], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }));
if (q.result.totalSize > 0 && !probe) { console.log(`  ok  certificate ${cfg.CERT_NAME} already present`); process.exit(0); }
if (!probe && !manual && !cfg.JKS_PASSWORD) { console.error('  FAIL JKS_PASSWORD is empty in config.env (or run: mlocal cert --manual)'); process.exit(2); }
if (!existsSync(cfg.JKS_PATH)) { console.error(`  FAIL keystore not found: ${cfg.JKS_PATH}`); process.exit(2); }

const cache = path.join(os.homedir(), 'Library/Caches/ms-playwright');
const chromeDir = readdirSync(cache).filter((d) => d.startsWith('chromium-')).sort().pop();
const exe = chromeDir && readdirSync(path.join(cache, chromeDir)).map((a) => path.join(cache, chromeDir, a,
  'Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing')).find(existsSync);

const open = JSON.parse(execFileSync('sf', ['org', 'open', '-o', cfg.ORG_ALIAS, '--path', '/lightning/setup/CertificatesAndKeysManagement/home', '--url-only', '--json'],
  { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }));
const browser = await chromium.launch({ headless: !manual, executablePath: exe });
const page = await (await browser.newContext({ viewport: { width: 1400, height: 1000 } })).newPage();
try {
  await page.goto(open.result.url, { waitUntil: 'commit' }).catch(() => {}); // login redirect chain interrupts goto
  await page.waitForURL(/salesforce-setup\.com|lightning\.force\.com\/lightning\/setup/, { timeout: 90000 }).catch(() => {});
  await page.waitForLoadState('load').catch(() => {}); await page.waitForTimeout(4000);
  if (manual) { console.log('  Import the keystore in the opened window, then close it.'); await page.waitForEvent('close', { timeout: 0 }); process.exit(0); }
  // Setup pages render inside iframes; find the frame that holds a selector
  const inFrames = async (sel, ms = 60000) => {
    const end = Date.now() + ms;
    while (Date.now() < end) {
      for (const fr of page.frames()) { const l = fr.locator(sel).first(); if (await l.count().catch(() => 0)) return l; }
      await page.waitForTimeout(700);
    }
    throw new Error(`selector not found in any frame: ${sel}`);
  };
  await (await inFrames('input[value="Import from Keystore"], button:has-text("Import from Keystore")')).click();
  await page.waitForTimeout(3000); await shot(page, '1-import-page');
  await (await inFrames('input[type=file]')).setInputFiles(cfg.JKS_PATH);
  await (await inFrames('input[type=password]')).fill(probe ? 'probe-wrong-password' : cfg.JKS_PASSWORD);
  await shot(page, '2-filled');
  await (await inFrames('input[value="Save"], input[type=submit], button[type=submit]')).click();
  await page.waitForTimeout(5000); await shot(page, '3-after-save');
  if (probe) { console.log('  probe done; see ~/.manabie-local/logs/cert-*.png'); process.exit(0); }
  // the keystore can hold several aliases; accept the one named like CERT_NAME, otherwise the first
  const save = await inFrames('input[value="Save"], input[value="Import"], button:has-text("Save")', 8000).catch(() => null);
  if (save) { await save.click(); await page.waitForTimeout(5000); }
  await shot(page, '4-done');
} catch (e) {
  await shot(page, 'error'); console.error('  FAIL cert import: ' + e.message + ' (screenshot in ~/.manabie-local/logs)'); process.exit(1);
} finally { await browser.close(); }
const after = JSON.parse(execFileSync('sf', ['data', 'query', '-o', cfg.ORG_ALIAS, '--use-tooling-api', '--json', '-q',
  `SELECT DeveloperName FROM Certificate`], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })).result.records.map((r) => r.DeveloperName);
if (!after.includes(cfg.CERT_NAME)) { console.error(`  FAIL ${cfg.CERT_NAME} not present after import; certificates: ${after.join(', ')} (rename in Setup if the keystore alias differs)`); process.exit(1); }
console.log(`  ok  certificate ${cfg.CERT_NAME} imported`);
