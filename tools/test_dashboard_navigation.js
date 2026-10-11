const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  console.log('Navigating to Dashboard at 1440x900...');
  await page.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  await page.waitForTimeout(5000);

  // 1. Click Tasks (around X=100, Y=256)
  console.log('Clicking Tasks in sidebar (100, 256)...');
  await page.mouse.click(100, 256);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'dashboard_clean_slate_navigation_tasks.png') });
  console.log('Captured Tasks screen.');

  // 2. Click Goals (around X=100, Y=305)
  console.log('Clicking Goals in sidebar (100, 305)...');
  await page.mouse.click(100, 305);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'dashboard_clean_slate_navigation_goals.png') });
  console.log('Captured Goals screen.');

  // 3. Click Stats (around X=100, Y=455)
  console.log('Clicking Stats in sidebar (100, 455)...');
  await page.mouse.click(100, 455);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'dashboard_clean_slate_navigation_stats.png') });
  console.log('Captured Stats screen.');

  // 4. Click back to Home / Dashboard (around X=100, Y=160)
  console.log('Clicking Home in sidebar (100, 160)...');
  await page.mouse.click(100, 160);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'dashboard_clean_slate_navigation_back_home.png') });
  console.log('Captured Back to Home screen.');

  await browser.close();
  console.log('Navigation test completed successfully.');
})();
