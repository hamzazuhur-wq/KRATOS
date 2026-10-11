const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  // ── 1. Multi-viewport Base Captures ──────────────────────────────────────────
  const viewports = [
    { name: 'desktop_1440x900', width: 1440, height: 900 },
    { name: 'tablet_1024x768', width: 1024, height: 768 },
    { name: 'mobile_390x844', width: 390, height: 844 },
  ];

  for (const vp of viewports) {
    // Dark mode base
    console.log(`Capturing Dark Mode: ${vp.name}...`);
    const pageDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageDark.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
    await pageDark.waitForTimeout(4500);
    await pageDark.screenshot({ path: `screenshots/wave03_fix_dark_${vp.name}.png` });
    await pageDark.close();

    // Light mode base
    console.log(`Capturing Light Mode: ${vp.name}...`);
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
    await pageLight.waitForTimeout(4500);
    await pageLight.screenshot({ path: `screenshots/wave03_fix_light_${vp.name}.png` });
    await pageLight.close();
  }

  // ── 2. Consistency Card Floating Detail Interaction (Dark Mode) ──────────────
  console.log('Testing Consistency card click (Dark mode)...');
  const desktopPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await desktopPage.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await desktopPage.waitForTimeout(4500);

  // Click on the Consistency card (4th card on desktop, x: 1270, y: 300)
  await desktopPage.mouse.click(1270, 300);
  await desktopPage.waitForTimeout(1500);
  await desktopPage.screenshot({ path: 'screenshots/wave03_fix_consistency_detail_dark.png' });

  // Click translucent backdrop at x = 100, y = 100 to close modal
  await desktopPage.mouse.click(100, 100);
  await desktopPage.waitForTimeout(1000);
  await desktopPage.screenshot({ path: 'screenshots/wave03_fix_consistency_modal_closed.png' });
  await desktopPage.close();

  // ── 3. Consistency Card Floating Detail Interaction (Light Mode) ─────────────
  console.log('Testing Consistency card click (Light mode)...');
  const lightModalPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await lightModalPage.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
  await lightModalPage.waitForTimeout(4500);

  // Click Consistency card (x: 1270, y: 300)
  await lightModalPage.mouse.click(1270, 300);
  await lightModalPage.waitForTimeout(1500);
  await lightModalPage.screenshot({ path: 'screenshots/wave03_fix_consistency_detail_light.png' });
  await lightModalPage.close();

  // ── 4. Filter Interaction: Date Range Change ────────────────────────────────
  console.log('Testing Date Range filter change...');
  const filterPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await filterPage.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await filterPage.waitForTimeout(4500);

  // Click Date Range pill (x: 260, y: 200)
  await filterPage.mouse.click(260, 200);
  await filterPage.waitForTimeout(800);
  // Click first option "Last 7 Days" in dropdown popup (appears right below or near x: 260, y: 250)
  await filterPage.mouse.click(260, 250);
  await filterPage.waitForTimeout(1500);
  await filterPage.screenshot({ path: 'screenshots/wave03_fix_date_range_7d.png' });
  await filterPage.close();

  await browser.close();
  console.log('✅ All Wave 03-FIX QA screenshots captured successfully.');
})();
