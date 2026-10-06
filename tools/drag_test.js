const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  await page.goto('http://127.0.0.1:3000/?preview=wave13&theme=dark');
  await page.waitForTimeout(3000);

  // Drag mouse down to scroll up
  await page.mouse.move(700, 300);
  await page.mouse.down();
  await page.mouse.move(700, 700, { steps: 10 });
  await page.mouse.up();
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'screenshots/wave13_top_drag.png' });

  await browser.close();
})();
