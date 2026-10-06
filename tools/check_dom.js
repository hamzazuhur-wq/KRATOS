const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  await page.goto('http://127.0.0.1:3000/?preview=wave13&theme=dark');
  await page.waitForTimeout(3000);
  
  const text = await page.evaluate(() => document.body.innerText);
  console.log('BODY TEXT PREVIEW:', text.substring(0, 500));
  
  const canvasCount = await page.evaluate(() => document.querySelectorAll('canvas').length);
  console.log('CANVAS COUNT:', canvasCount);

  await browser.close();
})();
