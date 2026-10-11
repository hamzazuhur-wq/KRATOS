const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await page.waitForTimeout(5000);

  // 1. Initial All Sources
  console.log('Capturing All Sources...');
  await page.screenshot({ path: path.join('screenshots', 'wave04_verify_source_all.png') });

  // 2. Select Tasks
  console.log('Selecting Tasks source filter...');
  await page.mouse.click(530, 200);
  await page.waitForTimeout(1000);
  await page.mouse.click(530, 310);
  await page.waitForTimeout(2500);
  console.log('Capturing Tasks source filter result...');
  await page.screenshot({ path: path.join('screenshots', 'wave04_verify_source_tasks.png') });

  // 3. Select Goals
  console.log('Selecting Goals source filter...');
  await page.mouse.click(530, 200);
  await page.waitForTimeout(1000);
  await page.mouse.click(530, 355);
  await page.waitForTimeout(2500);
  console.log('Capturing Goals source filter result...');
  await page.screenshot({ path: path.join('screenshots', 'wave04_verify_source_goals.png') });

  await browser.close();
  console.log('✅ Source filter verification screenshots captured.');
})();
