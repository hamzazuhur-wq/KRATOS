const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const dir = path.join(__dirname, '..', 'screenshots');

  // 1. Desktop 1440x900 Dark Mode Final
  const pageDark = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageDark.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await pageDark.waitForTimeout(4500);
  await pageDark.screenshot({ path: path.join(dir, 'wave04_final_dark_desktop_1440x900.png') });
  await pageDark.close();

  // 2. Desktop 1440x900 Light Mode Final
  const pageLight = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
  await pageLight.waitForTimeout(4500);
  await pageLight.screenshot({ path: path.join(dir, 'wave04_final_light_desktop_1440x900.png') });
  await pageLight.close();

  // 3. Mobile 390x844 Light Mode Final Scrolled
  const page390Light = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await page390Light.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
  await page390Light.waitForTimeout(4500);
  await page390Light.mouse.move(195, 450);
  await page390Light.mouse.wheel(0, 800);
  await page390Light.waitForTimeout(1000);
  await page390Light.screenshot({ path: path.join(dir, 'wave04_final_light_mobile_390x844_scrolled.png') });
  await page390Light.close();

  // 4. Mobile 430x932 Light Mode Final Scrolled
  const page430Light = await browser.newPage({ viewport: { width: 430, height: 932 } });
  await page430Light.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
  await page430Light.waitForTimeout(4500);
  await page430Light.mouse.move(215, 450);
  await page430Light.mouse.wheel(0, 800);
  await page430Light.waitForTimeout(1000);
  await page430Light.screenshot({ path: path.join(dir, 'wave04_final_light_mobile_430x932_scrolled.png') });
  await page430Light.close();

  // 5. Scrolled Desktop 1440x900 Dark Mode to verify area below XP Trend is completely clean
  const pageDarkScroll = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageDarkScroll.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await pageDarkScroll.waitForTimeout(4500);
  await pageDarkScroll.mouse.move(720, 500);
  await pageDarkScroll.mouse.wheel(0, 450);
  await pageDarkScroll.waitForTimeout(1000);
  await pageDarkScroll.screenshot({ path: path.join(dir, 'wave04_final_dark_desktop_scrolled_below.png') });
  await pageDarkScroll.close();

  await browser.close();
  console.log('Final verification captures completed.');
})();
