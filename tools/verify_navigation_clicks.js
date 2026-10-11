const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });

  // 1. Mobile bottom bar navigation test (430x932)
  console.log('Testing Mobile Bottom Navigation...');
  const mobilePage = await browser.newPage({ viewport: { width: 430, height: 932 } });
  await mobilePage.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  await mobilePage.waitForTimeout(5000);

  // Bottom nav is at Y ≈ 950 (or height is 932, so bottom bar center is around Y=900)
  // Let's click "Tasks" (2nd item, X ≈ 140, Y ≈ 950 in physical or Y ≈ 950/932)
  // Total width is 430:
  // Item 0: Home (X=70, Y=950)
  // Item 1: Tasks (X=140, Y=950)
  // Item 2: Goals (X=215, Y=950)
  // Item 3: Activities (X=290, Y=950)
  // Item 5: Stats (X=410, Y=950)
  console.log('Mobile: Clicking Tasks (140, 950)...');
  await mobilePage.mouse.click(140, 950);
  await mobilePage.waitForTimeout(3000);
  await mobilePage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_mobile_click_tasks.png') });

  // Click Goals
  console.log('Mobile: Clicking Goals (215, 950)...');
  await mobilePage.mouse.click(215, 950);
  await mobilePage.waitForTimeout(3000);
  await mobilePage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_mobile_click_goals.png') });

  // 2. Desktop sidebar navigation test (1440x900)
  console.log('Testing Desktop Sidebar Navigation...');
  const desktopPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await desktopPage.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load' });
  await desktopPage.waitForTimeout(5000);

  // Let's measure sidebar tile positions on 1440x900:
  // In 1440x900:
  // Top header: height 64.
  // Sidebar user header: Y from 0 to 125.
  // ListView starts at Y=125 with padding vertical 8.
  // Tile height is ~44.
  // Home: Y ≈ 133 + 22 = 155
  // Due Today: Y ≈ 155 + 44 = 199
  // Tasks: Y ≈ 199 + 44 = 243
  // Goals: Y ≈ 243 + 44 = 287
  // Activities: Y ≈ 287 + 44 = 331
  // Idea Capture: Y ≈ 331 + 44 = 375
  // Stats: Y ≈ 375 + 44 = 419
  console.log('Desktop: Clicking Tasks (X=80, Y=255)...');
  await desktopPage.mouse.click(80, 255);
  await desktopPage.waitForTimeout(3000);
  await desktopPage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_desktop_click_tasks.png') });

  console.log('Desktop: Clicking Goals (X=80, Y=305)...');
  await desktopPage.mouse.click(80, 305);
  await desktopPage.waitForTimeout(3000);
  await desktopPage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_desktop_click_goals.png') });

  console.log('Desktop: Clicking Stats (X=80, Y=455)...');
  await desktopPage.mouse.click(80, 455);
  await desktopPage.waitForTimeout(3000);
  await desktopPage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_desktop_click_stats.png') });

  console.log('Desktop: Clicking Home (X=80, Y=160)...');
  await desktopPage.mouse.click(80, 160);
  await desktopPage.waitForTimeout(3000);
  await desktopPage.screenshot({ path: path.join(__dirname, '..', 'screenshots', 'nav_desktop_click_home.png') });

  await browser.close();
  console.log('Done.');
})();
