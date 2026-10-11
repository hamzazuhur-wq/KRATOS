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
    await pageDark.waitForTimeout(4500);
    await pageDark.screenshot({ path: `screenshots/wave04_dark_analytics_${vp.name}.png`, fullPage: false });
    await pageDark.close();

    // Light mode
    console.log(`Capturing Light Mode: ${vp.name} (${vp.width}x${vp.height})...`);
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
    await pageLight.waitForTimeout(4500);
    await pageLight.screenshot({ path: `screenshots/wave04_light_analytics_${vp.name}.png`, fullPage: false });
    // If mobile, also capture scrolled view focused on XP Trend Card
    if (vp.name.startsWith('mobile_')) {
      console.log(`Capturing Scrolled Dark Mode: ${vp.name}...`);
      const pageDarkScroll = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
      await pageDarkScroll.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
      await pageDarkScroll.waitForTimeout(4500);
      await pageDarkScroll.mouse.wheel(0, 380);
      await pageDarkScroll.waitForTimeout(600);
      await pageDarkScroll.screenshot({ path: `screenshots/wave04_dark_analytics_${vp.name}_scrolled.png`, fullPage: false });
      await pageDarkScroll.close();

      console.log(`Capturing Scrolled Light Mode: ${vp.name}...`);
      const pageLightScroll = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
      await pageLightScroll.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
      await pageLightScroll.waitForTimeout(4500);
      await pageLightScroll.mouse.wheel(0, 380);
      await pageLightScroll.waitForTimeout(600);
      await pageLightScroll.screenshot({ path: `screenshots/wave04_light_analytics_${vp.name}_scrolled.png`, fullPage: false });
      await pageLightScroll.close();
    }
  }

  // Interactive Hover QA (Desktop 1440x900 Dark Mode)
  console.log('Capturing Interactive Tooltip Hover QA...');
  const pageHover = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageHover.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await pageHover.waitForTimeout(4500);

  // Hover over the center-right of the XP Trend chart
  // XP Trend is located directly below the KPI row (y ~ 520, x ~ 900)
  await pageHover.mouse.move(900, 520);
  await pageHover.waitForTimeout(800);
  await pageHover.screenshot({ path: 'screenshots/wave04_dark_analytics_desktop_tooltip_hover.png', fullPage: false });
  await pageHover.close();

  await browser.close();
  console.log('✅ All Wave 04 Analytics XP Trend Visual QA screenshots captured successfully.');
})();
