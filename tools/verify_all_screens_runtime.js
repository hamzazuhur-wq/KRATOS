const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const OUT_DIR = path.join(__dirname, '..', 'screenshots', 'runtime_verification');
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

(async () => {
  const profileDir = path.join(__dirname, '..', '.playwright_profile');
  if (fs.existsSync(profileDir)) {
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
  const context = await chromium.launchPersistentContext(profileDir, {
    viewport: { width: 1440, height: 900 },
    headless: true,
  });
  const page = context.pages().length > 0 ? context.pages()[0] : await context.newPage();

  const errors = [];
  let seedDone = false;

  page.on('console', msg => {
    const text = msg.text();
    console.log(`[BROWSER ${msg.type()}]`, text);
    if (msg.type() === 'error' || text.includes('Exception') || text.includes('Error')) {
      errors.push(`[${msg.type()}] ${text}`);
    }
    if (text.includes('bootstrapDevUser completed!') || text.includes('isCompleted = true')) {
      seedDone = true;
    }
  });

  page.on('pageerror', err => {
    errors.push(`[pageerror] ${err.message}`);
    console.error('PAGE UNCAUGHT:', err.message);
  });

  const screens = [
    { name: '01_Dashboard', preview: 'dashboard', waitMs: 8000 },
    { name: '02_Due_Today', preview: 'due_today', waitMs: 4000 },
    { name: '03_Tasks', preview: 'tasks', waitMs: 4000 },
    { name: '04_Goals', preview: 'goals', waitMs: 4000 },
    { name: '05_Activities', preview: 'activities', waitMs: 4000 },
    { name: '06_Ideas', preview: 'ideas', waitMs: 4000 },
    { name: '07_Stats', preview: 'stats', waitMs: 4000 },
    { name: '08_Levels', preview: 'levels', waitMs: 4000 },
    { name: '09_Life_Areas', preview: 'life_areas', waitMs: 4000 },
    { name: '10_Skills', preview: 'skills_registry', waitMs: 4000 },
    { name: '11_Projects', preview: 'projects', waitMs: 4000 },
    { name: '12_Profile', preview: 'profile', waitMs: 4000 },
    { name: '13_Calendar', preview: 'calendar', waitMs: 5000 },
  ];

  for (let i = 0; i < screens.length; i++) {
    const s = screens[i];
    const url = `http://127.0.0.1:3000/?preview=${s.preview}&theme=dark`;
    console.log(`\n[${i + 1}/${screens.length}] Navigating to ${s.name} (${url})...`);
    await page.goto(url, { waitUntil: 'load' });

    if (i === 0) {
      console.log('Waiting for initial cold database creation and seed (up to 55s)...');
      for (let w = 0; w < 55; w++) {
        if (seedDone) {
          console.log(`Seed verified after ${w} seconds.`);
          break;
        }
        await page.waitForTimeout(1000);
      }
    }

    console.log(`Waiting ${s.waitMs}ms for query resolution and render pipeline...`);
    await page.waitForTimeout(s.waitMs);

    const shotPath = path.join(OUT_DIR, `${s.name}.png`);
    await page.screenshot({ path: shotPath });
    console.log(`Captured ${s.name}.png`);
  }

  await context.close();

  console.log('\n======================================================');
  console.log(`Verification run finished. Total screens: ${screens.length}`);
  console.log(`Total errors captured: ${errors.length}`);
  if (errors.length > 0) {
    console.log('Errors:', errors);
  }
  console.log('======================================================');
})();
