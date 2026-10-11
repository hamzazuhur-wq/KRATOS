const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });

  console.log('Testing Mobile Bottom Navigation with Y=890...');
  const mobilePage = await browser.newPage({ viewport: { width: 430, height: 932 } });
  await mobilePage.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  await mobilePage.waitForTimeout(5000);

  // Click Tasks (item 1: X ≈ 120, Y = 890)
  console.log('Mobile: Clicking Tasks (120, 890)...');
  await mobilePage.mouse.click(120, 890);
  await mobilePage.waitForTimeout(3000);
  await mobilePage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_mobile_tasks_screen.png') });

  // Click Goals (item 2: X ≈ 190, Y = 890)
  console.log('Mobile: Clicking Goals (190, 890)...');
  await mobilePage.mouse.click(190, 890);
  await mobilePage.waitForTimeout(3000);
  await mobilePage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_mobile_goals_screen.png') });

  // Click Back to Home (item 0: X ≈ 60, Y = 890)
  console.log('Mobile: Clicking Home (60, 890)...');
  await mobilePage.mouse.click(60, 890);
  await mobilePage.waitForTimeout(3000);
  await mobilePage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_mobile_back_home_screen.png') });

  await browser.close();
  console.log('Mobile navigation test complete.');
})();
