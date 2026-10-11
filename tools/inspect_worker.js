const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  page.on('worker', worker => {
    console.log('Worker created:', worker.url());
    worker.on('console', msg => console.log('[WORKER CONSOLE]', msg.text()));
    worker.on('error', err => console.error('[WORKER ERROR]', err));
  });

  page.on('console', msg => {
    console.log(`[PAGE CONSOLE ${msg.type()}]`, msg.text());
  });
  page.on('pageerror', err => {
    console.error('[PAGE ERROR]', err.message);
  });

  console.log('Navigating...');
  await page.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark');
  await page.waitForTimeout(6000);

  // Check what workers exist and evaluate worker status in page
  const res = await page.evaluate(async () => {
    return {
      hasOpfs: !!(navigator.storage && navigator.storage.getDirectory),
      hasLocks: !!(navigator.locks),
      hasWorker: !!window.Worker,
      hasSharedWorker: !!window.SharedWorker,
    };
  });
  console.log('Browser capabilities:', res);

  await page.waitForTimeout(8000);
  await browser.close();
})();
