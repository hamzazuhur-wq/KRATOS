const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();

  async function scrollDown() {
    await page.mouse.move(720, 450);
    await page.mouse.wheel(0, 680);
    await page.waitForTimeout(1200);
  }

  console.log('Testing Filters with Real Data on KRATOS Analytics...');

  // ── TEST 1: Default 30D Range ──────────────────────────────────────────────
  console.log('1. Loading Default 30D Range...');
  await page.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark', { waitUntil: 'load' });
  await page.waitForTimeout(5000);
  await scrollDown();
  await page.screenshot({
    path: path.join(screenshotsDir, 'wave05_test1_filter_range_30d.png'),
    fullPage: false,
  });

  // ── TEST 1B: Date Range 7D ─────────────────────────────────────────────────
  console.log('2. Loading 7D Range...');
  await page.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark&period=7d', { waitUntil: 'load' });
  await page.waitForTimeout(5000);
  await scrollDown();
  await page.screenshot({
    path: path.join(screenshotsDir, 'wave05_test1_filter_range_7d.png'),
    fullPage: false,
  });

  // ── TEST 1C: Date Range 90D ────────────────────────────────────────────────
  console.log('3. Loading 90D Range...');
  await page.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark&period=90d', { waitUntil: 'load' });
  await page.waitForTimeout(5000);
  await scrollDown();
  await page.screenshot({
    path: path.join(screenshotsDir, 'wave05_test1_filter_range_90d.png'),
    fullPage: false,
  });

  // ── TEST 3: Source Filter Tasks ────────────────────────────────────────────
  console.log('4. Loading Source Filter Tasks...');
  await page.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark&source=task', { waitUntil: 'load' });
  await page.waitForTimeout(5000);
  await scrollDown();
  await page.screenshot({
    path: path.join(screenshotsDir, 'wave05_test3_filter_source_task.png'),
    fullPage: false,
  });

  // ── TEST 3B: Source Filter Goals ───────────────────────────────────────────
  console.log('5. Loading Source Filter Goals...');
  await page.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark&source=goal', { waitUntil: 'load' });
  await page.waitForTimeout(5000);
  await scrollDown();
  await page.screenshot({
    path: path.join(screenshotsDir, 'wave05_test3_filter_source_goal.png'),
    fullPage: false,
  });

  await context.close();
  await browser.close();
  console.log('✅ Real Data Filter QA completed successfully.');
})();
