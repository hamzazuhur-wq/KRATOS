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
    { name: 'desktop_1440x900', width: 1440, height: 900, scrollDist: 1100 },
    { name: 'desktop_1280x800', width: 1280, height: 800, scrollDist: 1100 },
    { name: 'tablet_1024x768', width: 1024, height: 768, scrollDist: 1200 },
    { name: 'tablet_portrait_768x1024', width: 768, height: 1024, scrollDist: 1100 },
    { name: 'mobile_430x932', width: 430, height: 932, scrollDist: 1500 },
    { name: 'mobile_390x844', width: 390, height: 844, scrollDist: 1500 },
  ];

  console.log('=== Wave 06: XP Progress Visual QA Started ===');

  // 1. Integrated Analytics Screen QA across Viewports & Themes
  for (const vp of viewports) {
    // 1a. Dark Mode
    console.log(`Capturing Dark Mode: ${vp.name}...`);
    const pageDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageDark.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark', { waitUntil: 'load' });
    await pageDark.waitForTimeout(4500);

    // Scroll to XP Progress
    await pageDark.mouse.move(Math.floor(vp.width * 0.5), Math.floor(vp.height * 0.5));
    await pageDark.mouse.wheel(0, vp.scrollDist);
    await pageDark.waitForTimeout(1200);

    await pageDark.screenshot({
      path: path.join(screenshotsDir, `wave06_dark_analytics_${vp.name}_xp_progress.png`),
      fullPage: false,
    });
    await pageDark.close();

    // 1b. Light Mode
    console.log(`Capturing Light Mode: ${vp.name}...`);
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light', { waitUntil: 'load' });
    await pageLight.waitForTimeout(4500);

    // Scroll to XP Progress
    await pageLight.mouse.move(Math.floor(vp.width * 0.5), Math.floor(vp.height * 0.5));
    await pageLight.mouse.wheel(0, vp.scrollDist);
    await pageLight.waitForTimeout(1200);

    await pageLight.screenshot({
      path: path.join(screenshotsDir, `wave06_light_analytics_${vp.name}_xp_progress.png`),
      fullPage: false,
    });
    await pageLight.close();
  }

  // 2. Dedicated Storybook QA across diverse presets
  console.log('Capturing Storybook Presets...');
  const sbPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  // Storybook - Default (Level IV Crystal) Dark
  await sbPage.goto('http://127.0.0.1:3000/?preview=wave06&theme=dark', { waitUntil: 'load' });
  await sbPage.waitForTimeout(4000);
  await sbPage.screenshot({ path: path.join(screenshotsDir, 'wave06_storybook_dark_level4_crystal.png') });

  // Storybook - Default (Level IV Crystal) Light
  await sbPage.goto('http://127.0.0.1:3000/?preview=wave06&theme=light', { waitUntil: 'load' });
  await sbPage.waitForTimeout(4000);
  await sbPage.screenshot({ path: path.join(screenshotsDir, 'wave06_storybook_light_level4_crystal.png') });

  // Storybook - Mobile Viewport (390x844) Dark
  const sbMobile = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await sbMobile.goto('http://127.0.0.1:3000/?preview=wave06&theme=dark', { waitUntil: 'load' });
  await sbMobile.waitForTimeout(4000);
  await sbMobile.screenshot({ path: path.join(screenshotsDir, 'wave06_storybook_mobile_dark.png') });
  await sbMobile.close();

  // Storybook - Tablet Viewport (1024x768) Dark
  const sbTablet = await browser.newPage({ viewport: { width: 1024, height: 768 } });
  await sbTablet.goto('http://127.0.0.1:3000/?preview=wave06&theme=dark', { waitUntil: 'load' });
  await sbTablet.waitForTimeout(4000);
  await sbTablet.screenshot({ path: path.join(screenshotsDir, 'wave06_storybook_tablet_dark.png') });
  await sbTablet.close();

  await sbPage.close();
  await browser.close();

  console.log('=== Wave 06: XP Progress Visual QA Completed Successfully ===');
})();
