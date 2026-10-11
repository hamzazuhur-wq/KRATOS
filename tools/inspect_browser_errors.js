const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {
  const profileDir = path.join(__dirname, '..', '.playwright_inspect_profile');
  if (fs.existsSync(profileDir)) {
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
  const context = await chromium.launchPersistentContext(profileDir, {
    viewport: { width: 1440, height: 900 },
    headless: true,
  });
  const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();

  page.on('console', msg => {
    console.log(`[BROWSER ${msg.type()}]`, msg.text());
  });

  page.on('pageerror', err => {
    console.error('[PAGE ERROR]', err.message, err.stack);
  });

  console.log('--- Loading Dashboard ---');
  await page.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  await page.waitForTimeout(10000);

  console.log('--- Clicking Due Today (80, 200) ---');
  await page.mouse.click(80, 200);
  await page.waitForTimeout(4000);

  console.log('--- Clicking Back (30, 30) ---');
  await page.mouse.click(30, 30);
  await page.waitForTimeout(1500);

  console.log('--- Clicking Levels (80, 470) ---');
  await page.mouse.click(80, 470);
  await page.waitForTimeout(4000);

  console.log('--- Clicking Back (30, 30) ---');
  await page.mouse.click(30, 30);
  await page.waitForTimeout(1500);

  console.log('--- Clicking Projects (80, 605) ---');
  await page.mouse.click(80, 605);
  await page.waitForTimeout(4000);

  console.log('--- Clicking Back (30, 30) ---');
  await page.mouse.click(30, 30);
  await page.waitForTimeout(1500);

  console.log('--- Clicking Profile (80, 50) ---');
  await page.mouse.click(80, 50);
  await page.waitForTimeout(4000);

  console.log('--- Navigating to Calendar Preview ---');
  await page.goto('http://127.0.0.1:3000/?preview=calendar&theme=dark', { waitUntil: 'load' });
  await page.waitForTimeout(5000);

  await context.close();
  console.log('--- Done Inspection ---');
})();
