const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });
  console.log('=== Starting Full Insights & View All Playwright QA ===');

  try {
    // -------------------------------------------------------------
    // TEST 1: View All Click & Navigation on Desktop Dark (1440x900)
    // -------------------------------------------------------------
    console.log('\n--- 1. Testing "View All" Click & Navigation (Desktop Dark) ---');
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await page.goto('http://127.0.0.1:3000/?preview=insights&theme=dark', { waitUntil: 'load' });
    await page.waitForTimeout(5000);

    // Capture initial preview
    await page.screenshot({ path: path.join(screenshotsDir, 'qa_view_all_1_preview_dark.png') });
    console.log('Saved: qa_view_all_1_preview_dark.png');

    // In 1440x900, the Insights card header has:
    // Left: Lightbulb + "Insights" + "Smart insights from your data."
    // Right: "View All →" button
    // Let's find "View All" button coordinates or click via semantics/mouse
    // Container width is max 1100, centered in 1440.
    // Left edge of card: (1440 - 1100)/2 = 170.
    // Card header top padding: ~24. AppBar: ~56.
    // "View All" is right-aligned inside card header: X ≈ 170 + 1100 - 60 = 1210, Y ≈ 56 + 24 + 40 = 120
    // Let's scan or click around X: 1200, Y: 120 or search for semantics element
    const viewAllElement = await page.$('flt-semantics[aria-label*="View All"]');
    if (viewAllElement) {
      console.log('Found semantic View All element! Clicking...');
      await viewAllElement.click();
    } else {
      console.log('Clicking "View All" by coordinates (X: 1205, Y: 120)...');
      await page.mouse.click(1205, 120);
    }
    await page.waitForTimeout(3000);

    // Capture the opened Full Insights Screen
    await page.screenshot({ path: path.join(screenshotsDir, 'qa_view_all_2_opened_full_screen.png') });
    console.log('Saved: qa_view_all_2_opened_full_screen.png');

    // Now test Back button: Top-left of InsightsScreen
    // Top bar is at Y: 12-50, Back button at X: 35, Y: 30
    console.log('Clicking Back button on InsightsScreen (X: 35, Y: 30)...');
    const backElement = await page.$('flt-semantics[aria-label*="Back"]');
    if (backElement) {
      await backElement.click();
    } else {
      await page.mouse.click(35, 30);
    }
    await page.waitForTimeout(2500);

    // Capture returned preview state
    await page.screenshot({ path: path.join(screenshotsDir, 'qa_view_all_3_returned_to_preview.png') });
    console.log('Saved: qa_view_all_3_returned_to_preview.png');
    await page.close();

    // -------------------------------------------------------------
    // TEST 2: Dedicated Full Insights Screen (Desktop Dark 1440x900)
    // -------------------------------------------------------------
    console.log('\n--- 2. Full Insights Screen (Desktop Dark) ---');
    const fullDarkPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await fullDarkPage.goto('http://127.0.0.1:3000/?preview=insights_full&theme=dark', { waitUntil: 'load' });
    await fullDarkPage.waitForTimeout(5000);
    await fullDarkPage.screenshot({ path: path.join(screenshotsDir, 'insights_full_desktop_dark.png') });
    console.log('Saved: insights_full_desktop_dark.png');
    await fullDarkPage.close();

    // -------------------------------------------------------------
    // TEST 3: Dedicated Full Insights Screen (Desktop Light 1440x900)
    // -------------------------------------------------------------
    console.log('\n--- 3. Full Insights Screen (Desktop Light) ---');
    const fullLightPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await fullLightPage.goto('http://127.0.0.1:3000/?preview=insights_full&theme=light', { waitUntil: 'load' });
    await fullLightPage.waitForTimeout(5000);
    await fullLightPage.screenshot({ path: path.join(screenshotsDir, 'insights_full_desktop_light.png') });
    console.log('Saved: insights_full_desktop_light.png');
    await fullLightPage.close();

    // -------------------------------------------------------------
    // TEST 4: Dedicated Full Insights Screen (Tablet 768x1024)
    // -------------------------------------------------------------
    console.log('\n--- 4. Full Insights Screen (Tablet 768x1024 Dark & Light) ---');
    const tabletDarkPage = await browser.newPage({ viewport: { width: 768, height: 1024 } });
    await tabletDarkPage.goto('http://127.0.0.1:3000/?preview=insights_full&theme=dark', { waitUntil: 'load' });
    await tabletDarkPage.waitForTimeout(5000);
    await tabletDarkPage.screenshot({ path: path.join(screenshotsDir, 'insights_full_tablet_dark.png') });
    console.log('Saved: insights_full_tablet_dark.png');
    await tabletDarkPage.close();

    const tabletLightPage = await browser.newPage({ viewport: { width: 768, height: 1024 } });
    await tabletLightPage.goto('http://127.0.0.1:3000/?preview=insights_full&theme=light', { waitUntil: 'load' });
    await tabletLightPage.waitForTimeout(5000);
    await tabletLightPage.screenshot({ path: path.join(screenshotsDir, 'insights_full_tablet_light.png') });
    console.log('Saved: insights_full_tablet_light.png');
    await tabletLightPage.close();

    // -------------------------------------------------------------
    // TEST 5: Dedicated Full Insights Screen (Mobile 390x844)
    // -------------------------------------------------------------
    console.log('\n--- 5. Full Insights Screen (Mobile 390x844 Dark & Light) ---');
    const mobileDarkPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
    await mobileDarkPage.goto('http://127.0.0.1:3000/?preview=insights_full&theme=dark', { waitUntil: 'load' });
    await mobileDarkPage.waitForTimeout(5000);
    await mobileDarkPage.screenshot({ path: path.join(screenshotsDir, 'insights_full_mobile_dark.png') });
    console.log('Saved: insights_full_mobile_dark.png');
    await mobileDarkPage.close();

    const mobileLightPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
    await mobileLightPage.goto('http://127.0.0.1:3000/?preview=insights_full&theme=light', { waitUntil: 'load' });
    await mobileLightPage.waitForTimeout(5000);
    await mobileLightPage.screenshot({ path: path.join(screenshotsDir, 'insights_full_mobile_light.png') });
    console.log('Saved: insights_full_mobile_light.png');
    await mobileLightPage.close();

    // -------------------------------------------------------------
    // TEST 6: Mobile "View All" Touch Interaction (Mobile 390x844)
    // -------------------------------------------------------------
    console.log('\n--- 6. Mobile "View All" Touch Interaction ---');
    const mobileTouchPage = await browser.newPage({ viewport: { width: 390, height: 844 } });
    await mobileTouchPage.goto('http://127.0.0.1:3000/?preview=insights&theme=dark', { waitUntil: 'load' });
    await mobileTouchPage.waitForTimeout(5000);

    // In 390 width, card width is 390 - 48 = 342.
    // Card starts at X ≈ 24.
    // "View All" button is at the top right of the card: X ≈ 390 - 24 - 40 = 326, Y ≈ 56 + 24 + 40 = 120
    console.log('Tapping Mobile "View All" (X: 325, Y: 120)...');
    await mobileTouchPage.mouse.click(325, 120);
    await mobileTouchPage.waitForTimeout(3000);
    await mobileTouchPage.screenshot({ path: path.join(screenshotsDir, 'qa_view_all_mobile_navigated.png') });
    console.log('Saved: qa_view_all_mobile_navigated.png');
    await mobileTouchPage.close();

  } catch (err) {
    console.error('Test execution error:', err);
  } finally {
    await browser.close();
    console.log('=== Playwright QA Finished ===');
  }
})();
