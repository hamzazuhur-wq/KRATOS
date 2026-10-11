const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  console.log('=== KRATOS Insights Visual QA Started ===');

  const captures = [
    {
      name: 'insights_desktop_1440x900_dark',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=dark',
      width: 1440,
      height: 900,
    },
    {
      name: 'insights_desktop_1440x900_light',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=light',
      width: 1440,
      height: 900,
    },
    {
      name: 'insights_tablet_820x1180_dark',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=dark',
      width: 820,
      height: 1180,
    },
    {
      name: 'insights_tablet_820x1180_light',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=light',
      width: 820,
      height: 1180,
    },
    {
      name: 'insights_mobile_390x844_dark',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=dark',
      width: 390,
      height: 844,
    },
    {
      name: 'insights_mobile_390x844_light',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=light',
      width: 390,
      height: 844,
    },
    {
      name: 'insights_dashboard_context_dark',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=dark',
      width: 1440,
      height: 1800,
    },
    {
      name: 'insights_dashboard_context_light',
      url: 'http://127.0.0.1:3000/?preview=focus_time&theme=light',
      width: 1440,
      height: 1800,
    },
    {
      name: 'insights_empty_state_dark',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=dark&empty=true',
      width: 1440,
      height: 900,
    },
    {
      name: 'insights_empty_state_light',
      url: 'http://127.0.0.1:3000/?preview=insights&theme=light&empty=true',
      width: 1440,
      height: 900,
    },
  ];

  for (const item of captures) {
    console.log(`Capturing: ${item.name} (${item.width}x${item.height})...`);
    const page = await browser.newPage({ viewport: { width: item.width, height: item.height } });
    try {
      await page.goto(item.url, { waitUntil: 'load', timeout: 35000 });
      // Allow Flutter web canvaskit / wasm fonts and animations to settle
      await page.waitForTimeout(6000);

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
  console.log('=== KRATOS Insights Visual QA Completed ===');
})();
