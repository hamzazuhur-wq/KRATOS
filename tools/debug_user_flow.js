const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();

  console.log('Navigating to http://127.0.0.1:3000...');
  await page.goto('http://127.0.0.1:3000', { waitUntil: 'load' });
  await page.waitForTimeout(4000);
  await page.screenshot({ path: 'screenshots/user_step1_open.png' });

  // In Flutter Canvas, DOM text elements are in flt-semantics or canvas.
  // Click on the Sign In button coordinate on 1440x900 (center of screen is ~720, 585)
  // Let's check where Sign In button was in debug_root_url.png:
  // Card is centered: center X=720. Sign In yellow button is around Y=588.
  console.log('Clicking Sign In button...');
  await page.mouse.click(720, 588);
  await page.waitForTimeout(4000);
  await page.screenshot({ path: 'screenshots/user_step2_after_signin.png' });

  // Sidebar "Stats" is around X=100, Y=458
  console.log('Clicking Stats in sidebar...');
  await page.mouse.click(100, 458);
  await page.waitForTimeout(4000);
  await page.screenshot({ path: 'screenshots/user_step3_stats_initial.png' });

  // Scroll down to see if XP Distribution is visible
  console.log('Scrolling down on Stats...');
  await page.mouse.move(700, 450);
  await page.mouse.wheel(0, 600);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: 'screenshots/user_step4_stats_scrolled.png' });

  await browser.close();
  console.log('Debug flow finished.');
})();
