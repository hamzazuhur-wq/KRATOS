const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const configs = [
    { name: 'wave04_verify_source_all.png', url: 'http://127.0.0.1:3000/?preview=analytics&theme=dark' },
    { name: 'wave04_verify_source_task.png', url: 'http://127.0.0.1:3000/?preview=analytics&theme=dark&source=task' },
    { name: 'wave04_verify_source_goal.png', url: 'http://127.0.0.1:3000/?preview=analytics&theme=dark&source=goal' },
  ];

  for (const c of configs) {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await page.goto(c.url);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: path.join('screenshots', c.name) });
    await page.close();
    console.log('Saved', c.name);
  }

  await browser.close();
  console.log('Source filter captures finished.');
})();
