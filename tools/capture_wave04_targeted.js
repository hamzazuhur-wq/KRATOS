const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  async function capture(url, vp, filename, scroll = false) {
    console.log(`Capturing ${filename} (${vp.width}x${vp.height})...`);
    const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(5000);

    if (scroll) {
      // Drag upwards to scroll down in Flutter Web
      const startX = Math.floor(vp.width / 2);
      const startY = Math.floor(vp.height * 0.75);
      const endY = Math.floor(vp.height * 0.2);
      await page.mouse.move(startX, startY);
      await page.mouse.down();
      await page.mouse.move(startX, endY, { steps: 25 });
      await page.mouse.up();
      await page.waitForTimeout(1200);
    }

    await page.screenshot({ path: path.join(screenshotsDir, filename), fullPage: false });
    await context.close();
  }

  // Tablet captures
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=dark', { width: 1024, height: 768 }, 'wave04_dark_analytics_tablet_1024x768.png');
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=light', { width: 1024, height: 768 }, 'wave04_light_analytics_tablet_1024x768.png');
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=dark', { width: 768, height: 1024 }, 'wave04_dark_analytics_tablet_portrait_768x1024.png');
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=light', { width: 768, height: 1024 }, 'wave04_light_analytics_tablet_portrait_768x1024.png');

  // Scrolled mobile captures
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=dark', { width: 430, height: 932 }, 'wave04_dark_analytics_mobile_430x932_scrolled.png', true);
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=light', { width: 430, height: 932 }, 'wave04_light_analytics_mobile_430x932_scrolled.png', true);
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=dark', { width: 390, height: 844 }, 'wave04_dark_analytics_mobile_390x844_scrolled.png', true);
  await capture('http://127.0.0.1:3000/?preview=analytics&theme=light', { width: 390, height: 844 }, 'wave04_light_analytics_mobile_390x844_scrolled.png', true);

  await browser.close();
  console.log('✅ Targeted captures completed.');
})();
