const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  await page.goto('http://127.0.0.1:3000/?preview=wave13&theme=dark');
  await page.waitForTimeout(3000);
  
  await page.mouse.wheel(0, 1000);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'screenshots/wave13_scrolled_1000.png' });
  
  await page.mouse.wheel(0, 1000);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'screenshots/wave13_scrolled_2000.png' });

  await browser.close();
})();
