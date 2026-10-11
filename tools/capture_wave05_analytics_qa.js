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
    { name: 'desktop_1440x900', width: 1440, height: 900, scrollDist: 680 },
    { name: 'desktop_1280x800', width: 1280, height: 800, scrollDist: 680 },
    { name: 'tablet_1024x768', width: 1024, height: 768, scrollDist: 720 },
    { name: 'tablet_portrait_768x1024', width: 768, height: 1024, scrollDist: 700 },
    { name: 'mobile_430x932', width: 430, height: 932, scrollDist: 920 },
    { name: 'mobile_390x844', width: 390, height: 844, scrollDist: 920 },
  ];

  for (const vp of viewports) {
    // 1. Dark Mode
    console.log(`Capturing Dark Mode: ${vp.name}...`);
    const pageDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageDark.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark', { waitUntil: 'load' });
    await pageDark.waitForTimeout(4500);

    // Initial overview
    await pageDark.screenshot({
      path: path.join(screenshotsDir, `wave05_dark_analytics_${vp.name}_overview.png`),
      fullPage: false,
    });

    // Move mouse over main content and wheel scroll to XP Distribution
    await pageDark.mouse.move(Math.floor(vp.width * 0.6), Math.floor(vp.height * 0.5));
    await pageDark.mouse.wheel(0, vp.scrollDist);
    await pageDark.waitForTimeout(1000);

    await pageDark.screenshot({
      path: path.join(screenshotsDir, `wave05_dark_analytics_${vp.name}_xp_distribution.png`),
      fullPage: false,
    });
    await pageDark.close();

    // 2. Light Mode
    console.log(`Capturing Light Mode: ${vp.name}...`);
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light', { waitUntil: 'load' });
    await pageLight.waitForTimeout(4500);

    // Move mouse over main content and wheel scroll to XP Distribution
    await pageLight.mouse.move(Math.floor(vp.width * 0.6), Math.floor(vp.height * 0.5));
    await pageLight.mouse.wheel(0, vp.scrollDist);
    await pageLight.waitForTimeout(1000);

    await pageLight.screenshot({
      path: path.join(screenshotsDir, `wave05_light_analytics_${vp.name}_xp_distribution.png`),
      fullPage: false,
    });
    await pageLight.close();
  }

  // 3. Interactive Hover & Hit Testing QA (Desktop 1440x900 Dark Mode)
  console.log('Capturing Interactive Hover QA...');
  const pageHover = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageHover.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark', { waitUntil: 'load' });
  await pageHover.waitForTimeout(4500);
  await pageHover.mouse.move(700, 450);
  await pageHover.mouse.wheel(0, 540);
  await pageHover.waitForTimeout(1000);

  // Hover over the donut right segment (Tasks segment)
  await pageHover.mouse.move(485, 450);
  await pageHover.waitForTimeout(600);
  await pageHover.screenshot({
    path: path.join(screenshotsDir, 'wave05_dark_analytics_desktop_donut_hover.png'),
    fullPage: false,
  });

  // Hover over the second source row in the ranked list (Projects)
  await pageHover.mouse.move(660, 440);
  await pageHover.waitForTimeout(600);
  await pageHover.screenshot({
    path: path.join(screenshotsDir, 'wave05_dark_analytics_desktop_row_hover.png'),
    fullPage: false,
  });
  await pageHover.close();

  // 4. Dedicated Storybook QA across diverse presets
  console.log('Capturing Storybook Presets...');
  const sbPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  // Populated Dark & Light
  await sbPage.goto('http://127.0.0.1:3000/?preview=wave05&theme=dark', { waitUntil: 'load' });
  await sbPage.waitForTimeout(4000);
  await sbPage.screenshot({ path: path.join(screenshotsDir, 'wave05_storybook_dark_populated.png') });

  await sbPage.goto('http://127.0.0.1:3000/?preview=wave05&theme=light', { waitUntil: 'load' });
  await sbPage.waitForTimeout(4000);
  await sbPage.screenshot({ path: path.join(screenshotsDir, 'wave05_storybook_light_populated.png') });

  await sbPage.close();

  await browser.close();
  console.log('✅ All Wave 05 Visual QA screenshots captured successfully.');
})();
