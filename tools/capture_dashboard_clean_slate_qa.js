const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  console.log('=== KRATOS Dashboard Clean Slate Visual QA Started ===');

  const viewports = [
    { name: '1440x900', width: 1440, height: 900 },
    { name: '1024x768', width: 1024, height: 768 },
    { name: '430x932', width: 430, height: 932 },
  ];

  for (const vp of viewports) {
    // 1. Dark Theme
    console.log(`Capturing Dark Mode: ${vp.name}...`);
    const pageDark = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageDark.goto(`http://127.0.0.1:3000/?preview=dashboard&theme=dark`, { waitUntil: 'load', timeout: 30000 });
    await pageDark.waitForTimeout(5000);
    const darkPath = path.join(screenshotsDir, `dashboard_clean_slate_dark_${vp.name}.png`);
    await pageDark.screenshot({ path: darkPath, fullPage: false });
    console.log(`Saved: ${darkPath}`);
    await pageDark.close();

    // 2. Light Theme
    console.log(`Capturing Light Mode: ${vp.name}...`);
    const pageLight = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    await pageLight.goto(`http://127.0.0.1:3000/?preview=dashboard&theme=light`, { waitUntil: 'load', timeout: 30000 });
    await pageLight.waitForTimeout(5000);
    const lightPath = path.join(screenshotsDir, `dashboard_clean_slate_light_${vp.name}.png`);
    await pageLight.screenshot({ path: lightPath, fullPage: false });
    console.log(`Saved: ${lightPath}`);
    await pageLight.close();
  }

  // 3. Navigation test from Dashboard to Tasks and Goals
  console.log('Testing and capturing navigation from Dashboard to Tasks...');
  const navPage = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await navPage.goto('http://127.0.0.1:3000/?preview=dashboard&theme=dark', { waitUntil: 'load', timeout: 30000 });
  await navPage.waitForTimeout(5000);

  // Click Tasks tab in sidebar / nav
  console.log('Clicking Tasks in navigation...');
  const tasksBtn = await navPage.locator('text=Tasks').first();
  if (await tasksBtn.count() > 0) {
    await tasksBtn.click();
    await navPage.waitForTimeout(3000);
    const navTasksPath = path.join(screenshotsDir, 'dashboard_clean_slate_navigation_tasks.png');
    await navPage.screenshot({ path: navTasksPath, fullPage: false });
    console.log(`Saved navigation tasks screenshot: ${navTasksPath}`);
  }

  // Click Goals tab in sidebar / nav
  console.log('Clicking Goals in navigation...');
  const goalsBtn = await navPage.locator('text=Goals').first();
  if (await goalsBtn.count() > 0) {
    await goalsBtn.click();
    await navPage.waitForTimeout(3000);
    const navGoalsPath = path.join(screenshotsDir, 'dashboard_clean_slate_navigation_goals.png');
    await navPage.screenshot({ path: navGoalsPath, fullPage: false });
    console.log(`Saved navigation goals screenshot: ${navGoalsPath}`);
  }

  // Click back to Home / Dashboard
  console.log('Clicking Home in navigation...');
  const homeBtn = await navPage.locator('text=Home').first();
  if (await homeBtn.count() > 0) {
    await homeBtn.click();
    await navPage.waitForTimeout(3000);
    const navHomePath = path.join(screenshotsDir, 'dashboard_clean_slate_navigation_back_home.png');
    await navPage.screenshot({ path: navHomePath, fullPage: false });
    console.log(`Saved navigation back to home screenshot: ${navHomePath}`);
  }

  await navPage.close();
  await browser.close();

  console.log('=== All Clean Slate QA screenshots captured successfully! ===');
})();
