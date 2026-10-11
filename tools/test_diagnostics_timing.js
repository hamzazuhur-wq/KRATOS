const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const profileDir = path.join(__dirname, '..', '.test_persistent_profile');
  const context = await chromium.launchPersistentContext(profileDir, {
    viewport: { width: 1440, height: 900 },
    headless: true,
  });
  const page = context.pages()[0] || await context.newPage();

  page.on('console', msg => {
    const d = new Date().toISOString().substring(14, 23);
    console.log(`[${d}] [BROWSER ${msg.type()}] ${msg.text()}`);
  });
  page.on('pageerror', err => console.error('[PAGEERROR]', err.message));

  console.log('--- Testing projects with 25s wait ---');
  await page.goto('http://127.0.0.1:3000/?preview=projects&theme=dark', { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  await page.screenshot({ path: 'screenshots/runtime_verification/timing_projects.png' });
  console.log('Captured timing_projects.png');

  console.log('\n--- Testing levels with 20s wait ---');
  await page.goto('http://127.0.0.1:3000/?preview=levels&theme=dark', { waitUntil: 'load' });
  await page.waitForTimeout(20000);
  await page.screenshot({ path: 'screenshots/runtime_verification/timing_levels.png' });
  console.log('Captured timing_levels.png');

  console.log('\n--- Testing dashboard with 20s wait ---');
  await page.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  await page.waitForTimeout(20000);
  await page.screenshot({ path: 'screenshots/runtime_verification/timing_dashboard.png' });
  console.log('Captured timing_dashboard.png');

  await context.close();
  console.log('Done timing diagnostics.');
})();
