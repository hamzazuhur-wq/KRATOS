const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  let completed = false;
  page.on('console', msg => {
    const t = msg.text();
    console.log(`[CONSOLE ${msg.type()}]`, t);
    if (t.includes('bootstrapDevUser completed!')) {
      completed = true;
    }
  });
  page.on('pageerror', err => {
    console.log('[PAGE ERROR]', err.message);
  });

  page.on('requestfailed', req => {
    console.log('[REQ FAILED]', req.url(), req.failure() ? req.failure().errorText : '');
  });

  console.log('Navigating to http://127.0.0.1:3000/?preview=dashboard&theme=dark ...');
  await page.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  console.log('Waiting for seed completion (up to 60s)...');
  for (let i = 0; i < 60; i++) {
    if (completed) {
      console.log(`Seed completed after ${i} seconds!`);
      break;
    }
    await page.waitForTimeout(1000);
  }
  // Wait another 3s for Flutter widgets to paint
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshots/runtime_verification/01_Dashboard_seeded.png' });
  console.log('Captured 01_Dashboard_seeded.png');

  await browser.close();
})();
