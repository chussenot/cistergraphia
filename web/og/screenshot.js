// Screenshot an HTML file at an exact viewport (used by web/og/render.rb).
// node web/og/screenshot.js INPUT.html OUTPUT.png WIDTH HEIGHT [CHROMIUM_PATH]
const { chromium } = require('playwright');

(async () => {
  const [input, output, width, height, executablePath] = process.argv.slice(2);
  const browser = await chromium.launch(executablePath ? { executablePath } : {});
  const page = await browser.newPage({ viewport: { width: Number(width), height: Number(height) } });
  await page.goto(`file://${input}`);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: output });
  await browser.close();
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
