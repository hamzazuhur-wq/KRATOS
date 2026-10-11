const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  console.log('=== Wave 07: Life Areas Radar & Overview Visual QA Started ===');

  // 1. Storybook Screen QA across viewports, themes, and states
  const storybookStates = [
    {
      name: 'wave07_storybook_desktop_1440x900_dark_baseline',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=dark',
      width: 1440,
      height: 900,
    },
    {
      name: 'wave07_storybook_desktop_1440x900_light_baseline',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=light',
      width: 1440,
      height: 900,
    },
    {
      name: 'wave07_storybook_tablet_1024x768_dark',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=dark',
      width: 1024,
      height: 768,
    },
    {
      name: 'wave07_storybook_mobile_430x932_dark',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=dark',
      width: 430,
      height: 932,
    },
    {
      name: 'wave07_storybook_mobile_390x844_dark',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=dark',
      width: 390,
      height: 844,
    },
  ];

  for (const item of storybookStates) {
    console.log(`Capturing Storybook: ${item.name}...`);
    const page = await browser.newPage({ viewport: { width: item.width, height: item.height } });
    await page.goto(item.url, { waitUntil: 'load' });
    await page.waitForTimeout(4000);

    await page.screenshot({
      path: path.join(screenshotsDir, `${item.name}.png`),
      fullPage: false,
    });
    await page.close();
  }

  // 2. Storybook Interactive States (Day 2 Values Transition, Selected Area, Large Count)
  console.log('Capturing Storybook Interactive States...');
  const interactiveStates = [
    {
      name: 'wave07_storybook_dark_day2_animated',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=dark&preset=day2',
    },
    {
      name: 'wave07_storybook_dark_selected_knowledge',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=dark&preset=selected',
    },
    {
      name: 'wave07_storybook_dark_large_count_9areas',
      url: 'http://127.0.0.1:3000/?preview=wave07&theme=dark&preset=large',
    },
  ];

  for (const st of interactiveStates) {
    console.log(`Capturing Interactive Storybook: ${st.name}...`);
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await page.goto(st.url, { waitUntil: 'load' });
    await page.waitForTimeout(4000);
    await page.screenshot({
      path: path.join(screenshotsDir, `${st.name}.png`),
      fullPage: false,
    });
    await page.close();
  }

  // 3. Integrated Analytics Screen QA (Showing Life Areas Overview in Context)
  const integratedViewports = [
    { name: 'desktop_1440x900', width: 1440, height: 900, scrollDist: 1050 },
    { name: 'desktop_1280x800', width: 1280, height: 800, scrollDist: 1050 },
    { name: 'tablet_1024x768', width: 1024, height: 768, scrollDist: 1150 },
    { name: 'mobile_430x932', width: 430, height: 932, scrollDist: 1400 },
    { name: 'mobile_390x844', width: 390, height: 844, scrollDist: 1400 },
  ];

  for (const vp of integratedViewports) {
    // 3a. Dark Mode Integrated
    console.log(`Capturing Integrated Analytics Dark: ${vp.name}...`);
    const pageDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageDark.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark', { waitUntil: 'load' });
    await pageDark.waitForTimeout(4500);

    await pageDark.mouse.move(Math.floor(vp.width * 0.5), Math.floor(vp.height * 0.5));
    await pageDark.mouse.wheel(0, vp.scrollDist);
    await pageDark.waitForTimeout(1200);

    await pageDark.screenshot({
      path: path.join(screenshotsDir, `wave07_dark_analytics_${vp.name}_life_areas_overview.png`),
      fullPage: false,
    });
    await pageDark.close();

    // 3b. Light Mode Integrated
    console.log(`Capturing Integrated Analytics Light: ${vp.name}...`);
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light', { waitUntil: 'load' });
    await pageLight.waitForTimeout(4500);

    await pageLight.mouse.move(Math.floor(vp.width * 0.5), Math.floor(vp.height * 0.5));
    await pageLight.mouse.wheel(0, vp.scrollDist);
    await pageLight.waitForTimeout(1200);

    await pageLight.screenshot({
      path: path.join(screenshotsDir, `wave07_light_analytics_${vp.name}_life_areas_overview.png`),
      fullPage: false,
    });
    await pageLight.close();
  }

  await browser.close();
  console.log('=== Wave 07: Visual QA Completed Successfully ===');
})();
