const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const profileDir = path.join(__dirname, '.test_persistent_profile');
  const context = await chromium.launchPersistentContext(profileDir, {
    viewport: { width: 1440, height: 900 },
    headless: true,
  });
  const page = context.pages()[0] || await context.newPage();

  page.on('console', msg => console.log('[BROWSER ' + msg.type() + ']', msg.text()));
  page.on('pageerror', err => console.error('[PAGEERROR]', err.message));

  console.log('--- Targeted Final Dashboard Verification ---');
  const startTime = Date.now();
  await page.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  
  // Wait 15s for full Wasm initialization and render
  await page.waitForTimeout(15000);
  
  await page.screenshot({ path: 'screenshots/runtime_verification/final_dashboard.png' });
  console.log('Captured screenshots/runtime_verification/final_dashboard.png in ' + (Date.now() - startTime) + 'ms');

  await context.close();
})();
