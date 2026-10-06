const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  await page.goto('http://127.0.0.1:3000/?preview=wave13&theme=dark');
  await page.waitForTimeout(3000);
  
  const html = await page.evaluate(() => document.querySelector('flt-glass-pane') ? document.querySelector('flt-glass-pane').outerHTML.substring(0, 500) : document.body.innerHTML.substring(0, 1000));
  console.log('HTML STRUCTURE:\n', html);

  await browser.close();
})();
