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
    await pageDark.goto('http://127.0.0.1:3000/?preview=wave13&theme=dark');
    await pageDark.waitForTimeout(4000);
    await pageDark.screenshot({ path: `screenshots/wave13_dark_storybook_${vp.name}.png`, fullPage: false });
    await pageDark.close();

    // Light Storybook
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=wave13&theme=light');
    await pageLight.waitForTimeout(4000);
    await pageLight.screenshot({ path: `screenshots/wave13_light_storybook_${vp.name}.png`, fullPage: false });
    await pageLight.close();

    // Dark Real Profile Screen
    const pageProfDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageProfDark.goto('http://127.0.0.1:3000/?preview=profile&theme=dark');
    await pageProfDark.waitForTimeout(4000);
    await pageProfDark.screenshot({ path: `screenshots/wave13_dark_profile_screen_${vp.name}.png`, fullPage: false });
    await pageProfDark.close();

    // Light Real Profile Screen
    const pageProfLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageProfLight.goto('http://127.0.0.1:3000/?preview=profile&theme=light');
    await pageProfLight.waitForTimeout(4000);
    await pageProfLight.screenshot({ path: `screenshots/wave13_light_profile_screen_${vp.name}.png`, fullPage: false });
    await pageProfLight.close();
  }

  // Dialogs
  const pageEditDark = await browser.newPage({ viewport: { width: 1200, height: 800 } });
  await pageEditDark.goto('http://127.0.0.1:3000/?preview=profile&theme=dark&dialog=edit');
  await pageEditDark.waitForTimeout(4000);
  await pageEditDark.screenshot({ path: `screenshots/wave13_dark_dialog_edit.png`, fullPage: false });
  await pageEditDark.close();

  const pageEditLight = await browser.newPage({ viewport: { width: 1200, height: 800 } });
  await pageEditLight.goto('http://127.0.0.1:3000/?preview=profile&theme=light&dialog=edit');
  await pageEditLight.waitForTimeout(4000);
  await pageEditLight.screenshot({ path: `screenshots/wave13_light_dialog_edit.png`, fullPage: false });
  await pageEditLight.close();

  const pageSignoutDark = await browser.newPage({ viewport: { width: 1200, height: 800 } });
  await pageSignoutDark.goto('http://127.0.0.1:3000/?preview=profile&theme=dark&dialog=signout');
  await pageSignoutDark.waitForTimeout(4000);
  await pageSignoutDark.screenshot({ path: `screenshots/wave13_dark_dialog_signout.png`, fullPage: false });
  await pageSignoutDark.close();

  await browser.close();
  console.log('QA Screenshots captured successfully.');
})();
