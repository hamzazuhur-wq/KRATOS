const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });
  const viewports = [
    { name: 'desktop_1440x900', width: 1440, height: 900 },
    { name: 'desktop_1280x800', width: 1280, height: 800 },
    { name: 'tablet_1024x768', width: 1024, height: 768 },
    { name: 'tablet_portrait_768x1024', width: 768, height: 1024 },
    { name: 'mobile_430x932', width: 430, height: 932 },
    { name: 'mobile_390x844', width: 390, height: 844 },
  ];

  for (const vp of viewports) {
    // Dark mode
    console.log(`Capturing Dark Mode: ${vp.name} (${vp.width}x${vp.height})...`);
    const pageDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageDark.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
    await pageDark.waitForTimeout(4000);
    await pageDark.screenshot({ path: `screenshots/wave02_dark_analytics_${vp.name}.png`, fullPage: false });
    await pageDark.close();

    // Light mode
    console.log(`Capturing Light Mode: ${vp.name} (${vp.width}x${vp.height})...`);
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
    await pageLight.waitForTimeout(4000);
    await pageLight.screenshot({ path: `screenshots/wave02_light_analytics_${vp.name}.png`, fullPage: false });
    await pageLight.close();
  }

  await browser.close();
  console.log('✅ All Wave 02 Analytics Visual QA screenshots captured successfully.');
})();
