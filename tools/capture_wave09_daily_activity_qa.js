const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  console.log('=== Wave 09: This Week / Daily Activity Visual QA Started ===');

  // 1. Storybook Viewports across Desktop, Tablet, and Mobile
  const storybookViewports = [
    {
      name: 'wave09_storybook_desktop_1440x900_dark_baseline',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark',
      width: 1440,
      height: 900,
    },
    {
      name: 'wave09_storybook_desktop_1440x900_light_baseline',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=light',
      width: 1440,
      height: 900,
    },
    {
      name: 'wave09_storybook_tablet_1024x768_dark',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark',
      width: 1024,
      height: 768,
    },
    {
      name: 'wave09_storybook_tablet_768x1024_dark',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark',
      width: 768,
      height: 1024,
    },
    {
      name: 'wave09_storybook_mobile_430x932_dark',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark',
      width: 430,
      height: 932,
    },
    {
      name: 'wave09_storybook_mobile_390x844_dark',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark',
      width: 390,
      height: 844,
    },
  ];

  for (const item of storybookViewports) {
    console.log(`Capturing Storybook Viewport: ${item.name}...`);
    const page = await browser.newPage({ viewport: { width: item.width, height: item.height } });
    try {
      await page.goto(item.url, { waitUntil: 'load', timeout: 20000 });
      await page.waitForTimeout(4000);

      await page.screenshot({
        path: path.join(screenshotsDir, `${item.name}.png`),
        fullPage: false,
      });
    } catch (err) {
      console.warn(`Warning capturing ${item.name}: ${err.message}`);
    } finally {
      await page.close();
    }
  }

  // 2. Storybook State Presets
  console.log('Capturing Storybook Interactive State Presets...');
  const statePresets = [
    {
      name: 'wave09_storybook_dark_zero_activity',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark&preset=zeroActivity',
    },
    {
      name: 'wave09_storybook_dark_tie_breaker',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark&preset=tieBreaker',
    },
    {
      name: 'wave09_storybook_dark_xp_only',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark&preset=xpOnly',
    },
    {
      name: 'wave09_storybook_dark_tasks_only',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark&preset=tasksOnly',
    },
    {
      name: 'wave09_storybook_dark_thirty_days',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark&preset=thirtyDays',
    },
    {
      name: 'wave09_storybook_dark_loading_skeleton',
      url: 'http://127.0.0.1:3000/?preview=wave09&theme=dark&preset=loadingSkeleton',
    },
  ];

  for (const preset of statePresets) {
    console.log(`Capturing Preset: ${preset.name}...`);
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    try {
      await page.goto(preset.url, { waitUntil: 'load', timeout: 20000 });
      await page.waitForTimeout(3500);

      await page.screenshot({
        path: path.join(screenshotsDir, `${preset.name}.png`),
        fullPage: false,
      });
    } catch (err) {
      console.warn(`Warning capturing ${preset.name}: ${err.message}`);
    } finally {
      await page.close();
    }
  }

  // 3. Integrated Analytics Screen QA (scrolled to This Week section)
  console.log('Capturing Integrated Analytics Screen (Wave 09 This Week section)...');
  const integratedViews = [
    {
      name: 'wave09_integrated_analytics_desktop_1440x900_dark',
      url: 'http://127.0.0.1:3000/?preview=analytics&theme=dark',
      width: 1440,
      height: 900,
      scrollOffset: 750,
    },
    {
      name: 'wave09_integrated_analytics_desktop_1440x900_light',
      url: 'http://127.0.0.1:3000/?preview=analytics&theme=light',
      width: 1440,
      height: 900,
      scrollOffset: 750,
    },
    {
      name: 'wave09_integrated_analytics_mobile_430x932_dark',
      url: 'http://127.0.0.1:3000/?preview=analytics&theme=dark',
      width: 430,
      height: 932,
      scrollOffset: 1250,
    },
  ];

  for (const view of integratedViews) {
    console.log(`Capturing Integrated View: ${view.name}...`);
    const page = await browser.newPage({ viewport: { width: view.width, height: view.height } });
    try {
      await page.goto(view.url, { waitUntil: 'load', timeout: 20000 });
      await page.waitForTimeout(4500);

      // Scroll down to This Week section
      await page.mouse.move(Math.floor(view.width * 0.5), Math.floor(view.height * 0.5));
      await page.mouse.wheel(0, view.scrollOffset);
      await page.waitForTimeout(1500);

      await page.screenshot({
        path: path.join(screenshotsDir, `${view.name}.png`),
        fullPage: false,
      });
    } catch (err) {
      console.warn(`Warning capturing ${view.name}: ${err.message}`);
    } finally {
      await page.close();
    }
  }

  await browser.close();
  console.log('=== Wave 09 Visual QA Screenshots Successfully Captured! ===');
})();
