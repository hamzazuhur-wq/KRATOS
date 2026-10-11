const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await page.waitForTimeout(4500);

  // Click Date Range pill (x: 280, y: 200)
  console.log('Clicking Date Range pill...');
  await page.mouse.click(280, 200);
  await page.waitForTimeout(1000);

  // Click "Last 7 Days" (first item in the popup menu, x: 280, y: 265)
  console.log('Clicking Last 7 Days...');
  await page.mouse.click(280, 265);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'screenshots/wave03_fix_date_range_7d.png' });

  // Click Source filter pill (3rd pill: x ~ 530, y: 200)
  console.log('Clicking Source filter pill...');
  await page.mouse.click(530, 200);
  await page.waitForTimeout(1000);

  // Click "Tasks" (second item in popup menu: x: 530, y: 310)
  console.log('Clicking Tasks source...');
  await page.mouse.click(530, 310);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'screenshots/wave03_fix_source_tasks.png' });

  await browser.close();
  console.log('✅ Filter test captures completed.');
})();
