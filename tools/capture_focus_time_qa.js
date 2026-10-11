const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  console.log('=== Focus Time Visual QA Started ===');

  const captures = [
    {
      name: 'focus_time_desktop_1440x900_dark',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=dark',
      width: 1440,
      height: 900,
    },
    {
      name: 'focus_time_desktop_1440x900_light',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=light',
      width: 1440,
      height: 900,
    },
    {
      name: 'focus_time_desktop_1440x1600_dark_full',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=dark',
      width: 1440,
      height: 1600,
    },
    {
      name: 'focus_time_desktop_1440x1600_light_full',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=light',
      width: 1440,
      height: 1600,
    },
    {
      name: 'focus_time_tablet_1024x768_dark',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=dark',
      width: 1024,
      height: 768,
    },
    {
      name: 'focus_time_tablet_768x1024_light',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=light',
      width: 768,
      height: 1024,
    },
    {
      name: 'focus_time_mobile_390x844_dark',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=dark',
      width: 390,
      height: 844,
    },
    {
      name: 'focus_time_mobile_390x844_light',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=light',
      width: 390,
      height: 844,
    },
    {
      name: 'focus_time_mobile_390x2100_dark_full',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=dark',
      width: 390,
      height: 2100,
    },
    {
      name: 'focus_time_mobile_390x2100_light_full',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=light',
      width: 390,
      height: 2100,
    },
  ];

  for (const item of captures) {
    console.log(`Capturing: ${item.name} (${item.width}x${item.height})...`);
    const page = await browser.newPage({ viewport: { width: item.width, height: item.height } });
    try {
      await page.goto(item.url, { waitUntil: 'load', timeout: 30000 });
      // Allow Flutter web canvaskit / wasm fonts and animations to settle
      await page.waitForTimeout(5000);

      const filePath = path.join(screenshotsDir, `${item.name}.png`);
      await page.screenshot({ path: filePath, fullPage: true });
      console.log(`Saved screenshot: ${filePath}`);
    } catch (err) {
      console.error(`Error capturing ${item.name}:`, err);
    } finally {
      await page.close();
    }
  }

  await browser.close();
  console.log('=== Focus Time Visual QA Completed ===');
})();
