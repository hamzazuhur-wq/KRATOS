const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  page.on('console', msg => console.log(`[${msg.type()}]`, msg.text()));
  page.on('pageerror', err => console.error('[PAGE ERROR]', err.message));

  console.log('Navigating and waiting 25s...');
  await page.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark');
  await page.waitForTimeout(25000);

  // Check OPFS files
  const files = await page.evaluate(async () => {
    try {
      const root = await navigator.storage.getDirectory();
      const names = [];
      for await (const name of root.keys()) {
        names.push(name);
      }
      return { success: true, names };
    } catch (e) {
      return { success: false, error: e.message };
    }
  });
  console.log('OPFS root files:', files);

  await page.screenshot({ path: 'screenshots/after_25s.png' });
  console.log('Captured screenshots/after_25s.png');
  await browser.close();
})();
