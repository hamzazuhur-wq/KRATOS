const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });

  console.log('=== Wave 08: Top Skills Visual QA Started ===');

  // 1. Storybook Screen QA across viewports, themes, and states
  const storybookStates = [
    {
      name: 'wave08_storybook_desktop_1440x900_dark_baseline',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark',
      width: 1440,
      height: 900,
    },
    {
      name: 'wave08_storybook_desktop_1440x900_light_baseline',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=light',
      width: 1440,
      height: 900,
    },
    {
      name: 'wave08_storybook_tablet_1024x768_dark',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark',
      width: 1024,
      height: 768,
    },
    {
      name: 'wave08_storybook_mobile_430x932_dark',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark',
      width: 430,
      height: 932,
    },
    {
      name: 'wave08_storybook_mobile_390x844_dark',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark',
      width: 390,
      height: 844,
    },
  ];

  for (const item of storybookStates) {
    console.log(`Capturing Storybook: ${item.name}...`);
    const page = await browser.newPage({ viewport: { width: item.width, height: item.height } });
    try {
      await page.goto(item.url, { waitUntil: 'load', timeout: 15000 });
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

  // 2. Storybook Interactive Presets
  console.log('Capturing Storybook Interactive States...');
  const interactivePresets = [
    {
      name: 'wave08_storybook_dark_selected_detail',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=selected',
    },
    {
      name: 'wave08_storybook_dark_large_count',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=large',
    },
    {
      name: 'wave08_storybook_dark_few_skills',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=few',
    },
    {
      name: 'wave08_storybook_dark_single_skill',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=single',
    },
    {
      name: 'wave08_storybook_dark_empty_state',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=empty',
    },
    {
      name: 'wave08_storybook_dark_loading_skeleton',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=skeleton',
    },
    {
      name: 'wave08_storybook_dark_error_retry',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=error',
    },
    {
      name: 'wave08_storybook_dark_long_names',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=long_names',
    },
    {
      name: 'wave08_storybook_dark_large_numbers',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=large_numbers',
    },
    {
      name: 'wave08_storybook_dark_growth_variations',
      url: 'http://127.0.0.1:3000/?preview=wave08&theme=dark&preset=growth',
    },
  ];

  for (const preset of interactivePresets) {
    console.log(`Capturing Preset: ${preset.name}...`);
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    try {
      await page.goto(preset.url, { waitUntil: 'load', timeout: 15000 });
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

  // 3. Integrated Analytics Screen QA (scrolled to Top Skills)
  console.log('Capturing Integrated Analytics Screen (Wave 08 Top Skills section)...');
  const integratedViews = [
    {
      name: 'wave08_integrated_analytics_desktop_1440x900_dark',
      url: 'http://127.0.0.1:3000/?preview=analytics&theme=dark',
      width: 1440,
      height: 900,
      scrollOffset: 1450,
    },
    {
      name: 'wave08_integrated_analytics_desktop_1440x900_light',
      url: 'http://127.0.0.1:3000/?preview=analytics&theme=light',
      width: 1440,
      height: 900,
      scrollOffset: 1450,
    },
    {
      name: 'wave08_integrated_analytics_mobile_430x932_dark',
      url: 'http://127.0.0.1:3000/?preview=analytics&theme=dark',
      width: 430,
      height: 932,
      scrollOffset: 2400,
    },
  ];

  for (const view of integratedViews) {
    console.log(`Capturing Integrated View: ${view.name}...`);
    const page = await browser.newPage({ viewport: { width: view.width, height: view.height } });
    try {
      await page.goto(view.url, { waitUntil: 'load', timeout: 15000 });
      await page.waitForTimeout(4500);

      // Scroll down to Top Skills section
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
  console.log('=== Wave 08 Visual QA Screenshots Successfully Captured! ===');
})();
