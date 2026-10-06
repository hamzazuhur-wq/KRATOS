const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  await page.goto('http://127.0.0.1:3000/?preview=wave13&theme=dark');
  await page.waitForTimeout(3000);
  
  const shadowHtml = await page.evaluate(() => {
    const pane = document.querySelector('flt-glass-pane');
    if (!pane) return 'No glass pane';
    if (!pane.shadowRoot) return 'No shadow root';
    return pane.shadowRoot.innerHTML.substring(0, 1000);
  });
  console.log('SHADOW ROOT HTML:\n', shadowHtml);

  await browser.close();
})();
