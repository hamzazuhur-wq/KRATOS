const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  // 1. Default 30 Days
  console.log('Capturing Default 30 Days...');
  const page30 = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page30.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await page30.waitForTimeout(4500);
  await page30.screenshot({ path: 'screenshots/wave03_fix_dark_30d.png' });
  await page30.close();

  // 2. 7 Days Filter
  console.log('Capturing 7 Days Filter...');
  const page7 = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page7.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark&period=7d');
  await page7.waitForTimeout(4500);
  await page7.screenshot({ path: 'screenshots/wave03_fix_dark_7d.png' });
  await page7.close();

  // 3. 90 Days Filter
  console.log('Capturing 90 Days Filter...');
  const page90 = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page90.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark&period=90d');
  await page90.waitForTimeout(4500);
  await page90.screenshot({ path: 'screenshots/wave03_fix_dark_90d.png' });
  await page90.close();

  // 4. Tasks Source Filter
  console.log('Capturing Tasks Source Filter...');
  const pageTask = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageTask.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark&source=task');
  await pageTask.waitForTimeout(4500);
  await pageTask.screenshot({ path: 'screenshots/wave03_fix_dark_source_task.png' });
  await pageTask.close();

  // 5. Consistency Card Click & Dismiss
  console.log('Capturing Consistency Detail Modal and Dismiss...');
  const pageModal = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageModal.goto('http://127.0.0.1:3000/?preview=analytics&theme=dark');
  await pageModal.waitForTimeout(4500);

  // Click Consistency card (x: 1270, y: 300)
  await pageModal.mouse.click(1270, 300);
  await pageModal.waitForTimeout(1500);
  await pageModal.screenshot({ path: 'screenshots/wave03_fix_consistency_detail_dark.png' });

  // Click the 'Dismiss' button inside the modal (centered around x: 720, y: 700)
  // or the 'x' close icon at x: 860, y: 235
  await pageModal.mouse.click(860, 235);
  await pageModal.waitForTimeout(1000);
  await pageModal.screenshot({ path: 'screenshots/wave03_fix_consistency_dismissed.png' });
  await pageModal.close();

  // 6. Light Mode Consistency Detail
  console.log('Capturing Light Mode Consistency Detail...');
  const pageLight = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await pageLight.goto('http://127.0.0.1:3000/?preview=analytics&theme=light');
  await pageLight.waitForTimeout(4500);
  await pageLight.mouse.click(1270, 300);
  await pageLight.waitForTimeout(1500);
  await pageLight.screenshot({ path: 'screenshots/wave03_fix_consistency_detail_light.png' });
  await pageLight.close();

  await browser.close();
  console.log('✅ All Wave 03 filter & consistency QA captures completed successfully.');
})();
