const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const viewports = [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'medium', width: 1024, height: 768 },
    { name: 'mobile', width: 390, height: 844 }
  ];

  for (const vp of viewports) {
    // Dark Storybook
    const pageDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageDark.goto('http://127.0.0.1:3000/?preview=wave10&theme=dark');
    await pageDark.waitForTimeout(4000);
    await pageDark.screenshot({ path: `screenshots/wave10_dark_storybook_${vp.name}.png`, fullPage: false });
    await pageDark.close();

    // Light Storybook
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=wave10&theme=light');
    await pageLight.waitForTimeout(4000);
    await pageLight.screenshot({ path: `screenshots/wave10_light_storybook_${vp.name}.png`, fullPage: false });
    await pageLight.close();
  }

  await browser.close();
})();
